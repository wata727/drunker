require "spec_helper"

RSpec.describe Drunker::Source do
  let(:s3) { double("s3 stub") }
  let(:bucket) { double(name: "drunker-source-store-1483196400") }
  let(:object) { double("object stub") }
  let(:zip) { double("zip stub") }
  let(:archive_path) { double("archive path stub") }
  before do
    Timecop.freeze(Time.local(2017))

    allow(Aws::S3::Resource).to receive(:new).and_return(s3)
    allow(s3).to receive(:create_bucket).and_return(bucket)
    allow(bucket).to receive(:object).and_return(object)
    allow(object).to receive(:upload_file)
  end
  after { Timecop.return }

  context "#initiliaze" do
    it "creates s3 bucket" do
      expect(s3).to receive(:create_bucket).with(bucket: "drunker-source-store-1483196400").and_return(bucket)
      Drunker::Source.new(Pathname.pwd)
    end

    it "sets target files" do
      expect(Drunker::Source.new(Pathname(__dir__) + "fixtures").target_files).to contain_exactly("test.rb", "test2.rb", "subdir/test3.rb")
    end

    it "archives and deletes source" do
      expect(Zip::File).to receive(:open).with((Pathname(__dir__) + "fixtures/drunker_source_1483196400.zip").to_s, Zip::File::CREATE).and_yield(zip)
      expect(zip).to receive(:add).with(Pathname(".gitignore"), (Pathname(__dir__) + "fixtures/.gitignore").to_s)
      expect(zip).to receive(:add).with(Pathname("test.rb"), (Pathname(__dir__) + "fixtures/test.rb").to_s)
      expect(zip).to receive(:add).with(Pathname("test2.rb"), (Pathname(__dir__) + "fixtures/test2.rb").to_s)
      expect(zip).to receive(:add).with(Pathname("subdir/.rspec"), (Pathname(__dir__) + "fixtures/subdir/.rspec").to_s)
      expect(zip).to receive(:add).with(Pathname("subdir/test3.rb"), (Pathname(__dir__) + "fixtures/subdir/test3.rb").to_s)
      expect_any_instance_of(Pathname).to receive(:unlink)
      Drunker::Source.new(Pathname(__dir__) + "fixtures")
    end

    it "uploads archived source" do
      expect(object).to receive(:upload_file).with((Pathname.pwd + "drunker_source_1483196400.zip").to_s)
      Drunker::Source.new(Pathname.pwd)
    end
  end

  context "#location" do
    it "returns archived source object path on S3" do
      expect(Drunker::Source.new(Pathname.pwd).location).to eq "drunker-source-store-1483196400/drunker_source_1483196400.zip"
    end
  end

  context "#to_h" do
    it "returns hash for buildspec" do
      source = Drunker::Source.new(Pathname.pwd)
      expect(source.to_h).to eq(type: "S3", location: source.location)
    end
  end

  context "#delete" do
    it "deletes bucket" do
      expect(bucket).to receive(:delete!)
      Drunker::Source.new(Pathname.pwd).delete
    end
  end
end