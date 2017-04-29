module Drunker
  class Artifact
    attr_reader :bucket

    def initialize
      timestamp = Time.now.to_i.to_s
      @s3 = Aws::S3::Resource.new
      @bucket = s3.create_bucket(bucket: "drunker-artifact-store-#{timestamp}")
      @name = "drunker_artifact_#{timestamp}.zip"
    end

    def to_h
      {
        type: "S3",
        location: bucket.name,
        namespace_type: "BUILD_ID",
        name: name,
        packaging: "ZIP",
      }
    end

    private

    attr_reader :s3
    attr_reader :name
  end
end
