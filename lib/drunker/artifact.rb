module Drunker
  class Artifact
    attr_reader :bucket
    attr_reader :stdout
    attr_reader :stderr
    attr_reader :exit_status

    def initialize(config:, logger:)
      timestamp = Time.now.to_i.to_s
      s3 = Aws::S3::Resource.new(client: Aws::S3::Client.new(config.aws_client_options))

      @bucket = s3.create_bucket(bucket: "drunker-artifact-store-#{timestamp}")
      logger.info("Created artifact bucket: #{bucket.name}")
      @name = "drunker_artifact_#{timestamp}"
      @stdout = "drunker_artifact_#{timestamp}_stdout.txt"
      @stderr = "drunker_artifact_#{timestamp}_stderr.txt"
      @exit_status = "drunker_artifact_#{timestamp}_exit_status.txt"
      @builds = []
      @logger = logger
    end

    def to_h
      {
        type: "S3",
        location: bucket.name,
        namespace_type: "BUILD_ID",
      }
    end

    def layers
      @layers ||= builds.each_with_object([]) do |build, layers|
        project_name, build_id = build.split(":")
        layers << Layer.new(build_id: build).tap do |layer|
          begin
            layer.stdout = fetch_content("#{build_id}/#{project_name}/#{stdout}")
            layer.stderr = fetch_content("#{build_id}/#{project_name}/#{stderr}")
            layer.exit_status = fetch_content("#{build_id}/#{project_name}/#{exit_status}")
          rescue Aws::S3::Errors::NoSuchKey
            logger.debug("Artifact not found")
            layer.invalid!
          end
        end
      end
    end

    def set_build(build)
      @builds << build
      logger.debug("Set build: { build: #{build}, artifact: #{name} }")
    end

    def replace_build(before:, after:)
      builds.delete(before)
      logger.debug("Unset build: { build: #{before}, artifact: #{name} }")
      set_build(after)
    end

    def delete
      bucket.delete!
      logger.info("Deleted bucket: #{bucket.name}")
    end

    private

    attr_reader :builds
    attr_reader :name
    attr_reader :logger

    def fetch_content(object_id)
      logger.debug("Get artifact: #{object_id}")
      bucket.object(object_id).get.body.string
    end
  end
end
