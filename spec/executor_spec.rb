require "spec_helper"

RSpec.describe Drunker::Executor do
  let(:commands) { %w(rubocop --fail-level=F FILES) }
  let(:image) { "wata727/rubocop" }
  let(:concurrency) { 1 }
  let(:executor) { Drunker::Executor.new(source: source, commands: commands, image: image, concurrency: concurrency, logger: Logger.new("/dev/null")) }
  let(:source) do
    double(
      target_files: %w(lib/drunker.rb lib/drunker/cli.rb lib/drunker/version.rb),
      to_h: { type: "Source" }
    )
  end
  let(:artifact) do
    double(
      to_h: { type: "Artifact" },
      set_build: ""
    )
  end
  before do
    Timecop.freeze(Time.local(2017))
    allow(Drunker::Artifact).to receive(:new).and_return(artifact)
  end
  after { Timecop.return }

  context "#initialize" do
    it "sets attributes" do
      expect(executor.instance_variable_get(:@project_name)).to eq "drunker-executor-1483196400"
      expect(executor.instance_variable_get(:@source)).to eq source
      expect(executor.instance_variable_get(:@artifact)).to eq artifact
      expect(executor.instance_variable_get(:@commands)).to eq commands
      expect(executor.instance_variable_get(:@image)).to eq image
      expect(executor.instance_variable_get(:@concurrency)).to eq concurrency
    end

    it "creates and sets artifact" do
      expect(Drunker::Artifact).to receive(:new).with(logger: instance_of(Logger)).and_return(artifact)
      expect(executor.instance_variable_get(:@artifact)).to eq artifact
    end
  end

  context "#run" do
    let(:iam) { double(role: double(name: "drunker-service-role")) }
    let(:client) { double("codebuild clinet stub") }
    let(:builder) { double("builder stub") }
    let(:project_info) do
      {
        name: "drunker-executor-1483196400",
        source: { type: "Source" },
        artifacts: { type: "Artifact" },
        environment: {
          type: "LINUX_CONTAINER",
          image: "wata727/rubocop",
          compute_type: "BUILD_GENERAL1_SMALL",
        },
        service_role: "drunker-service-role",
      }
    end

    before do
      allow(Aws::CodeBuild::Client).to receive(:new).and_return(client)
      allow(Drunker::Executor::IAM).to receive(:new).and_return(iam)
      allow(client).to receive(:create_project)
      allow(Drunker::Executor::Builder).to receive(:new).and_return(builder)
      allow(builder).to receive(:run).and_return("project_name:build_id")
      allow(builder).to receive(:running?).and_return(false)
      allow(iam).to receive(:delete)
      allow(client).to receive(:delete_project)
      allow_any_instance_of(Object).to receive(:sleep)
    end

    it "creates and deletes IAM" do
      expect(Drunker::Executor::IAM).to receive(:new).with(source: source, artifact: artifact, logger: instance_of(Logger)).and_return(iam)
      expect(iam).to receive(:delete)
      executor.run
    end

    it "creates and deletes project" do
      expect(client).to receive(:create_project).with(project_info)
      expect(client).to receive(:delete_project).with(name: "drunker-executor-1483196400")
      executor.run
    end

    it "returns artifact" do
      expect(executor.run).to eq artifact
    end

    context "when happened `CodeBuild is not authorized to perform: sts:AssumeRole` error" do
      let(:exception) { Aws::CodeBuild::Errors::InvalidInputException.new(nil, "CodeBuild is not authorized to perform: sts:AssumeRole") }
      it "retries create_project" do
        expect(client).to receive(:create_project).with(project_info).once.and_raise(exception)
        expect(client).to receive(:create_project).with(project_info).once
        executor.run
      end
    end

    context "when target files is 3 and concurrency is 1" do
      it "creates 1 builder" do
        expect(Drunker::Executor::Builder).to receive(:new)
                                                .with(project_name: "drunker-executor-1483196400",
                                                      commands: commands,
                                                      targets: %w(lib/drunker.rb lib/drunker/cli.rb lib/drunker/version.rb),
                                                      artifact: artifact,
                                                      logger: instance_of(Logger))
                                                .and_return(builder)
        executor.run
      end

      it "runs 1 builder" do
        expect(builder).to receive(:run)
        executor.run
      end

      it "sets 1 build to artifact" do
        expect(artifact).to receive(:set_build).with("project_name:build_id")
        executor.run
      end
    end

    context "when target files is 3 and concurrency is 2" do
      let(:concurrency) { 2 }
      let(:builder1) { double("builder stub") }
      let(:builder2) { double("builder stub") }

      before do
        allow(Drunker::Executor::Builder).to receive(:new)
                                                .with(project_name: "drunker-executor-1483196400",
                                                      commands: commands,
                                                      targets: %w(lib/drunker.rb lib/drunker/cli.rb),
                                                      artifact: artifact,
                                                      logger: instance_of(Logger))
                                                .and_return(builder1)
        allow(Drunker::Executor::Builder).to receive(:new)
                                                .with(project_name: "drunker-executor-1483196400",
                                                      commands: commands,
                                                      targets: %w(lib/drunker/version.rb),
                                                      artifact: artifact,
                                                      logger: instance_of(Logger))
                                                .and_return(builder2)
        allow(builder1).to receive(:run).and_return("project_name:build_id_1")
        allow(builder2).to receive(:run).and_return("project_name:build_id_2")
        allow(builder1).to receive(:running?).and_return(false)
        allow(builder2).to receive(:running?).and_return(false)
      end

      it "creates 2 builders" do
        expect(Drunker::Executor::Builder).to receive(:new)
                                                .with(project_name: "drunker-executor-1483196400",
                                                      commands: commands,
                                                      targets: %w(lib/drunker.rb lib/drunker/cli.rb),
                                                      artifact: artifact,
                                                      logger: instance_of(Logger))
                                                .and_return(builder1)
        expect(Drunker::Executor::Builder).to receive(:new)
                                                .with(project_name: "drunker-executor-1483196400",
                                                      commands: commands,
                                                      targets: %w(lib/drunker/version.rb),
                                                      artifact: artifact,
                                                      logger: instance_of(Logger))
                                                .and_return(builder2)
        executor.run
      end

      it "runs 2 builders" do
        expect(builder1).to receive(:run)
        expect(builder2).to receive(:run)
        executor.run
      end

      it "sets 2 builds to artifact" do
        expect(artifact).to receive(:set_build).with("project_name:build_id_1")
        expect(artifact).to receive(:set_build).with("project_name:build_id_2")
        executor.run
      end
    end

    context "when target files is 3 and concurrency is 10" do
      let(:concurrency) { 10 }
      let(:builder1) { double("builder stub") }
      let(:builder2) { double("builder stub") }
      let(:builder3) { double("builder stub") }

      before do
        allow(Drunker::Executor::Builder).to receive(:new)
                                               .with(project_name: "drunker-executor-1483196400",
                                                     commands: commands,
                                                     targets: %w(lib/drunker.rb),
                                                     artifact: artifact,
                                                     logger: instance_of(Logger))
                                               .and_return(builder1)
        allow(Drunker::Executor::Builder).to receive(:new)
                                               .with(project_name: "drunker-executor-1483196400",
                                                     commands: commands,
                                                     targets: %w(lib/drunker/cli.rb),
                                                     artifact: artifact,
                                                     logger: instance_of(Logger))
                                               .and_return(builder2)
        allow(Drunker::Executor::Builder).to receive(:new)
                                               .with(project_name: "drunker-executor-1483196400",
                                                     commands: commands,
                                                     targets: %w(lib/drunker/version.rb),
                                                     artifact: artifact,
                                                     logger: instance_of(Logger))
                                               .and_return(builder3)
        allow(builder1).to receive(:run).and_return("project_name:build_id_1")
        allow(builder2).to receive(:run).and_return("project_name:build_id_2")
        allow(builder3).to receive(:run).and_return("project_name:build_id_3")
        allow(builder1).to receive(:running?).and_return(false)
        allow(builder2).to receive(:running?).and_return(false)
        allow(builder3).to receive(:running?).and_return(false)
      end

      it "creates 3 builders" do
        expect(Drunker::Executor::Builder).to receive(:new)
                                                .with(project_name: "drunker-executor-1483196400",
                                                      commands: commands,
                                                      targets: %w(lib/drunker.rb),
                                                      artifact: artifact,
                                                      logger: instance_of(Logger))
                                                .and_return(builder1)
        expect(Drunker::Executor::Builder).to receive(:new)
                                                .with(project_name: "drunker-executor-1483196400",
                                                      commands: commands,
                                                      targets: %w(lib/drunker/cli.rb),
                                                      artifact: artifact,
                                                      logger: instance_of(Logger))
                                                .and_return(builder2)
        expect(Drunker::Executor::Builder).to receive(:new)
                                                .with(project_name: "drunker-executor-1483196400",
                                                      commands: commands,
                                                      targets: %w(lib/drunker/version.rb),
                                                      artifact: artifact,
                                                      logger: instance_of(Logger))
                                                .and_return(builder3)
        executor.run
      end

      it "runs 3 builders" do
        expect(builder1).to receive(:run)
        expect(builder2).to receive(:run)
        expect(builder3).to receive(:run)
        executor.run
      end

      it "sets 3 builds to artifact" do
        expect(artifact).to receive(:set_build).with("project_name:build_id_1")
        expect(artifact).to receive(:set_build).with("project_name:build_id_2")
        expect(artifact).to receive(:set_build).with("project_name:build_id_3")
        executor.run
      end
    end

    context "when all builders are running" do
      let(:concurrency) { 2 }
      let(:builder1) { double("builder stub") }
      let(:builder2) { double("builder stub") }

      before do
        allow(Drunker::Executor::Builder).to receive(:new)
                                               .with(project_name: "drunker-executor-1483196400",
                                                     commands: commands,
                                                     targets: %w(lib/drunker.rb lib/drunker/cli.rb),
                                                     artifact: artifact,
                                                     logger: instance_of(Logger))
                                               .and_return(builder1)
        allow(Drunker::Executor::Builder).to receive(:new)
                                               .with(project_name: "drunker-executor-1483196400",
                                                     commands: commands,
                                                     targets: %w(lib/drunker/version.rb),
                                                     artifact: artifact,
                                                     logger: instance_of(Logger))
                                               .and_return(builder2)
        allow(builder1).to receive(:run).and_return("project_name:build_id_1")
        allow(builder2).to receive(:run).and_return("project_name:build_id_2")
        allow(builder1).to receive(:running?).and_return(true)
        allow(builder2).to receive(:running?).and_return(true)
        allow_any_instance_of(Drunker::Executor).to receive(:loop).and_yield
      end

      it "calls sleep in loop" do
        expect_any_instance_of(Object).to receive(:sleep)
        executor.run
      end
    end

    context "when 1 builder is running yet" do
      let(:concurrency) { 2 }
      let(:builder1) { double("builder stub") }
      let(:builder2) { double("builder stub") }

      before do
        allow(Drunker::Executor::Builder).to receive(:new)
                                               .with(project_name: "drunker-executor-1483196400",
                                                     commands: commands,
                                                     targets: %w(lib/drunker.rb lib/drunker/cli.rb),
                                                     artifact: artifact,
                                                     logger: instance_of(Logger))
                                               .and_return(builder1)
        allow(Drunker::Executor::Builder).to receive(:new)
                                               .with(project_name: "drunker-executor-1483196400",
                                                     commands: commands,
                                                     targets: %w(lib/drunker/version.rb),
                                                     artifact: artifact,
                                                     logger: instance_of(Logger))
                                               .and_return(builder2)
        allow(builder1).to receive(:run).and_return("project_name:build_id_1")
        allow(builder2).to receive(:run).and_return("project_name:build_id_2")
        allow(builder1).to receive(:running?).and_return(true)
        allow(builder2).to receive(:running?).and_return(false)
        allow_any_instance_of(Drunker::Executor).to receive(:loop).and_yield
      end

      it "calls sleep in loop" do
        expect_any_instance_of(Object).to receive(:sleep)
        executor.run
      end
    end

    context "when all builders are successed" do
      let(:concurrency) { 2 }
      let(:builder1) { double("builder stub") }
      let(:builder2) { double("builder stub") }

      before do
        allow(Drunker::Executor::Builder).to receive(:new)
                                               .with(project_name: "drunker-executor-1483196400",
                                                     commands: commands,
                                                     targets: %w(lib/drunker.rb lib/drunker/cli.rb),
                                                     artifact: artifact,
                                                     logger: instance_of(Logger))
                                               .and_return(builder1)
        allow(Drunker::Executor::Builder).to receive(:new)
                                               .with(project_name: "drunker-executor-1483196400",
                                                     commands: commands,
                                                     targets: %w(lib/drunker/version.rb),
                                                     artifact: artifact,
                                                     logger: instance_of(Logger))
                                               .and_return(builder2)
        allow(builder1).to receive(:run).and_return("project_name:build_id_1")
        allow(builder2).to receive(:run).and_return("project_name:build_id_2")
        allow(builder1).to receive(:running?).and_return(false)
        allow(builder2).to receive(:running?).and_return(false)
        allow_any_instance_of(Drunker::Executor).to receive(:loop).and_yield
      end

      it "does not call sleep in loop" do
        expect_any_instance_of(Object).not_to receive(:sleep)
        executor.run
      end
    end
  end
end
