require "spec_helper"

RSpec.describe Drunker::CLI do
  describe "#run" do
    let(:config) { double("config stub") }
    let(:source) { double("source stub") }
    let(:executor) { double("executor stub") }
    let(:layers) { double("artifact layers stub") }
    let(:artifact) { double(layers: layers) }
    let(:aggregator) { double("aggregator stub") }
    let(:logger) { Logger.new("/dev/null") }
    before do
      allow(Drunker::Config).to receive(:new).and_return(config)
      allow(config).to receive(:debug?).and_return(false)
      allow(Logger).to receive(:new).and_return(logger)
      allow(Drunker::Source).to receive(:new).and_return(source)
      allow(Drunker::Executor).to receive(:new).and_return(executor)
      allow(executor).to receive(:run).and_return(artifact)
      allow(Drunker::Aggregator).to receive(:create).and_return(aggregator)
      allow(aggregator).to receive(:run)
      allow(aggregator).to receive(:exit_status).and_return(0)
      allow(source).to receive(:delete)
      allow(artifact).to receive(:delete)
      allow_any_instance_of(Object).to receive(:exit)
    end

    it "creates new source" do
      expect(logger).to receive(:level=).with(Logger::INFO)
      expect(logger).to receive(:formatter=)
      expect(Drunker::Source).to receive(:new).with(Pathname.pwd, config: config, logger: logger).and_return(source)
      Drunker::CLI.start(%w(run wata727/rubocop rubocop --fail-level=F FILES))
    end

    it "sets log level" do
      expect(logger).to receive(:level=).with(Logger::DEBUG)
      expect(logger).not_to receive(:formatter=)
      Drunker::CLI.start(%w(run --loglevel=debug wata727/rubocop rubocop --fail-level=F FILES))
    end

    it "creates new executor" do
      expect(Drunker::Config).to receive(:new).with(image: "wata727/rubocop",
                                                    commands: %w(rubocop --fail-level=F FILES),
                                                    config: ".drunker.yml",
                                                    concurrency: 1,
                                                    compute_type: "small",
                                                    timeout: 60,
                                                    env: {},
                                                    buildspec: nil,
                                                    file_pattern: "**/*",
                                                    aggregator: "pretty",
                                                    debug: false,
                                                    access_key: nil,
                                                    secret_key: nil,
                                                    region: nil,
                                                    profile_name: nil,
                                                    logger: logger)
                                   .and_return(config)
      expect(Drunker::Executor).to receive(:new).with(source: source, config: config, logger: logger).and_return(executor)
      Drunker::CLI.start(%w(run wata727/rubocop rubocop --fail-level=F FILES))
    end

    it "runs executor" do
      expect(executor).to receive(:run).and_return(artifact)
      Drunker::CLI.start(%w(run wata727/rubocop rubocop --fail-level=F FILES))
    end

    it "deletes source" do
      expect(source).to receive(:delete)
      Drunker::CLI.start(%w(run wata727/rubocop rubocop --fail-level=F FILES))
    end

    it "deletes artifact" do
      expect(artifact).to receive(:delete)
      Drunker::CLI.start(%w(run wata727/rubocop rubocop --fail-level=F FILES))
    end

    it "runs aggregator" do
      expect(Drunker::Aggregator).to receive(:create).and_return(aggregator)
      expect(aggregator).to receive(:run).with(layers)
      expect(aggregator).to receive(:exit_status).with(layers).and_return(0)
      expect_any_instance_of(Object).to receive(:exit).with(0)
      Drunker::CLI.start(%w(run wata727/rubocop rubocop --fail-level=F FILES))
    end

    context "when exit_status is 1" do
      before do
        allow(aggregator).to receive(:exit_status).and_return(1)
      end

      it "returns 1 as exit status code" do
        expect_any_instance_of(Object).to receive(:exit).with(1)
        Drunker::CLI.start(%w(run wata727/rubocop rubocop --fail-level=F FILES))
      end
    end

    context "with modified config (enabled debug mode)" do
      before { allow(config).to receive(:debug?).and_return(true) }

      it "creates new executor" do
        expect(logger).to receive(:level=).with(Logger::DEBUG)
        expect(Drunker::Config).to receive(:new).with(image: "wata727/rubocop",
                                                      commands: %w(rubocop --fail-level=F FILES),
                                                      config: ".custom_drunker.yml",
                                                      concurrency: 10,
                                                      compute_type: "large",
                                                      timeout: 100,
                                                      env: { "RAILS_ENV" => "test", "SECRET_KEY_BASE" => "super_secret" },
                                                      buildspec: "custom_buildspec.yml.erb",
                                                      file_pattern: "spec/**/*_spec.rb",
                                                      aggregator: "rspec",
                                                      debug: true,
                                                      access_key: "ACCESS_KEY",
                                                      secret_key: "SECRET_KEY",
                                                      region: "us-east-1",
                                                      profile_name: "PROFILE_NAME",
                                                      logger: logger)
                                     .and_return(config)
        expect(Drunker::Executor).to receive(:new).with(source: source, config: config, logger: logger).and_return(executor)
        Drunker::CLI.start(%w(
          run
          --config=.custom_drunker.yml
          --concurrency=10
          --compute_type=large
          --timeout=100
          --env=RAILS_ENV:test SECRET_KEY_BASE:super_secret
          --buildspec=custom_buildspec.yml.erb
          --file-pattern=spec/**/*_spec.rb
          --aggregator=rspec
          --debug
          --access-key=ACCESS_KEY
          --secret-key=SECRET_KEY
          --region=us-east-1
          --profile-name=PROFILE_NAME
          wata727/rubocop
          rubocop
          --fail-level=F
          FILES
        ))
      end

      it "does not delete source" do
        expect(source).not_to receive(:delete)
        Drunker::CLI.start(%w(run --debug wata727/rubocop rubocop --fail-level=F FILES))
      end

      it "does not delete artifact" do
        expect(artifact).not_to receive(:delete)
        Drunker::CLI.start(%w(run --debug wata727/rubocop rubocop --fail-level=F FILES))
      end
    end

    context "when InvalidConfigException is raised" do
      before do
        allow(Drunker::Config).to receive(:new).and_raise(Drunker::Config::InvalidConfigException.new("something wrong"))
      end

      it "does not create source" do
        expect(Drunker::Source).not_to receive(:new)
        Drunker::CLI.start(%w(run wata727/rubocop rubocop --fail-level=F FILES))
      end

      it "outputs exception message" do
        expect(logger).to receive(:error).with("something wrong")
        Drunker::CLI.start(%w(run wata727/rubocop rubocop --fail-level=F FILES))
      end

      it "exits with 1" do
        expect_any_instance_of(Object).to receive(:exit).with(1)
        Drunker::CLI.start(%w(run wata727/rubocop rubocop --fail-level=F FILES))
      end
    end
  end

  describe "#version" do
    it "shows version" do
      expect { Drunker::CLI.start(%w(version)) }.to output("Drunker #{Drunker::VERSION}\n").to_stdout
    end
  end
end
