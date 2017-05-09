require "spec_helper"

RSpec.describe Drunker::Executor do
  let(:commands) { %w(rubocop --fail-level=F FILES) }
  let(:image) { "wata727/rubocop" }
  let(:concurrency) { 1 }
  let(:compute_type) { "BUILD_GENERAL1_SMALL" }
  let(:environment_variables) { [] }
  let(:aws_opts) { double("AWS options stub") }
  let(:config) do
    double(
      image: image,
      commands: commands,
      concurrency: concurrency,
      timeout: 60,
      compute_type: compute_type,
      environment_variables: environment_variables,
      aws_client_options: aws_opts,
    )
  end
  let(:client) { double("client stub") }
  let(:executor) { Drunker::Executor.new(source: source, config: config, logger: Logger.new("/dev/null")) }
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
  let(:time) { Time.local(2017) }
  before do
    Timecop.freeze(time)
    allow(Aws::CodeBuild::Client).to receive(:new).with(aws_opts).and_return(client)
    allow(Drunker::Artifact).to receive(:new).and_return(artifact)
    allow(config).to receive(:debug?).and_return(false)
  end
  after { Timecop.return }

  describe "#initialize" do
    it "uses CodeBuild client with config options" do
      expect(Aws::CodeBuild::Client).to receive(:new).with(aws_opts).and_return(client)
      expect(executor.instance_variable_get(:@client)).to eq client
    end

    it "sets attributes" do
      expect(executor.instance_variable_get(:@project_name)).to eq "drunker-executor-#{time.to_i}"
      expect(executor.instance_variable_get(:@source)).to eq source
      expect(executor.instance_variable_get(:@artifact)).to eq artifact
      expect(executor.instance_variable_get(:@config)).to eq config
    end

    it "creates and sets artifact" do
      expect(Drunker::Artifact).to receive(:new).with(config: config, logger: instance_of(Logger)).and_return(artifact)
      expect(executor.instance_variable_get(:@artifact)).to eq artifact
    end
  end

  describe "#run" do
    let(:iam) { double(role: double(name: "drunker-service-role")) }
    let(:client) { double("codebuild clinet stub") }
    let(:builder1) { double(build_id: "project_name:build_id_1") }
    let(:builder2) { double(build_id: "project_name:build_id_2") }
    let(:builder3) { double(build_id: "project_name:build_id_3") }
    let(:project_info) do
      {
        name: "drunker-executor-#{time.to_i}",
        source: { type: "Source" },
        artifacts: { type: "Artifact" },
        environment: {
          type: "LINUX_CONTAINER",
          image: "wata727/rubocop",
          compute_type: "BUILD_GENERAL1_SMALL",
        },
        service_role: "drunker-service-role",
        timeout_in_minutes: 60,
      }
    end

    before do
      allow(Aws::CodeBuild::Client).to receive(:new).and_return(client)
      allow(Drunker::Executor::IAM).to receive(:new).and_return(iam)
      allow(client).to receive(:create_project)
      allow(Drunker::Executor::Builder).to receive(:new).and_return(builder1)
      allow(builder1).to receive(:run).and_return("project_name:build_id_1")
      allow(builder2).to receive(:run).and_return("project_name:build_id_2")
      allow(builder3).to receive(:run).and_return("project_name:build_id_3")
      allow(builder1).to receive(:access_denied?).and_return(false)
      allow(builder2).to receive(:access_denied?).and_return(false)
      allow(builder3).to receive(:access_denied?).and_return(false)
      allow(builder1).to receive(:running?).and_return(false)
      allow(builder2).to receive(:running?).and_return(false)
      allow(builder3).to receive(:running?).and_return(false)
      allow(builder1).to receive(:failed?).and_return(false)
      allow(builder2).to receive(:failed?).and_return(false)
      allow(builder3).to receive(:failed?).and_return(false)
      allow(builder1).to receive(:refresh)
      allow(builder2).to receive(:refresh)
      allow(builder3).to receive(:refresh)
      allow(artifact).to receive(:layers)
      allow(iam).to receive(:delete)
      allow(client).to receive(:delete_project)
      allow_any_instance_of(Object).to receive(:sleep)
    end

    it "creates and deletes IAM" do
      expect(Drunker::Executor::IAM).to receive(:new).with(source: source, artifact: artifact, config: config, logger: instance_of(Logger)).and_return(iam)
      expect(iam).to receive(:delete)
      executor.run
    end

    it "creates and deletes project" do
      expect(client).to receive(:create_project).with(project_info)
      expect(client).to receive(:delete_project).with(name: "drunker-executor-#{time.to_i}")
      executor.run
    end

    it "returns artifact" do
      expect(artifact).to receive(:layers)
      expect(executor.run).to eq artifact
    end

    context "when environment variables are configured" do
      let(:environment_variables) do
        [
          { name: "RAILS_ENV", value: "test" },
          { name: "SECRET_KEY_BASE", value: "super secret" },
        ]
      end

      it "creates project with project_info including environment variables" do
        expect(client).to receive(:create_project).with({
                                                           name: "drunker-executor-#{time.to_i}",
                                                           source: { type: "Source" },
                                                           artifacts: { type: "Artifact" },
                                                           environment: {
                                                             type: "LINUX_CONTAINER",
                                                             image: "wata727/rubocop",
                                                             compute_type: "BUILD_GENERAL1_SMALL",
                                                             environment_variables: environment_variables
                                                           },
                                                           service_role: "drunker-service-role",
                                                           timeout_in_minutes: 60,
                                                        })
        executor.run
      end
    end

    context "when enabled debug mode" do
      before { allow(config).to receive(:debug?).and_return(true) }

      it "creates IAM, but does not delete it" do
        expect(Drunker::Executor::IAM).to receive(:new).with(source: source, artifact: artifact, config: config, logger: instance_of(Logger)).and_return(iam)
        expect(iam).not_to receive(:delete)
        executor.run
      end

      it "creates project, but does not delete it" do
        expect(client).to receive(:create_project).with(project_info)
        expect(client).not_to receive(:delete_project)
        executor.run
      end
    end

    context "when happened `CodeBuild is not authorized to perform: sts:AssumeRole` error" do
      let(:exception) { Aws::CodeBuild::Errors::InvalidInputException.new(nil, "CodeBuild is not authorized to perform: sts:AssumeRole") }
      it "retries create_project at 10 times" do
        expect(client).to receive(:create_project).with(project_info).exactly(11).times.and_raise(exception)
        expect { executor.run }.to raise_error(exception)
      end
    end

    context "when target files is 3 and concurrency is 1" do
      it "creates 1 builder" do
        expect(Drunker::Executor::Builder).to receive(:new)
                                                .with(project_name: "drunker-executor-#{time.to_i}",
                                                      targets: %w(lib/drunker.rb lib/drunker/cli.rb lib/drunker/version.rb),
                                                      artifact: artifact,
                                                      config: config,
                                                      logger: instance_of(Logger))
                                                .and_return(builder1)
        executor.run
      end

      it "runs 1 builder" do
        expect(builder1).to receive(:run)
        executor.run
      end

      it "sets 1 build to artifact" do
        expect(artifact).to receive(:set_build).with("project_name:build_id_1")
        executor.run
      end
    end

    context "when target files is 3 and concurrency is 2" do
      let(:concurrency) { 2 }

      before do
        allow(Drunker::Executor::Builder).to receive(:new)
                                               .with(project_name: "drunker-executor-#{time.to_i}",
                                                     targets: %w(lib/drunker.rb lib/drunker/cli.rb),
                                                     artifact: artifact,
                                                     config: config,
                                                     logger: instance_of(Logger))
                                               .and_return(builder1)
        allow(Drunker::Executor::Builder).to receive(:new)
                                               .with(project_name: "drunker-executor-#{time.to_i}",
                                                     targets: %w(lib/drunker/version.rb),
                                                     artifact: artifact,
                                                     config: config,
                                                     logger: instance_of(Logger))
                                               .and_return(builder2)
      end

      it "creates 2 builders" do
        expect(Drunker::Executor::Builder).to receive(:new)
                                                .with(project_name: "drunker-executor-#{time.to_i}",
                                                      targets: %w(lib/drunker.rb lib/drunker/cli.rb),
                                                      artifact: artifact,
                                                      config: config,
                                                      logger: instance_of(Logger))
                                                .and_return(builder1)
        expect(Drunker::Executor::Builder).to receive(:new)
                                                .with(project_name: "drunker-executor-#{time.to_i}",
                                                      targets: %w(lib/drunker/version.rb),
                                                      artifact: artifact,
                                                      config: config,
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

      before do
        allow(Drunker::Executor::Builder).to receive(:new)
                                               .with(project_name: "drunker-executor-#{time.to_i}",
                                                     targets: %w(lib/drunker.rb),
                                                     artifact: artifact,
                                                     config: config,
                                                     logger: instance_of(Logger))
                                               .and_return(builder1)
        allow(Drunker::Executor::Builder).to receive(:new)
                                               .with(project_name: "drunker-executor-#{time.to_i}",
                                                     targets: %w(lib/drunker/cli.rb),
                                                     artifact: artifact,
                                                     config: config,
                                                     logger: instance_of(Logger))
                                               .and_return(builder2)
        allow(Drunker::Executor::Builder).to receive(:new)
                                               .with(project_name: "drunker-executor-#{time.to_i}",
                                                     targets: %w(lib/drunker/version.rb),
                                                     artifact: artifact,
                                                     config: config,
                                                     logger: instance_of(Logger))
                                               .and_return(builder3)
      end

      it "creates 3 builders" do
        expect(Drunker::Executor::Builder).to receive(:new)
                                                .with(project_name: "drunker-executor-#{time.to_i}",
                                                      targets: %w(lib/drunker.rb),
                                                      artifact: artifact,
                                                      config: config,
                                                      logger: instance_of(Logger))
                                                .and_return(builder1)
        expect(Drunker::Executor::Builder).to receive(:new)
                                                .with(project_name: "drunker-executor-#{time.to_i}",
                                                      targets: %w(lib/drunker/cli.rb),
                                                      artifact: artifact,
                                                      config: config,
                                                      logger: instance_of(Logger))
                                                .and_return(builder2)
        expect(Drunker::Executor::Builder).to receive(:new)
                                                .with(project_name: "drunker-executor-#{time.to_i}",
                                                      targets: %w(lib/drunker/version.rb),
                                                      artifact: artifact,
                                                      config: config,
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

    context "when running multiple builder" do
      let(:concurrency) { 2 }

      before do
        allow(Drunker::Executor::Builder).to receive(:new)
                                               .with(project_name: "drunker-executor-#{time.to_i}",
                                                     targets: %w(lib/drunker.rb lib/drunker/cli.rb),
                                                     artifact: artifact,
                                                     config: config,
                                                     logger: instance_of(Logger))
                                               .and_return(builder1)
        allow(Drunker::Executor::Builder).to receive(:new)
                                               .with(project_name: "drunker-executor-#{time.to_i}",
                                                     targets: %w(lib/drunker/version.rb),
                                                     artifact: artifact,
                                                     config: config,
                                                     logger: instance_of(Logger))
                                               .and_return(builder2)
        allow_any_instance_of(Drunker::Executor).to receive(:loop).and_yield
      end

      context "and all builders are running" do
        before do
          allow(builder1).to receive(:running?).and_return(true)
          allow(builder2).to receive(:running?).and_return(true)
        end

        it "calls sleep in loop" do
          expect_any_instance_of(Object).to receive(:sleep)
          executor.run
        end
      end

      context "and 1 builder is running yet" do
        before do
          allow(builder1).to receive(:running?).and_return(true)
        end

        it "calls sleep in loop" do
          expect_any_instance_of(Object).to receive(:sleep)
          executor.run
        end
      end

      context "and all builders are successed" do
        it "does not call sleep in loop" do
          expect_any_instance_of(Object).not_to receive(:sleep)
          executor.run
        end
      end

      context "and 1 builder has access denied error" do
        before do
          allow(builder1).to receive(:access_denied?).and_return(true)
          allow(builder1).to receive(:running?).and_return(true)
          allow(builder1).to receive(:retry).and_return("project_name:build_id_1_retry")
          allow(artifact).to receive(:replace_build)
        end

        context "and builder is retriable" do
          before { allow(builder1).to receive(:retriable?).and_return(true) }

          it "reties only access denieded builder" do
            expect(builder1).to receive(:retry).and_return("project_name:build_id_1_retry")
            expect(builder2).not_to receive(:retry)
            executor.run
          end

          it "replaces access denieded build id" do
            expect(artifact).to receive(:replace_build).with(before: "project_name:build_id_1", after: "project_name:build_id_1_retry")
            executor.run
          end
        end

        context "and builder is not retriable" do
          before { allow(builder1).to receive(:retriable?).and_return(false) }

          it "does not retry all builders" do
            expect(builder1).not_to receive(:retry)
            expect(builder2).not_to receive(:retry)
            executor.run
          end

          it "does not replace build id" do
            expect(artifact).not_to receive(:replace_build)
            executor.run
          end
        end
      end
    end
  end
end
