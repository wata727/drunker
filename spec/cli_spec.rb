require "spec_helper"

RSpec.describe Drunker::CLI do
  describe "#run" do
    let(:config) { double("config stub") }
    let(:source) { double("source stub") }
    let(:executor) { double("executor stub") }
    let(:builders) { [double("builder stub")] }
    let(:artifact) { double("artifact stub") }
    let(:aggregator) { double(exit_status: 0) }
    let(:logger) { Logger.new("/dev/null") }
    before do
      allow(Drunker::Config).to receive(:new).and_return(config)
      allow(config).to receive(:debug?).and_return(false)
      allow(Logger).to receive(:new).and_return(logger)
      allow(Drunker::Source).to receive(:new).and_return(source)
      allow(Drunker::Executor).to receive(:new).and_return(executor)
      allow(executor).to receive(:run).and_return([builders, artifact])
      allow(Drunker::Aggregator).to receive(:create).and_return(aggregator)
      allow(aggregator).to receive(:run)
      allow(source).to receive(:delete)
      allow(artifact).to receive(:delete)
      allow_any_instance_of(Object).to receive(:exit)
    end

    it "creates new source" do
      expect(logger).to receive(:level=).with(Logger::INFO)
      expect(Drunker::Source).to receive(:new).with(Pathname.pwd, logger: logger).and_return(source)
      Drunker::CLI.start(%w(run wata727/rubocop rubocop --fail-level=F FILES))
    end

    it "sets log level" do
      expect(logger).to receive(:level=).with(Logger::DEBUG)
      Drunker::CLI.start(%w(run --loglevel=debug wata727/rubocop rubocop --fail-level=F FILES))
    end

    it "creates new executor" do
      expect(Drunker::Config).to receive(:new).with(image: "wata727/rubocop",
                                                    commands: %w(rubocop --fail-level=F FILES),
                                                    concurrency: 1,
                                                    debug: false)
                                              .and_return(config)
      expect(Drunker::Executor).to receive(:new).with(source: source, config: config, logger: logger).and_return(executor)
      Drunker::CLI.start(%w(run wata727/rubocop rubocop --fail-level=F FILES))
    end

    it "runs executor" do
      expect(executor).to receive(:run).and_return([builders, artifact])
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
      expect(Drunker::Aggregator).to receive(:create).with(builders: builders, artifact: artifact).and_return(aggregator)
      expect(aggregator).to receive(:run)
      expect_any_instance_of(Object).to receive(:exit).with(0)
      Drunker::CLI.start(%w(run wata727/rubocop rubocop --fail-level=F FILES))
    end

    context "when exit_status is 1" do
      let(:aggregator) { double(exit_status: 1) }

      it "returns 1 as exit status code" do
        expect_any_instance_of(Object).to receive(:exit).with(1)
        Drunker::CLI.start(%w(run wata727/rubocop rubocop --fail-level=F FILES))
      end
    end

    context "when enabled debug mode" do
      before { allow(config).to receive(:debug?).and_return(true) }

      it "creates new executor with modified config" do
        expect(logger).to receive(:level=).with(Logger::DEBUG)
        expect(Drunker::Config).to receive(:new).with(image: "wata727/rubocop",
                                                      commands: %w(rubocop --fail-level=F FILES),
                                                      concurrency: 10,
                                                      debug: true)
                                       .and_return(config)
        expect(Drunker::Executor).to receive(:new).with(source: source, config: config, logger: logger).and_return(executor)
        Drunker::CLI.start(%w(run --concurrency=10 --debug wata727/rubocop rubocop --fail-level=F FILES))
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
  end

  describe "#version" do
    it "shows version" do
      expect { Drunker::CLI.start(%w(version)) }.to output("Drunker #{Drunker::VERSION}\n").to_stdout
    end
  end
end
