module Drunker
  class Artifact
    class Layer
      attr_reader :build_id
      attr_reader :exit_status
      attr_accessor :stdout
      attr_accessor :stderr

      def initialize(build_id:, stdout: nil, stderr: nil, exit_status: nil)
        @build_id = build_id
        @stdout = stdout
        @stderr = stderr
        @exit_status = exit_status.to_i
        @invalid = false
      end

      def exit_status=(exit_status)
        @exit_status = exit_status.to_i
      end

      def invalid?
        @invalid
      end

      def invalid!
        @invalid = true
      end
    end
  end
end
