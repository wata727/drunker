require "spec_helper"

RSpec.describe Drunker::Artifact::Layer do
  let(:build_id) { "project_name:build_1" }
  let(:layer) { Drunker::Artifact::Layer.new(build_id: build_id) }

  describe "#initialize" do
    before do
      layer.stdout = "stdout"
      layer.stderr = "stderr"
      layer.exit_status = "1"
    end

    it "creates layer" do
      expect(layer).to have_attributes(build_id: build_id, stdout: "stdout", stderr: "stderr", exit_status: 1)
    end
  end

  describe "#invalid?" do
    it "returns false" do
      expect(layer.invalid?).to be false
    end

    context "when layer is invalid" do
      before { layer.instance_variable_set(:@invalid, true) }

      it "returns true" do
        expect(layer.invalid?).to be true
      end
    end
  end

  describe "#invalid!" do
    it "changes invalid flag" do
      expect { layer.invalid! }.to change { layer.instance_variable_get(:@invalid) } # rubocop:disable Lint/AmbiguousBlockAssociation
    end
  end
end
