module Drunker
  class CLI < Thor
    desc "run", "Run a command on CodeBuild"
    method_option :concurrency, :type => :numeric, :default => 1
    def _run(image, *commands)
      source = Drunker::Source.new(Pathname.pwd)
      artifact = Drunker::Executor.new(source: source, commands: commands, image: image, concurrency: options[:concurrency]).run
      puts artifact.output
      # aggregator
      source.delete
      artifact.delete
    end
    map "run" => "_run" # "run" is a Thor reserved word and cannot be defined as command

    desc "version", "Show version"
    def version
      puts "Drunker #{VERSION}"
    end
  end
end
