module Drunker
  class Aggregator
    def self.create(config)
      if config.aggregator
        require config.aggregator.name
        klass = Object.const_get(config.aggregator.name.split("-").map(&:capitalize).join("::"))
        klass.new
      else
        Pretty.new
      end
    end
  end
end
