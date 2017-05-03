module Drunker
  class CLI < Thor
    desc "run", "Run a command on CodeBuild"
    method_option :concurrency, :type => :numeric, :default => 1
    method_option :loglevel, :type => :string, :default => "INFO", :enum => %w(debug DEBUG info INFO warn WARN error ERROR fatal FATAL)
    def _run(image, *commands)
      logger = Logger.new(STDERR).tap do |logger|
        logger.level = Logger.const_get(options[:loglevel].upcase)
      end
      logger.info("Creating source....")
      source = Drunker::Source.new(Pathname.pwd, logger: logger)
      logger.info("Starting executor...")
      artifact = Drunker::Executor.new(source: source, commands: commands, image: image, concurrency: options[:concurrency], logger: logger).run
      puts artifact.output
      # aggregator
      logger.info("Deleting source...")
      source.delete
      logger.info("Deleting artifact...")
      artifact.delete
    end
    map "run" => "_run" # "run" is a Thor reserved word and cannot be defined as command

    desc "version", "Show version"
    def version
      puts "Drunker #{VERSION}"
    end
  end
end
