module Drunker
  class CLI < Thor
    desc "exec", "Run a command on CodeBuild"
    method_option :concurrency, :type => :numeric, :default => 10
    def exec(image, *commands)
      source = Drunker::Source.new
      artifact = Drunker::Executor.new(source: source, commands: commands, image: image, concurrency: options[:concurrency]).run
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
