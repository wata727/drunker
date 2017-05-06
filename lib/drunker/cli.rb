module Drunker
  class CLI < Thor
    desc "run [IMAGE] [COMMAND]", "Run a command on CodeBuild"
    method_option :concurrency, :type => :numeric, :default => 1, :desc => "Build concurrency"
    method_option :compute_type, :type => :string, :default => "small", :enum => %w(small medium large), :desc => "Container compute type"
    method_option :timeout, :type => :numeric, :default => 60, :desc => "Build timeout in minutes, should be between 5 and 480"
    method_option :env, :type => :hash, :default => {}, :desc => "Environment variables in containers"
    method_option :loglevel, :type => :string, :default => "info", :enum => %w(debug info warn error fatal), :desc => "Output log level"
    method_option :debug, :type => :boolean, :default => false, :desc => "Enable debug mode. This mode does not delete the AWS resources created by Drunker"
    method_option :access_key, :type => :string, :desc => "AWS access key token used by Drunker"
    method_option :secret_key, :type => :string, :desc => "AWS secret key token used by Drunker"
    method_option :region, :type => :string, :desc => "AWS region in which resources is created by Drunker"
    method_option :profile_name, :type => :string, :desc => "AWS shared profile name used by Drunker"
    def _run(image, *commands)
      loglevel = options[:debug] ? "DEBUG" : options[:loglevel].upcase
      logger = Logger.new(STDERR).tap do |logger|
        logger.level = Logger.const_get(loglevel)
        logger.formatter = Proc.new { |severity, _datetime, _progname, message| "#{severity}: #{message}\n" } unless loglevel == "DEBUG"
      end
      config = Drunker::Config.new(image: image,
                                   commands: commands,
                                   concurrency: options[:concurrency],
                                   compute_type: options[:compute_type],
                                   timeout: options[:timeout],
                                   env: options[:env],
                                   debug: options[:debug],
                                   access_key: options[:access_key],
                                   secret_key: options[:secret_key],
                                   region: options[:region],
                                   profile_name: options[:profile_name])

      logger.info("Creating source....")
      source = Drunker::Source.new(Pathname.pwd, config: config, logger: logger)


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
    rescue Drunker::Config::InvalidConfigException => exn
      logger.fatal(exn.message)
      exit 1
    end
    map "run" => "_run" # "run" is a Thor reserved word and cannot be defined as command

    desc "version", "Show version"
    def version
      puts "Drunker #{VERSION}"
    end

    def self.exit_on_failure?
      true
    end
  end
end
