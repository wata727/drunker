module Drunker
  class Aggregator
    def self.create(builders:, artifact:)
      Pretty.new(builders: builders, artifact: artifact)
    end
  end
end
