require "spec_helper"

RSpec.describe Drunker::CLI do
  context "#run" do
    let(:source) { double("source stub") }
    let(:executor) { double("executor stub") }
    let(:artifact) { double(output: "Artifact") }
    let(:logger) { Logger.new("/dev/null") }
    before do
      allow(Logger).to receive(:new).and_return(logger)
      allow(Drunker::Source).to receive(:new).and_return(source)
      allow(Drunker::Executor).to receive(:new).and_return(executor)
      allow(executor).to receive(:run).and_return(artifact)
      allow(source).to receive(:delete)
      allow(artifact).to receive(:delete)
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

    it "creates new executor with arguments" do
      expect(Drunker::Executor).to receive(:new).with(source: source,
                                                      commands: ["rubocop", "--fail-level=F", "FILES"],
                                                      image: "wata727/rubocop",
                                                      concurrency: 1,
                                                      logger: logger)
                                       .and_return(executor)
      Drunker::CLI.start(%w(run wata727/rubocop rubocop --fail-level=F FILES))
    end

    it "creates new executor with concurrency option" do
      expect(Drunker::Executor).to receive(:new).with(source: source,
                                                      commands: ["rubocop", "--fail-level=F", "FILES"],
                                                      image: "wata727/rubocop",
                                                      concurrency: 10,
                                                      logger: logger)
                                       .and_return(executor)
      Drunker::CLI.start(%w(run --concurrency=10 wata727/rubocop rubocop --fail-level=F FILES))
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

    it "outputs artifact" do
      expect{ Drunker::CLI.start(%w(run wata727/rubocop rubocop --fail-level=F FILES)) }.to output("Artifact\n").to_stdout
    end
  end

  context "#version" do
    it "shows version" do
      expect { Drunker::CLI.start(%w(version)) }.to output("Drunker #{Drunker::VERSION}\n").to_stdout
    end
  end
end
