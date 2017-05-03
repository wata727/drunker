require "spec_helper"

RSpec.describe Drunker::Artifact do
  let(:s3) { double("s3 stub") }
  let(:bucket) { double(name: "drunker-artifact-store-1483196400") }
  before do
    Timecop.freeze(Time.local(2017))

    allow(Aws::S3::Resource).to receive(:new).and_return(s3)
    allow(s3).to receive(:create_bucket).and_return(bucket)
  end
  after { Timecop.return }

  context "#initialize" do
    it "creates s3 bucket" do
      expect(s3).to receive(:create_bucket).with(bucket: "drunker-artifact-store-1483196400").and_return(bucket)
      Drunker::Artifact.new
    end

    it "sets bucket" do
      expect(Drunker::Artifact.new.bucket).to eq bucket
    end

    it "sets artifact name" do
      expect(Drunker::Artifact.new.name).to eq "drunker_artifact_1483196400.txt"
    end
  end

  context "#to_h" do
    it "returns hash for buildspec" do
      expect(Drunker::Artifact.new.to_h).to eq(type: "S3", location: "drunker-artifact-store-1483196400", namespace_type: "BUILD_ID")
    end
  end

  context "#output" do
    let(:artifact) { Drunker::Artifact.new }
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

  context "#set_build" do
    let(:artifact) { Drunker::Artifact.new }
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

  context "#delete" do
    it "deletes bucket" do
      expect(bucket).to receive(:delete!)
      Drunker::Artifact.new.delete
    end
  end
end
