require "spec_helper"

RSpec.describe Drunker::Executor::Builder do
  let(:project_name) { "drunker-project-name" }
  let(:commands) { %w(rubocop --fail-level=F) }
  let(:targets) { %w(lib/drunker.rb lib/drunker/cli.rb lib/drunker/version.rb) }
  let(:artifact) { double(name: "artifact.txt") }
  let(:builder) { Drunker::Executor::Builder.new(project_name: project_name, commands: commands, targets: targets, artifact: artifact, logger: Logger.new("/dev/null")) }
  let(:client) { double("codebuild client stub") }

  before do
    allow(Aws::CodeBuild::Client).to receive(:new).and_return(client)
  end

  describe "#initialize" do
    it "sets attributes" do
      expect(builder.instance_variable_get(:@project_name)).to eq project_name
      expect(builder.instance_variable_get(:@commands)).to eq commands
      expect(builder.instance_variable_get(:@targets)).to eq targets
      expect(builder.instance_variable_get(:@artifact)).to eq artifact
    end
  end

  describe "#run" do
    let(:response) { double(build: double(id: "build_id")) }
    before do
      allow(client).to receive(:start_build).and_return(response)
      allow(builder).to receive(:refresh)
    end

    it "starts new build" do
      yaml = {
        "version" => 0.1,
          "phases" => {
            "build" => {
            "commands" => ["rubocop --fail-level=F > artifact.txt"]
          }
        },
        "artifacts" => {
          "files" => %w(artifact.txt)
        }
      }.to_yaml
      expect(client).to receive(:start_build).with(project_name: project_name, buildspec_override: yaml).and_return(response)

      builder.run
    end

    it "sets build id" do
      builder.run
      expect(builder.instance_variable_get(:@build_id)).to eq "build_id"
    end

    it "refreshes response" do
      expect(builder).to receive(:refresh)
      builder.run
    end

    context "when use meta variables" do
      let(:commands) { %w(rubocop --fail-level=F FILES) }

      it "starts new build with interpolated buildspec" do
        yaml = {
          "version" => 0.1,
          "phases" => {
            "build" => {
              "commands" => ["rubocop --fail-level=F lib/drunker.rb lib/drunker/cli.rb lib/drunker/version.rb > artifact.txt"]
            }
          },
          "artifacts" => {
            "files" => %w(artifact.txt)
          }
        }.to_yaml
        expect(client).to receive(:start_build).with(project_name: project_name, buildspec_override: yaml).and_return(response)

        builder.run
      end
    end
  end

  describe "#retriable?" do
    it "returns true" do
      expect(builder.retriable?).to be true
    end

    context "when already retried" do
      before { builder.instance_variable_set(:@retry_count, 1) }
      it "returns false" do
        expect(builder.retriable?).to be false
      end
    end
  end

  describe "#retry" do
    it "runs" do
      expect(builder).to receive(:run)
      builder.retry
    end
  end

  describe "#access_denined?" do
    before do
      builder.instance_variable_set(:@build_id, "build_id")
    end

    context "when builder is running" do
      before do
        allow(client).to receive(:batch_get_builds).with(ids: ["build_id"]).and_return(double(builds: [double(build_status: "IN_PROGRESS")]))
      end

      it "returns false" do
        expect(builder.access_denied?).to be false
      end
    end

    context "when builder is successed" do
      before do
        allow(client).to receive(:batch_get_builds).with(ids: ["build_id"]).and_return(double(builds: [double(build_status: "SUCCEEDED")]))
      end

      it "returns false" do
        expect(builder.access_denied?).to be false
      end
    end

    context "when builder is failed" do
      let(:build) do
        double(
          build_status: "FAILED",
          phases: [double(contexts: nil)]
        )
      end
      before do
        allow(client).to receive(:batch_get_builds).with(ids: ["build_id"]).and_return(double(builds: [build]))
      end

      it "returns false" do
        expect(builder.access_denied?).to be false
      end
    end

    context "when builder is access denined" do
      let(:build) do
        double(
          build_status: "FAILED",
          phases: [
            double(contexts: [
              double(
                status_code: "ACCESS_DENIED",
                message: <<MESSAGE
Service role arn:aws:iam::123456789012:role/drunker-codebuild-servie-role-1493887235 does not allow AWS CodeBuild to create Amazon CloudWatch Logs
log streams for build arn:aws:codebuild:us-east-1:123456789012:build/drunker-executor-1493887234:55c67f69-5a25-468a-bf01-bed03d4f9c07.
Error message: User: arn:aws:sts::123456789012:assumed-role/drunker-codebuild-servie-role-1493887235/AWSCodeBuild is not authorized to perform:
logs:CreateLogStream on resource: arn:aws:logs:us-east-1:123456789012:log-group:/aws/codebuild/drunker-executor-1493887234:log-stream:55c67f69-5a25-468a-bf01-bed03d4f9c07.
Service role arn:aws:iam::123456789012:role/drunker-codebuild-servie-role-1493887235 does not allow AWS CodeBuild to create Amazon CloudWatch Logs
log streams for build arn:aws:codebuild:us-east-1:123456789012:build/drunker-executor-1493887234:55c67f69-5a25-468a-bf01-bed03d4f9c07.
Error message: User: arn:aws:sts::123456789012:assumed-role/drunker-codebuild-servie-role-1493887235/AWSCodeBuild is not authorized to perform:
logs:CreateLogStream on resource: arn:aws:logs:us-east-1:123456789012:log-group:/aws/codebuild/drunker-executor-1493887234:log-stream:55c67f69-5a25-468a-bf01-bed03d4f9c07
MESSAGE
              )
            ]),
            double(contexts: nil)
          ]
        )
      end
      before do
        allow(client).to receive(:batch_get_builds).with(ids: ["build_id"]).and_return(double(builds: [build]))
      end

      it "returns true" do
        expect(builder.access_denied?).to be true
      end
    end
  end

  describe "#running?, #failed? and #success?" do
    before do
      builder.instance_variable_set(:@build_id, "build_id")
    end

    context "when build is in progress" do
      before do
        allow(client).to receive(:batch_get_builds).with(ids: ["build_id"]).and_return(double(builds: [double(build_status: "IN_PROGRESS")]))
      end

      it "returns true" do
        expect(builder.running?).to be true
      end

      it "returns false" do
        expect(builder.failed?).to be false
      end

      it "returns false" do
        expect(builder.success?).to be false
      end
    end

    context "when build is successed" do
      before do
        allow(client).to receive(:batch_get_builds).with(ids: ["build_id"]).and_return(double(builds: [double(build_status: "SUCCEEDED")]))
      end

      it "returns false" do
        expect(builder.running?).to be false
      end

      it "returns false" do
        expect(builder.failed?).to be false
      end

      it "returns true" do
        expect(builder.success?).to be true
      end
    end

    context "when build is failed" do
      before do
        allow(client).to receive(:batch_get_builds).with(ids: ["build_id"]).and_return(double(builds: [double(build_status: "FAILED")]))
      end

      it "returns false" do
        expect(builder.running?).to be false
      end

      it "returns true" do
        expect(builder.failed?).to be true
      end

      it "returns false" do
        expect(builder.success?).to be false
      end
    end

    context "when build is timed out" do
      before do
        allow(client).to receive(:batch_get_builds).with(ids: ["build_id"]).and_return(double(builds: [double(build_status: "TIMED_OUT")]))
      end

      it "returns false" do
        expect(builder.running?).to be false
      end

      it "returns false" do
        expect(builder.failed?).to be false
      end

      it "returns false" do
        expect(builder.success?).to be false
      end
    end

    context "when build is stopped" do
      before do
        allow(client).to receive(:batch_get_builds).with(ids: ["build_id"]).and_return(double(builds: [double(build_status: "STOPPED")]))
      end

      it "returns false" do
        expect(builder.running?).to be false
      end

      it "returns false" do
        expect(builder.failed?).to be false
      end

      it "returns false" do
        expect(builder.success?).to be false
      end
    end
  end

  describe "#refresh" do
    before { builder.instance_variable_set(:@result, double("CodeBuild response stub")) }
    it "makes result to nil" do
      builder.refresh
      expect(builder.instance_variable_get(:@result)).to be_nil
    end
  end
end
