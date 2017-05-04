require "spec_helper"

RSpec.describe Drunker::Artifact do
  let(:s3) { double("s3 stub") }
  let(:bucket) { double(name: "drunker-artifact-store-1483196400") }
  let(:artifact) { Drunker::Artifact.new(logger: Logger.new("/dev/null")) }
  before do
    Timecop.freeze(Time.local(2017))

    allow(Aws::S3::Resource).to receive(:new).and_return(s3)
    allow(s3).to receive(:create_bucket).and_return(bucket)
  end
  after { Timecop.return }

  describe "#initialize" do
    it "creates s3 bucket" do
      expect(s3).to receive(:create_bucket).with(bucket: "drunker-artifact-store-1483196400").and_return(bucket)
      artifact
    end

    it "sets bucket" do
      expect(artifact.bucket).to eq bucket
    end

    it "sets artifact name" do
      expect(artifact.name).to eq "drunker_artifact_1483196400.txt"
    end
  end

  describe "#to_h" do
    it "returns hash for buildspec" do
      expect(artifact.to_h).to eq(type: "S3", location: "drunker-artifact-store-1483196400", namespace_type: "BUILD_ID")
    end
  end

  describe "#output" do
    let(:build_1_object) { double(get: double(body: double(string: "build_1_string") ) ) }
    let(:build_2_object) { double(get: double(body: double(string: "build_2_string") ) ) }
    before do
      artifact.instance_variable_set(:@builds, %w(build_1 build_2))
      artifact.instance_variable_set(:@project_name, "drunker-test-executor")
      allow(bucket).to receive(:object).with("build_1/drunker-test-executor/drunker_artifact_1483196400.txt").and_return(build_1_object)
      allow(bucket).to receive(:object).with("build_2/drunker-test-executor/drunker_artifact_1483196400.txt").and_return(build_2_object)
    end

    it "returns artifact hash" do
      expect(artifact.output).to eq("build_1" => "build_1_string", "build_2" => "build_2_string")
    end
  end

  describe "#set_build" do
    it "sets build and project_name" do
      artifact.set_build("drunker-test-executor:build_1")
      expect(artifact.instance_variable_get(:@builds)).to eq %w(build_1)
      expect(artifact.instance_variable_get(:@project_name)).to eq "drunker-test-executor"
    end

    it "sets multiple builds and project_name" do
      artifact.set_build("drunker-test-executor:build_1")
      artifact.set_build("drunker-test-executor:build_2")
      expect(artifact.instance_variable_get(:@builds)).to eq %w(build_1 build_2)
      expect(artifact.instance_variable_get(:@project_name)).to eq "drunker-test-executor"
    end
  end

  describe "#replace_build" do
    before { artifact.instance_variable_set(:@builds, %w(build_1)) }

    it "replaces build id" do
      artifact.replace_build(before: "drunker-test-executor:build_1", after: "drunker-test-executor:build_1_retry")
      expect(artifact.instance_variable_get(:@builds)).to eq %w(build_1_retry)
    end
  end

  describe "#delete" do
    it "deletes bucket" do
      expect(bucket).to receive(:delete!)
      artifact.delete
    end
  end
end
