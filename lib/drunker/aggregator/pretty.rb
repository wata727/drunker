module Drunker
  class Aggregator
    class Pretty < Base
      def run
        artifact.output.each do |build, stdout|
          builder = builders.find { |builder| builder.build_id == build }

          puts
          puts "-----------------------------------Build ID: #{build}-----------------------------------"
          puts "RESULT: #{builder.success? ? "SUCCESS" : "FAILED"}"
          puts "STDOUT: #{stdout}"
          puts "-------------------------------------------------------------------------------------------"
          puts
        end
      end
    end
  end
end
