module Drunker
  class Executor
    def initialize(source:, commands:, image:)
      @project_name = "drunker-executor-#{Time.now.to_i.to_s}"
      @source = source
      @artifact = Drunker::Artifact.new
      @commands = commands
      @image = image
      @client = Aws::CodeBuild::Client.new
    end

    def run
      setup_project do
        resp = client.start_build(project_name: project_name, buildspec_override: buildspec)
        loop do
          status = client.batch_get_builds(ids: [resp.build.id]).builds.first.build_status
          break if status != "IN_PROGRESS"
          puts "Current status: #{status}"
          sleep 5
        end
      end
    end

    private

    attr_reader :project_name
    attr_reader :source
    attr_reader :artifact
    attr_reader :commands
    attr_reader :image
    attr_reader :client

    def setup_project
      iam = IAM.new(source: source, artifact: artifact)

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
      # Sometimes `CodeBuild is not authorized to perform: sts:AssumeRole` error occurs...
      # We can solve this problem by retrying after a while.
      rescue Aws::CodeBuild::Errors::InvalidInputException
        sleep 5
        puts "retrying..."
        retry
      end

      yield

      iam.delete
      client.delete_project(project_name)
    end

    def buildspec
      {
        "version" => 0.1,
        "phases" => {
          "build" => {
            "commands" => [commands.join(" ") + " > output.txt"]
          }
        },
        "artifacts" => {
          "type" => "zip",
          "files" => ["output.txt"]
        }
      }.to_yaml
    end
  end
end
