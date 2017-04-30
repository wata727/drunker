module Drunker
  class CLI < Thor
    desc "exec", "Run a command on platform"
    def exec(*commands)
      source = Drunker::Source.new
      artifact = Drunker::Executor.new(source: source, commands: commands, image: "quay.io/actcat/ruby_rubocop").run
      puts artifact.output
      # aggregator
      source.delete
      artifact.delete
    end

    desc "version", "Print version"
    def version
      puts "Drunker #{VERSION}"
    end
  end
end
