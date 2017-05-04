module Drunker
  class Executor
    class Builder
      IN_PROGRESS = "IN_PROGRESS"
      SUCCEEDED   = "SUCCEEDED"
      FAILED      = "FAILED"
      TIMED_OUT   = "TIMED_OUT"
      STOPPED     = "STOPPED"

      RETRY_LIMIT = 1
      PHASE_ACCESS_DENIED = "ACCESS_DENIED"

      attr_reader :build_id

      def initialize(project_name:, commands:, targets:, artifact:, logger:)
        @logger = logger
        @project_name = project_name
        @commands = commands
        @targets = targets
        @artifact = artifact
        @client = Aws::CodeBuild::Client.new
        @retry_count = 0
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

      private

      attr_reader :project_name
      attr_reader :commands
      attr_reader :targets
      attr_reader :artifact
      attr_reader :client
      attr_reader :logger
      attr_reader :retry_count

      def result
        @result ||= client.batch_get_builds(ids: [build_id])
      end

      def status
        result.builds[0].build_status
      end

      def buildspec
        {
          "version" => 0.1,
          "phases" => {
            "build" => {
              "commands" => [interpolate_commands.join(" ") + " 1> #{artifact.stdout} 2> #{artifact.stderr}; echo $? > #{artifact.status_code}"]
            }
          },
          "artifacts" => {
            "files" => [artifact.stdout, artifact.stderr, artifact.status_code]
          }
        }.to_yaml
      end

      def interpolate_commands
        variables = %w(FILES)

        commands.map do |command|
          variables.include?(command) ? targets : command
        end.flatten
      end

      def access_denied_message_included?(message)
        message.include?("is not authorized to perform") || message.include?("Not authorized to perform")
      end
    end
  end
end
