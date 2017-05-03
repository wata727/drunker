module Drunker
  class Executor
    def initialize(source:, commands:, image:, concurrency:, logger:)
      @logger = logger
      @project_name = "drunker-executor-#{Time.now.to_i.to_s}"
      @source = source
      logger.info("Creating artifact...")
      @artifact = Drunker::Artifact.new(logger: logger)
      @commands = commands
      @image = image
      @concurrency = concurrency
      @client = Aws::CodeBuild::Client.new
    end

    def run
      setup_project do
        builders = parallel_build

        loop do
          running, finished = builders.partition(&:running?)
          break if running.count.zero?
          logger.info("Waiting builder: #{finished.count}/#{builders.count}")
          sleep 5
        end
      end

      artifact
    end

    private

    attr_reader :project_name
    attr_reader :source
    attr_reader :artifact
    attr_reader :commands
    attr_reader :image
    attr_reader :concurrency
    attr_reader :client
    attr_reader :logger

    def setup_project
      logger.info("Creating IAM resources...")
      iam = IAM.new(source: source, artifact: artifact)

      logger.info("Creating project...")
      begin
        client.create_project(
          name: project_name,
          source: source.to_h,
          artifacts: artifact.to_h,
          environment: {
            type: "LINUX_CONTAINER",
            image: image,
            compute_type: "BUILD_GENERAL1_SMALL",
          },
          service_role: iam.role.name
        )
        logger.info("Created project: #{project_name}")
      # Sometimes `CodeBuild is not authorized to perform: sts:AssumeRole` error occurs...
      # We can solve this problem by retrying after a while.
      rescue Aws::CodeBuild::Errors::InvalidInputException
        sleep 5
        logger.info("Retrying...")
        retry
      end

      yield

      logger.info("Deleting IAM resources...")
      iam.delete
      client.delete_project(name: project_name)
      logger.info("Deleted project: #{project_name}")
    end

    def parallel_build
      builders = []

      files_list = source.target_files.each_slice(source.target_files.count.quo(concurrency).ceil).to_a
      logger.info("Start parallel build: { files: #{source.target_files.count}, concurrency: #{concurrency}, real_concurrency: #{files_list.count} }")
      files_list.to_a.each do |files|
        builder = Builder.new(project_name: project_name, commands: commands, targets: files, artifact: artifact)
        build_id = builder.run
        artifact.set_build(build_id)
        builders << builder
      end

      builders
    end
  end
end
