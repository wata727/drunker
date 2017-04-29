module Drunker
  class CLI < Thor
    desc "exec", "Run a command on platform"
    def exec(*commands)
      source = Drunker::Source.new
      Drunker::Executor.new(source: source, commands: commands, image: "quay.io/actcat/ruby_rubocop").run
      # aggregator
    end

    desc "version", "Print version"
    def version
      puts "Drunker #{VERSION}"
    end
  end
end
