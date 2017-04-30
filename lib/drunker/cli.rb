module Drunker
  class CLI < Thor
    desc "exec", "Run a command on CodeBuild"
    def exec(image, *commands)
      source = Drunker::Source.new
      artifact = Drunker::Executor.new(source: source, commands: commands, image: image).run
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
