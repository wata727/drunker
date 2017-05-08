require "spec_helper"

RSpec.describe Drunker::Artifact do
  let(:s3) { double("s3 stub") }
  let(:bucket) { double(name: "drunker-artifact-store-#{time.to_i}") }
  let(:aws_opts) { double("AWS options stub") }
  let(:config) { double(aws_client_options: aws_opts) }
  let(:client) { double("client stub") }
  let(:artifact) { Drunker::Artifact.new(config: config, logger: Logger.new("/dev/null")) }
  let(:time) { Time.local(2017) }
  before do
    Timecop.freeze(time)

    allow(Aws::S3::Client).to receive(:new).and_return(client)
    allow(Aws::S3::Resource).to receive(:new).and_return(s3)
    allow(s3).to receive(:create_bucket).and_return(bucket)
  end
  after { Timecop.return }

  describe "#initialize" do
    it "uses client with config" do
      expect(Aws::S3::Client).to receive(:new).with(aws_opts).and_return(client)
      expect(Aws::S3::Resource).to receive(:new).with(client: client).and_return(s3)
      artifact
    end

    it "creates s3 bucket" do
      expect(s3).to receive(:create_bucket).with(bucket: "drunker-artifact-store-#{time.to_i}").and_return(bucket)
      artifact
    end

    it "sets bucket" do
      expect(artifact.bucket).to eq bucket
    end

    it "sets artifact attributes" do
      expect(artifact.stdout).to eq "drunker_artifact_#{time.to_i}_stdout.txt"
      expect(artifact.stderr).to eq "drunker_artifact_#{time.to_i}_stderr.txt"
      expect(artifact.exit_status).to eq "drunker_artifact_#{time.to_i}_exit_status.txt"
    end
  end

  describe "#to_h" do
    it "returns hash for buildspec" do
      expect(artifact.to_h).to eq(type: "S3", location: "drunker-artifact-store-#{time.to_i}", namespace_type: "BUILD_ID")
    end
  end

  describe "#layers" do
    let(:build_1_stdout_object) { double(get: double(body: double(string: "build_1_stdout") ) ) }
    let(:build_1_stderr_object) { double(get: double(body: double(string: "build_1_stderr") ) ) }
    let(:build_1_exit_status_object) { double(get: double(body: double(string: "0") ) ) }
    let(:build_2_stdout_object) { double(get: double(body: double(string: "build_2_stdout") ) ) }
    let(:build_2_stderr_object) { double(get: double(body: double(string: "build_2_stderr") ) ) }
    let(:build_2_exit_status_object) { double(get: double(body: double(string: "0") ) ) }
    before do
      artifact.instance_variable_set(:@builds, %w(drunker-test-executor:build_1 drunker-test-executor:build_2))
      allow(bucket).to receive(:object).with("build_1/drunker-test-executor/drunker_artifact_#{time.to_i}_stdout.txt").and_return(build_1_stdout_object)
      allow(bucket).to receive(:object).with("build_1/drunker-test-executor/drunker_artifact_#{time.to_i}_stderr.txt").and_return(build_1_stderr_object)
      allow(bucket).to receive(:object).with("build_1/drunker-test-executor/drunker_artifact_#{time.to_i}_exit_status.txt").and_return(build_1_exit_status_object)
      allow(bucket).to receive(:object).with("build_2/drunker-test-executor/drunker_artifact_#{time.to_i}_stdout.txt").and_return(build_2_stdout_object)
      allow(bucket).to receive(:object).with("build_2/drunker-test-executor/drunker_artifact_#{time.to_i}_stderr.txt").and_return(build_2_stderr_object)
      allow(bucket).to receive(:object).with("build_2/drunker-test-executor/drunker_artifact_#{time.to_i}_exit_status.txt").and_return(build_2_exit_status_object)
    end

    it "returns artifact layers" do
      expect(artifact.layers[0].invalid?).to be false
      expect(artifact.layers[0]).to have_attributes(build_id: "drunker-test-executor:build_1", stdout: "build_1_stdout", stderr: "build_1_stderr", exit_status: 0)
      expect(artifact.layers[1].invalid?).to be false
      expect(artifact.layers[1]).to have_attributes(build_id: "drunker-test-executor:build_2", stdout: "build_2_stdout", stderr: "build_2_stderr", exit_status: 0)
    end

    context "when raise Aws::S3::Errors::NoSuchKey" do
      let(:exception) { Aws::S3::Errors::NoSuchKey.new(nil, "The specified key does not exist.") }
      before do
        allow(bucket).to receive(:object).with("build_1/drunker-test-executor/drunker_artifact_#{time.to_i}_stdout.txt").and_raise(exception)
        allow(bucket).to receive(:object).with("build_1/drunker-test-executor/drunker_artifact_#{time.to_i}_stderr.txt").and_raise(exception)
        allow(bucket).to receive(:object).with("build_1/drunker-test-executor/drunker_artifact_#{time.to_i}_exit_status.txt").and_raise(exception)
        allow(bucket).to receive(:object).with("build_2/drunker-test-executor/drunker_artifact_#{time.to_i}_stdout.txt").and_raise(exception)
        allow(bucket).to receive(:object).with("build_2/drunker-test-executor/drunker_artifact_#{time.to_i}_stderr.txt").and_raise(exception)
        allow(bucket).to receive(:object).with("build_2/drunker-test-executor/drunker_artifact_#{time.to_i}_exit_status.txt").and_raise(exception)
      end

      it "returns invalid artifact" do
        expect(artifact.layers[0].invalid?).to be true
        expect(artifact.layers[0]).to have_attributes(build_id: "drunker-test-executor:build_1")
        expect(artifact.layers[1].invalid?).to be true
        expect(artifact.layers[1]).to have_attributes(build_id: "drunker-test-executor:build_2")
      end
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
