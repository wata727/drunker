module Drunker
  class Executor
    def initialize(source:, commands:, image:, concurrency:)
      @project_name = "drunker-executor-#{Time.now.to_i.to_s}"
      @source = source
      @artifact = Drunker::Artifact.new
      @commands = commands
      @image = image
      @concurrency = concurrency
      @client = Aws::CodeBuild::Client.new
    end

    def run
      setup_project do
        builders = parallel_build

        loop do
          break unless builders.any?(&:running?)
          puts "Waiting running...."
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
      client.delete_project(name: project_name)
    end

    def parallel_build
      builders = []

      source.target_files.each_slice(source.target_files.count.quo(concurrency).ceil).to_a.each do |files|
        builder = Builder.new(project_name: project_name, commands: commands, targets: files, artifact: artifact)
        build_id = builder.run
        artifact.set_build(build_id)
        builders << builder
      end

      builders
    end
  end
end
