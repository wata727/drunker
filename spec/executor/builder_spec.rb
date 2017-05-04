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

  context "#initialize" do
    it "sets attributes" do
      expect(builder.instance_variable_get(:@project_name)).to eq project_name
      expect(builder.instance_variable_get(:@commands)).to eq commands
      expect(builder.instance_variable_get(:@targets)).to eq targets
      expect(builder.instance_variable_get(:@artifact)).to eq artifact
    end
  end

  context "#run" do
    let(:response) { double(build: double(id: "build_id")) }
    before do
      allow(client).to receive(:start_build).and_return(response)
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

  context "#running?" do
    before do
      builder.instance_variable_set(:@build_id, "build_id")
    end

    context "when build is in progress" do
      before do
        allow(client).to receive(:batch_get_builds).with(ids: ["build_id"]).and_return(double(builds: [double(build_status: "IN_PROGRESS")]))
      end

      it "retuns true" do
        expect(builder.running?).to be true
      end
    end

    context "when build is successed" do
      before do
        allow(client).to receive(:batch_get_builds).with(ids: ["build_id"]).and_return(double(builds: [double(build_status: "SUCCESSED")]))
      end

      it "retuns false" do
        expect(builder.running?).to be false
      end
    end

    context "when build is failed" do
      before do
        allow(client).to receive(:batch_get_builds).with(ids: ["build_id"]).and_return(double(builds: [double(build_status: "FAILED")]))
      end

      it "retuns false" do
        expect(builder.running?).to be false
      end
    end

    context "when build is timed out" do
      before do
        allow(client).to receive(:batch_get_builds).with(ids: ["build_id"]).and_return(double(builds: [double(build_status: "TIMED_OUT")]))
      end

      it "retuns false" do
        expect(builder.running?).to be false
      end
    end

    context "when build is stopped" do
      before do
        allow(client).to receive(:batch_get_builds).with(ids: ["build_id"]).and_return(double(builds: [double(build_status: "STOPPED")]))
      end

      it "retuns false" do
        expect(builder.running?).to be false
      end
    end
  end
end
