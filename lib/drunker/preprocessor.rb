module Drunker
  class PreProcessor
    def initialize
      timestamp = Time.now.to_i.to_s
      @s3 = Aws::S3::Resource.new
      @bucket = s3.create_bucket(bucket: "drunker-source-store-#{timestamp}")
      @archive_name = "drunker_archive_#{timestamp}.zip"
    end

    def run
      archive(Pathname.pwd) do |archive_path|
        bucket.object(archive_name).upload_file(archive_path)
      end
    end

    private

    attr_reader :s3
    attr_reader :bucket
    attr_reader :archive_name

    def archive(target_dir)
      archive_path = "#{target_dir.to_s}/#{archive_name}"

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
