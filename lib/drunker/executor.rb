module Drunker
  class Executor
    RETRY_LIMIT = 10

    def initialize(source:, config:, logger:)
      @project_name = "drunker-executor-#{Time.now.to_i}"
      @source = source
      logger.info("Creating artifact...")
      @artifact = Drunker::Artifact.new(config: config, logger: logger)
      @config = config
      @client = Aws::CodeBuild::Client.new(config.aws_client_options)
      @logger = logger
    end

    def run
      setup_project do
        builders = create_builders

        loop do
          start_builders builders
          restart_failed_builders builders

          ran, waiting = builders.partition(&:ran?)
          running, finished = ran.partition(&:running?)

          finished.select(&:failed?).each do |builder|
            builder.errors.each do |error|
              logger.warn("Build failed: #{builder.build_id}")
              logger.warn("\tphase_type: #{error[:phase_type]}")
              logger.warn("\tphase_status: #{error[:phase_status]}")
              logger.warn("\tstatus: #{error[:status]}")
              logger.warn("\tmessage: #{error[:message]}")
            end
          end

          if waiting.count.zero? && running.count.zero?
            logger.info("Build is completed!")
            break
          end
          logger.info("Waiting builders: #{finished.count}/#{builders.count}, queues: #{waiting.count}")
          sleep 5
          builders.each(&:refresh)
        end
        artifact.layers # load artifact layers from S3
      end

      artifact
    end

    private

    attr_reader :project_name
    attr_reader :source
    attr_reader :artifact
    attr_reader :config
    attr_reader :client
    attr_reader :logger

    def setup_project
      logger.info("Creating IAM resources...")
      iam = IAM.new(source: source, artifact: artifact, config: config, logger: logger)
      retry_count = 0

      logger.info("Creating project...")
      project_info = {
        name: project_name,
        source: source.to_h,
        artifacts: artifact.to_h,
        environment: {
          type: "LINUX_CONTAINER",
          image: config.image,
          compute_type: config.compute_type,
        },
        service_role: iam.role.name,
        timeout_in_minutes: config.timeout,
      }
      project_info[:environment][:environment_variables] = config.environment_variables unless config.environment_variables.empty?
      begin
        client.create_project(project_info)
        logger.info("Created project: #{project_name}")
      # Sometimes `CodeBuild is not authorized to perform: sts:AssumeRole` error occurs...
      # We can solve this problem by retrying after a while.
      rescue Aws::CodeBuild::Errors::InvalidInputException
        if retry_count < RETRY_LIMIT
          retry_count += 1
          sleep 5
          logger.info("Retrying...")
          retry
        else
          raise
        end
      end

      yield

      unless config.debug?
        logger.info("Deleting IAM resources...")
        iam.delete
        client.delete_project(name: project_name)
        logger.info("Deleted project: #{project_name}")
      end
    end

    def create_builders
      files_list = source.target_files.each_slice(source.target_files.count.quo(config.concurrency).ceil).to_a
      logger.info("Start parallel build: { files: #{source.target_files.count}, concurrency: #{config.concurrency}, real_concurrency: #{files_list.count} }")
      files_list.to_a.each_with_object([]) do |files, builders|
        builder = Builder.new(project_name: project_name, targets: files, artifact: artifact, config: config, logger: logger)
        builders << builder
      end
    end

    def start_builders(builders)
      builders.reject(&:ran?).each do |builder|
        build_id = builder.run
        artifact.set_build(build_id)
      end
    rescue Aws::CodeBuild::Errors::AccountLimitExceededException => exn
      logger.info("Maximum number of concurrent running builds has been reached. it will retry later...")
      logger.debug("Exception: #{exn.inspect}")
    end

    def restart_failed_builders(builders)
      builders.select(&:access_denied?).each do |builder|
        failed_id = builder.build_id
        if builder.retriable?
          build_id = builder.retry
          artifact.replace_build(before: failed_id ,after: build_id)
        end
      end
    end
  end
end
