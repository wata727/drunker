module Drunker
  class Executor
    class Builder
      IN_PROGRESS = "IN_PROGRESS"
      SUCCEEDED   = "SUCCEEDED"
      FAILED      = "FAILED"
      TIMED_OUT   = "TIMED_OUT"
      STOPPED     = "STOPPED"

      RETRY_LIMIT = 3
      PHASE_ACCESS_DENIED = "ACCESS_DENIED"

      attr_reader :build_id

      def initialize(project_name:, targets:, artifact:, config:, logger:)
        @project_name = project_name
        @targets = targets
        @artifact = artifact
        @config = config
        @client = Aws::CodeBuild::Client.new(config.aws_client_options)
        @retry_count = 0
        @logger = logger
      end

      def run
        @build_id = client.start_build(project_name: project_name, buildspec_override: buildspec).build.id
        refresh
        logger.info("Started build: #{build_id}")
        logger.debug("buildspec: #{buildspec}")
        build_id
      end

      def retriable?
        retry_count < RETRY_LIMIT
      end

      def retry
        logger.info("Retrying build: #{build_id}")
        @retry_count += 1
        run
      end

      # Sometimes `* is not authorized to perform` or `Not authorized to perform` error occurs...
      # It is judged that this is not a problem by user setting.
      def access_denied?
        return false unless failed?
        result.builds[0].phases.any? do |phase|
          phase.contexts&.any? do |context|
            context.status_code == PHASE_ACCESS_DENIED && access_denied_message_included?(context.message)
          end
        end
      end

      def running?
        status == IN_PROGRESS
      end

      def failed?
        status == FAILED
      end

      def success?
        status == SUCCEEDED
      end

      def refresh
        @result = nil
      end

      def errors
        return unless failed?
        result.builds[0].phases.each_with_object([]) do |phase, results|
          phase.contexts&.each do |context|
            results << {
              phase_type: phase.phase_type,
              phase_status: phase.phase_status,
              status: context.status_code,
              message: context.message
            }
          end
        end
      end

      private

      attr_reader :project_name
      attr_reader :targets
      attr_reader :artifact
      attr_reader :config
      attr_reader :client
      attr_reader :retry_count
      attr_reader :logger

      def result
        @result ||= client.batch_get_builds(ids: [build_id])
      end

      def status
        result.builds[0].build_status
      end

      def buildspec
        commands = interpolate_commands
        stdout = artifact.stdout
        stderr = artifact.stderr
        status_code = artifact.status_code

        template = Pathname(__dir__ + "/buildspec.yml.erb").read
        ERB.new(template).result(binding)
      end

      def interpolate_commands
        variables = %w(FILES)

        config.commands.map do |command|
          variables.include?(command) ? targets : command
        end.flatten
      end

      def access_denied_message_included?(message)
        message.include?("is not authorized to perform") || message.include?("Not authorized to perform")
      end
    end
  end
end
