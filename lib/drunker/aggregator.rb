module Drunker
  class Aggregator
    def self.create(config)
      require config.aggregator.name
      klass = Object.const_get(config.aggregator.name.split("-").map(&:capitalize).join("::"))
      klass.new
    end
  end
end
