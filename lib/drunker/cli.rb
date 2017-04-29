module Drunker
  class CLI < Thor
    desc "exec", "Run a command on platform"
    def exec(*commands)
      Drunker::PreProcessor.new.run
      # executor
      # aggregator
    end

    desc "version", "Print version"
    def version
      puts "Drunker #{VERSION}"
    end
  end
end
