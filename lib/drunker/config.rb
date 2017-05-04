module Drunker
  class Config
    attr_reader :image
    attr_reader :commands
    attr_reader :concurrency

    def initialize(image:, commands:, concurrency: ,debug:)
      @image = image
      @commands = commands
      @concurrency = concurrency
      @debug = debug
    end

    def debug?
      debug
    end

    private

    attr_reader :debug
  end
end
