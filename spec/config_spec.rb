require "spec_helper"

RSpec.describe Drunker::Config do
  let(:image) { "wata727/rubocop" }
  let(:commands) { %w(rubocop --fail-level=F FILES) }
  let(:concurrency) { 1 }
  let(:debug) { false }
  let(:config) { Drunker::Config.new(image: image, commands: commands, concurrency: concurrency, debug: debug) }

  describe "#initialize" do
    it "sets attributes" do
      expect(config.image).to eq image
      expect(config.commands).to eq commands
      expect(config.concurrency).to eq concurrency
      expect(config.instance_variable_get(:@debug)).to eq debug
    end
  end

  describe "#debug?" do
    it "returns false" do
      expect(config.debug?).to be false
    end

    context "when enabled debug mode" do
      let(:debug) { true }
      it "returns true" do
        expect(config.debug?).to be true
      end
    end
  end
end
