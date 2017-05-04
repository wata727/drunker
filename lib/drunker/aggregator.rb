module Drunker
  class Aggregator
    def self.run(builders:, artifact:)
      Pretty.new(builders: builders, artifact: artifact).run
    end
  end
end
