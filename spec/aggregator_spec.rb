require "spec_helper"

RSpec.describe Drunker::Aggregator do
  let(:builders) { [double("builder stub")] }
  let(:artifact) { double("artifact stub") }
  let(:aggregator) { Drunker::Aggregator.create(builders: builders, artifact: artifact) }
  let(:pretty_aggregator) { double("pretty aggregator stub") }

  describe "#initialize" do
    it "returns pretty aggregator" do
      expect(Drunker::Aggregator::Pretty).to receive(:new).with(builders: builders, artifact: artifact).and_return(pretty_aggregator)
      expect(aggregator).to eq pretty_aggregator
    end
  end
end
