module Drunker
  class Aggregator
    class Pretty < Base
      def run
        artifact.output.each do |build_id, stdout|
          builder = builders.find { |builder| builder.build_id == build_id }

          puts
          puts "-----------------------------------Build ID: #{build_id}-----------------------------------"
          puts "RESULT: #{builder.success? ? "SUCCESS" : "FAILED"}"
          puts "STDOUT: #{stdout}"
          puts "-------------------------------------------------------------------------------------------"
          puts
        end
      end
    end
  end
end
