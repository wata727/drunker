module Drunker
  class CLI < Thor
    desc "exec", "Run a command on platform"
    def exec(*commands)
      source = Drunker::Source.new
      # executor
      # aggregator
    end

    desc "version", "Print version"
    def version
      puts "Drunker #{VERSION}"
    end
  end
end
