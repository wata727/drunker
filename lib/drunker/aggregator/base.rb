module Drunker
  class Aggregator
    class Base
      attr_reader :builders
      attr_reader :artifact

      def initialize(builders:, artifact:)
        @builders = builders
        @artifact = artifact
      end

      def run
        raise NotImplementedError.new("You must implement #{self.class}##{__method__}")
      end

      def exit_status
        raise NotImplementedError.new("You must implement #{self.class}##{__method__}")
      end
    end
  end
end