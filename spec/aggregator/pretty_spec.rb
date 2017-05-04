require "spec_helper"

RSpec.describe Drunker::Aggregator::Pretty do
  let(:builder1) { double("project_name:builder stub") }
  let(:builder2) { double("project_name:builder stub") }
  let(:builders) { [builder1, builder2] }
  let(:artifact) { double("artifact stub") }
  let(:aggregator) { Drunker::Aggregator::Pretty.new(builders: builders, artifact: artifact) }

  describe "#run" do
    before do
      allow(builder1).to receive(:build_id).and_return("project_name:build_id_1")
      allow(builder2).to receive(:build_id).and_return("project_name:build_id_2")
      allow(builder1).to receive(:success?).and_return(true)
      allow(builder2).to receive(:success?).and_return(false)
      allow(artifact).to receive(:output).and_return("project_name:build_id_1" => "Success!", "project_name:build_id_2" => "Failed...")
    end

    it "outputs pretty print" do
      output =<<OUTPUT

-----------------------------------Build ID: project_name:build_id_1-----------------------------------
RESULT: SUCCESS
STDOUT: Success!
-------------------------------------------------------------------------------------------


-----------------------------------Build ID: project_name:build_id_2-----------------------------------
RESULT: FAILED
STDOUT: Failed...
-------------------------------------------------------------------------------------------

OUTPUT
      expect { aggregator.run }.to output(output).to_stdout
    end
  end
end
