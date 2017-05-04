module Drunker
  class Aggregator
    class Pretty < Base
      def run
        artifact.output.each do |build, body|
          builder = builders.find { |builder| builder.build_id == build }

          puts
          puts "-----------------------------------Build ID: #{build}-----------------------------------"
          puts "RESULT: #{builder.success? ? "SUCCESS" : "FAILED"}"
          puts "STDOUT: #{body[:stdout]}"
          puts "STDERR: #{body[:stderr]}"
          puts "STATUS_CODE: #{body[:status_code]}"
          puts "-------------------------------------------------------------------------------------------"
          puts
        end
      end

      def exit_status
        0
      end
    end
  end
end
