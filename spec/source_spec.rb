require "spec_helper"

RSpec.describe Drunker::Source do
  let(:path) { Pathname.pwd }
  let(:aws_opts) { double("AWS options stub") }
  let(:file_pattern) { "**/*" }
  let(:config) { double(aws_client_options: aws_opts, file_pattern: file_pattern) }
  let(:logger) { Logger.new("/dev/null") }
  let(:source) { Drunker::Source.new(path, config: config, logger: logger) }
  let(:client) { double("s3 client stub") }
  let(:s3) { double("s3 stub") }
  let(:bucket) { double(name: "drunker-source-store-#{time.to_i.to_s}") }
  let(:object) { double("object stub") }
  let(:zip) { double("zip stub") }
  let(:archive_path) { double("archive path stub") }
  let(:time) { Time.local(2017) }
  before do
    Timecop.freeze(time)

    allow(Aws::S3::Client).to receive(:new).and_return(client)
    allow(Aws::S3::Resource).to receive(:new).and_return(s3)
    allow(s3).to receive(:create_bucket).and_return(bucket)
    allow(bucket).to receive(:object).and_return(object)
    allow(object).to receive(:upload_file)
  end
  after { Timecop.return }

  describe "#initiliaze" do
    it "uses s3 client with config options" do
      expect(Aws::S3::Client).to receive(:new).with(aws_opts).and_return(client)
      expect(Aws::S3::Resource).to receive(:new).with(client: client).and_return(s3)
      source
    end

    it "creates s3 bucket" do
      expect(s3).to receive(:create_bucket).with(bucket: "drunker-source-store-#{time.to_i.to_s}").and_return(bucket)
      source
    end

    it "uploads archived source" do
      expect(object).to receive(:upload_file).with((path + "drunker_source_#{time.to_i.to_s}.zip").to_s)
      source
    end

    context "when use fixtures" do
      let(:path) { Pathname(__dir__) + "fixtures" }

      it "sets target files" do
        expect(source.target_files).to contain_exactly("buildspec.yml.erb", "test.rb", "test2.rb", "subdir/test3.rb")
      end

      it "archives and deletes source" do
        expect(Zip::File).to receive(:open).with((Pathname(__dir__) + "fixtures/drunker_source_#{time.to_i.to_s}.zip").to_s, Zip::File::CREATE).and_yield(zip)
        expect(zip).to receive(:add).with(Pathname(".custom_drunker.yml"), (Pathname(__dir__) + "fixtures/.custom_drunker.yml").to_s)
        expect(zip).to receive(:add).with(Pathname(".drunker.yml"), (Pathname(__dir__) + "fixtures/.drunker.yml").to_s)
        expect(zip).to receive(:add).with(Pathname(".gitignore"), (Pathname(__dir__) + "fixtures/.gitignore").to_s)
        expect(zip).to receive(:add).with(Pathname(".invalid_drunker.yml"), (Pathname(__dir__) + "fixtures/.invalid_drunker.yml").to_s)
        expect(zip).to receive(:add).with(Pathname("buildspec.yml.erb"), (Pathname(__dir__) + "fixtures/buildspec.yml.erb").to_s)
        expect(zip).to receive(:add).with(Pathname("test.rb"), (Pathname(__dir__) + "fixtures/test.rb").to_s)
        expect(zip).to receive(:add).with(Pathname("test2.rb"), (Pathname(__dir__) + "fixtures/test2.rb").to_s)
        expect(zip).to receive(:add).with(Pathname("subdir/.rspec"), (Pathname(__dir__) + "fixtures/subdir/.rspec").to_s)
        expect(zip).to receive(:add).with(Pathname("subdir/test3.rb"), (Pathname(__dir__) + "fixtures/subdir/test3.rb").to_s)
        expect_any_instance_of(Pathname).to receive(:unlink)
        source
      end

      context "when specified custom file pattern" do
        let(:file_pattern) { "**/*.rb" }

        it "sets target files" do
          expect(source.target_files).to contain_exactly("test.rb", "test2.rb", "subdir/test3.rb")
        end
      end
    end
  end

  describe "#location" do
    it "returns archived source object path on S3" do
      expect(source.location).to eq "drunker-source-store-#{time.to_i.to_s}/drunker_source_#{time.to_i.to_s}.zip"
    end
  end

  describe "#to_h" do
    it "returns hash for buildspec" do
      expect(source.to_h).to eq(type: "S3", location: source.location)
    end
  end

  describe "#delete" do
    it "deletes bucket" do
      expect(bucket).to receive(:delete!)
      source.delete
    end
  end
end
