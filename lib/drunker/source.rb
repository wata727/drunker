module Drunker
  class Source
    def initialize
      timestamp = Time.now.to_i.to_s
      @s3 = Aws::S3::Resource.new
      @bucket = s3.create_bucket(bucket: "drunker-source-store-#{timestamp}")
      @name = "drunker_source_#{timestamp}.zip"

      archive(Pathname.pwd) do |path|
        bucket.object(name).upload_file(path)
      end
    end

    def location
      "#{bucket.name}/#{name}"
    end

    def to_h
      {
        type: "S3",
        location: location
      }
    end

    private

    attr_reader :s3
    attr_reader :bucket
    attr_reader :name

    def archive(target_dir)
      archive_path = "#{target_dir.to_s}/#{name}"

      Zip::File.open(archive_path, Zip::File::CREATE) do |zip|
        Pathname.glob(target_dir.to_s + "/**/*", File::Constants::FNM_DOTMATCH).select(&:file?).each do |path|
          zip.add(path.relative_path_from(target_dir).to_s, path.to_s)
        end
      end
      yield archive_path
      File.unlink archive_path
    end
  end
end
