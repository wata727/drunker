module Drunker
  class Artifact
    attr_reader :bucket
    attr_reader :name

    def initialize
      timestamp = Time.now.to_i.to_s
      @s3 = Aws::S3::Resource.new
      @bucket = s3.create_bucket(bucket: "drunker-artifact-store-#{timestamp}")
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
      builds.each_with_object({}) do |build_id, results|
        results[build_id] = bucket.object("#{build_id}/#{project_name}/#{name}").get.body.string
      end
    end

    def set_build(build)
      @project_name, build_id = build.split(":")
      @builds << build_id
    end

    def delete
      bucket.delete!
    end

    private

    attr_reader :s3
    attr_reader :project_name
    attr_reader :builds
  end
end
