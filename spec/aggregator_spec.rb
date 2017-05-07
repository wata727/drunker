require "spec_helper"

RSpec.describe Drunker::Aggregator do
  let(:config) { double(aggregator: double(name: "drunker-aggregator-pretty")) }
  let(:aggregator) { Drunker::Aggregator.create(config) }
  let(:pretty_aggregator) { double("pretty aggregator stub") }

  describe "#initialize" do
    it "returns pretty aggregator" do
      expect(aggregator).to be_an_instance_of(Drunker::Aggregator::Pretty)
    end
  end
end
