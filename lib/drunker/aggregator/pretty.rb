module Drunker
  class Aggregator
    class Pretty < Base
      def run(layers)
        layers.each do |layer|
          puts
          puts "-------------------------------------------------------------------------------------------"
          puts "BUILD_ID: #{layer.build_id}"
          if layer.invalid?
            puts "RESULT: FAILED"
          else
            puts "RESULT: SUCCESS"
            puts "STDOUT: #{layer.stdout}"
            puts "STDERR: #{layer.stderr}"
            puts "EXIT_STATUS: #{layer.exit_status}"
          end
          puts "-------------------------------------------------------------------------------------------"
          puts
        end
      end

      def exit_status(layers)
        layers.map { |layer| layer.invalid? ? 1 : layer.exit_status }.max
      end
    end
  end
end
