module Drunker
  class Aggregator
    class Base
      def run(layers)
        raise NotImplementedError.new("You must implement #{self.class}##{__method__}")
      end

      def exit_status(layers)
        raise NotImplementedError.new("You must implement #{self.class}##{__method__}")
      end
    end
  end
end