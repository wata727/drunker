module Drunker
  class Aggregator
    class Pretty < Base
      def run
        artifact.output.each do |build, body|
          builder = builders.find { |builder| builder.build_id == build }

          puts
          puts "-------------------------------------------------------------------------------------------"
          puts "BUILD_ID: #{build}"
          puts "RESULT: #{builder.success? ? "SUCCESS" : "FAILED"}"
          puts "STDOUT: #{body[:stdout]}" unless body[:stdout] == Drunker::Artifact::NOT_FOUND
          puts "STDERR: #{body[:stderr]}" unless body[:stderr] == Drunker::Artifact::NOT_FOUND
          puts "EXIT_STATUS: #{body[:exit_status]}" unless body[:exit_status] == Drunker::Artifact::NOT_FOUND
          puts "-------------------------------------------------------------------------------------------"
          puts
        end
      end

      def exit_status
        artifact.output.map do |_build, body|
          body[:exit_status] == Drunker::Artifact::NOT_FOUND ? 1 : body[:exit_status].to_i
        end.max
      end
    end
  end
end
