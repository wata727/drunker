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

    it "sets artifact attributes" do
      expect(artifact.stdout).to eq "drunker_artifact_1483196400_stdout.txt"
      expect(artifact.stderr).to eq "drunker_artifact_1483196400_stderr.txt"
      expect(artifact.status_code).to eq "drunker_artifact_1483196400_status_code.txt"
    end
  end

  describe "#to_h" do
    it "returns hash for buildspec" do
      expect(artifact.to_h).to eq(type: "S3", location: "drunker-artifact-store-1483196400", namespace_type: "BUILD_ID")
    end
  end

  describe "#output" do
    let(:build_1_stdout_object) { double(get: double(body: double(string: "build_1_stdout") ) ) }
    let(:build_1_stderr_object) { double(get: double(body: double(string: "build_1_stderr") ) ) }
    let(:build_1_status_code_object) { double(get: double(body: double(string: "build_1_status_code") ) ) }
    let(:build_2_stdout_object) { double(get: double(body: double(string: "build_2_stdout") ) ) }
    let(:build_2_stderr_object) { double(get: double(body: double(string: "build_2_stderr") ) ) }
    let(:build_2_status_code_object) { double(get: double(body: double(string: "build_2_status_code") ) ) }
    before do
      artifact.instance_variable_set(:@builds, %w(drunker-test-executor:build_1 drunker-test-executor:build_2))
      allow(bucket).to receive(:object).with("build_1/drunker-test-executor/drunker_artifact_1483196400_stdout.txt").and_return(build_1_stdout_object)
      allow(bucket).to receive(:object).with("build_1/drunker-test-executor/drunker_artifact_1483196400_stderr.txt").and_return(build_1_stderr_object)
      allow(bucket).to receive(:object).with("build_1/drunker-test-executor/drunker_artifact_1483196400_status_code.txt").and_return(build_1_status_code_object)
      allow(bucket).to receive(:object).with("build_2/drunker-test-executor/drunker_artifact_1483196400_stdout.txt").and_return(build_2_stdout_object)
      allow(bucket).to receive(:object).with("build_2/drunker-test-executor/drunker_artifact_1483196400_stderr.txt").and_return(build_2_stderr_object)
      allow(bucket).to receive(:object).with("build_2/drunker-test-executor/drunker_artifact_1483196400_status_code.txt").and_return(build_2_status_code_object)
    end

    it "returns artifact hash" do
      build_1_body = {
        stdout: "build_1_stdout",
        stderr: "build_1_stderr",
        status_code: "build_1_status_code"
      }
      build_2_body = {
        stdout: "build_2_stdout",
        stderr: "build_2_stderr",
        status_code: "build_2_status_code"
      }
      expect(artifact.output).to eq("drunker-test-executor:build_1" => build_1_body, "drunker-test-executor:build_2" => build_2_body)
    end
  end

  describe "#set_build" do
    it "sets build and project_name" do
      artifact.set_build("drunker-test-executor:build_1")
      expect(artifact.instance_variable_get(:@builds)).to eq %w(drunker-test-executor:build_1)
    end

    it "sets multiple builds and project_name" do
      artifact.set_build("drunker-test-executor:build_1")
      artifact.set_build("drunker-test-executor:build_2")
      expect(artifact.instance_variable_get(:@builds)).to eq %w(drunker-test-executor:build_1 drunker-test-executor:build_2)
    end
  end

  describe "#replace_build" do
    before { artifact.instance_variable_set(:@builds, %w(drunker-test-executor:build_1)) }

    it "replaces build id" do
      artifact.replace_build(before: "drunker-test-executor:build_1", after: "drunker-test-executor:build_1_retry")
      expect(artifact.instance_variable_get(:@builds)).to eq %w(drunker-test-executor:build_1_retry)
    end
  end

  describe "#delete" do
    it "deletes bucket" do
      expect(bucket).to receive(:delete!)
      artifact.delete
    end
  end
end
