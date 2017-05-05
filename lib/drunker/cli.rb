module Drunker
  class CLI < Thor
    desc "run", "Run a command on CodeBuild"
    method_option :concurrency, :type => :numeric, :default => 1
    method_option :loglevel, :type => :string, :default => "INFO", :enum => %w(debug DEBUG info INFO warn WARN error ERROR fatal FATAL)
    method_option :debug, :type => :boolean, :default => false
    def _run(image, *commands)
      config = Drunker::Config.new(image: image, commands: commands, concurrency: options[:concurrency], debug: options[:debug])
      loglevel = config.debug? ? "DEBUG" : options[:loglevel].upcase
      logger = Logger.new(STDERR).tap do |logger|
        logger.level = Logger.const_get(loglevel)
        logger.formatter = Proc.new { |severity, _datetime, _progname, message| "#{severity}: #{message}\n" } unless loglevel == "DEBUG"
      end

      logger.info("Creating source....")
      source = Drunker::Source.new(Pathname.pwd, logger: logger)

      logger.info("Starting executor...")
      builders, artifact = Drunker::Executor.new(source: source, config: config, logger: logger).run

      logger.info("Starting aggregator...")
      aggregator = Drunker::Aggregator.create(builders: builders, artifact: artifact)
      aggregator.run

      unless config.debug?
        logger.info("Deleting source...")
        source.delete
        logger.info("Deleting artifact...")
        artifact.delete
      end

      exit aggregator.exit_status
    end
    map "run" => "_run" # "run" is a Thor reserved word and cannot be defined as command

    desc "version", "Show version"
    def version
      puts "Drunker #{VERSION}"
    end
  end
end
