module Drunker
  class Source
    attr_reader :target_files

    def initialize
      timestamp = Time.now.to_i.to_s
      @s3 = Aws::S3::Resource.new
      @bucket = s3.create_bucket(bucket: "drunker-source-store-#{timestamp}")
      @name = "drunker_source_#{timestamp}.zip"
      @target_files = []

      set_target_files(Pathname.pwd)
      archive(Pathname.pwd) do |path|
        bucket.object(name).upload_file(path.to_s)
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

    def delete
      bucket.delete!
    end

    private

    attr_reader :s3
    attr_reader :bucket
    attr_reader :name

    def archive(target_dir)
      archive_path = Pathname.new("#{target_dir.to_s}/#{name}")

      Zip::File.open(archive_path.to_s, Zip::File::CREATE) do |zip|
        Pathname.glob(target_dir.to_s + "/**/*", File::Constants::FNM_DOTMATCH).select(&:file?).each do |real_path|
          zip.add(real_path.relative_path_from(target_dir), real_path.to_s)
        end
      end
      yield archive_path
      archive_path.unlink
    end

    def set_target_files(target_dir)
      Pathname.glob(target_dir.to_s + "/**/*").select(&:file?).each do |real_path|
        @target_files << real_path.relative_path_from(target_dir).to_s
      end
    end
  end
end
