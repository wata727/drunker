module Drunker
  class Artifact
    NOT_FOUND = "ARTIFACT_NOT_FOUND"

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

    def output
      @output ||= builds.each_with_object({}) do |build, results|
        project_name, build_id = build.split(":")
        results[build] = {}.tap do |body|
          body[:stdout] = fetch_content("#{build_id}/#{project_name}/#{stdout}")
          body[:stderr] = fetch_content("#{build_id}/#{project_name}/#{stderr}")
          body[:exit_status] = fetch_content("#{build_id}/#{project_name}/#{exit_status}")
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
    rescue Aws::S3::Errors::NoSuchKey
      logger.debug("Artifact not found: #{object_id}")
      NOT_FOUND
    end
  end
end
