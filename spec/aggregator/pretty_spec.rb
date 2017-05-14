require "spec_helper"

RSpec.describe Drunker::Aggregator::Pretty do
  let(:aggregator) { Drunker::Aggregator::Pretty.new }
  let(:layers) do
    [
      Drunker::Artifact::Layer.new(
        build_id: "project_name:build_id_1",
        stdout: "Success!",
        stderr: "warning!",
        exit_status: 0,
      ),
      Drunker::Artifact::Layer.new(
        build_id: "project_name:build_id_2",
        stdout: "Trying...",
        stderr: "Failed...",
        exit_status: 1,
      )
    ]
  end

  describe "#run" do
    it "outputs pretty print" do
      output =<<OUTPUT

-------------------------------------------------------------------------------------------
BUILD_ID: project_name:build_id_1
RESULT: SUCCESS
STDOUT: Success!
STDERR: warning!
EXIT_STATUS: 0
-------------------------------------------------------------------------------------------


-------------------------------------------------------------------------------------------
BUILD_ID: project_name:build_id_2
RESULT: SUCCESS
STDOUT: Trying...
STDERR: Failed...
EXIT_STATUS: 1
-------------------------------------------------------------------------------------------

OUTPUT
      expect { aggregator.run(layers) }.to output(output).to_stdout
    end

    context "when artifact layer is invalid" do
      before { layers.each(&:invalid!) }

      it "outputs pretty print" do
        output =<<OUTPUT

-------------------------------------------------------------------------------------------
BUILD_ID: project_name:build_id_1
RESULT: FAILED
-------------------------------------------------------------------------------------------


-------------------------------------------------------------------------------------------
BUILD_ID: project_name:build_id_2
RESULT: FAILED
-------------------------------------------------------------------------------------------

OUTPUT
        expect { aggregator.run(layers) }.to output(output).to_stdout
      end
    end
  end

  describe "#exit_status" do
    it "returns 1 as exit status code" do
      expect(aggregator.exit_status(layers)).to eq 1
    end

    context "when artifact layer is invalid" do
      before { layers.each(&:invalid!) }

      it "returns 1 as exit status code" do
        expect(aggregator.exit_status(layers)).to eq 1
      end
    end
  end
end
