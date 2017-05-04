module Drunker
  class Artifact
    attr_reader :bucket
    attr_reader :name

    def initialize(logger:)
      @logger = logger
      timestamp = Time.now.to_i.to_s

      @s3 = Aws::S3::Resource.new
      @bucket = s3.create_bucket(bucket: "drunker-artifact-store-#{timestamp}")
      logger.info("Created artifact bucket: #{bucket.name}")
      @name = "drunker_artifact_#{timestamp}.txt"
      @builds = []
    end

    def to_h
      {
        type: "S3",
        location: bucket.name,
        namespace_type: "BUILD_ID",
      }
    end

    def output
      builds.each_with_object({}) do |build, results|
        project_name, build_id = build.split(":")
        object_id = "#{build_id}/#{project_name}/#{name}"
        results[build] = bucket.object(object_id).get.body.string
        logger.debug("Get artifact: #{object_id}")
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

    attr_reader :s3
    attr_reader :builds
    attr_reader :logger
  end
end
