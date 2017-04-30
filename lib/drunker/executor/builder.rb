module Drunker
  class Executor
    class Builder
      IN_PROGRESS = "IN_PROGRESS"
      SUCCEEDED   = "SUCCEEDED"
      FAILED      = "FAILED"
      TIMED_OUT   = "TIMED_OUT"
      STOPPED     = "STOPPED"

      def initialize(project_name:, commands:, targets:, artifact:)
        @project_name = project_name
        @commands = commands
        @targets = targets
        @artifact = artifact
        @client = Aws::CodeBuild::Client.new
      end

      def run
        @build_id = client.start_build(project_name: project_name, buildspec_override: buildspec).build.id
      end

      def running?
        status == IN_PROGRESS
      end

      private

      attr_reader :project_name
      attr_reader :commands
      attr_reader :targets
      attr_reader :artifact
      attr_reader :client
      attr_reader :build_id

      def status
        client.batch_get_builds(ids: [build_id]).builds.first.build_status
      end

      def buildspec
        {
          "version" => 0.1,
          "phases" => {
            "build" => {
              "commands" => [interpolate_commands.join(" ") + " > #{artifact.name}"]
            }
          },
          "artifacts" => {
            "files" => [artifact.name]
          }
        }.to_yaml
      end

      def interpolate_commands
        variables = %w(FILES)

        commands.map do |command|
          variables.include?(command) ? targets : command
        end.flatten
      end
    end
  end
end
