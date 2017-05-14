require "spec_helper"

RSpec.describe Drunker::Aggregator do
  let(:config) { double(aggregator: nil) }
  let(:aggregator) { Drunker::Aggregator.create(config) }
  let(:pretty_aggregator) { double("pretty aggregator stub") }

  describe "#initialize" do
    it "returns pretty aggregator" do
      expect(aggregator).to be_an_instance_of(Drunker::Aggregator::Pretty)
    end

    context "when specified custom aggregator" do
      let(:config) { double(aggregator: double(name: "drunker-aggregator-test")) }

      it "returns custom aggregator" do
        expect_any_instance_of(Kernel).to receive(:require).with("drunker-aggregator-test")
        expect(aggregator).to be_an_instance_of(Drunker::Aggregator::Test)
      end
    end
  end
end
