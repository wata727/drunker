module Drunker
  class Config
    attr_reader :image
    attr_reader :commands
    attr_reader :concurrency
    attr_reader :compute_type
    attr_reader :timeout
    attr_reader :environment_variables
    attr_reader :buildspec
    attr_reader :file_pattern
    attr_reader :aggregator

    class InvalidConfigException < StandardError; end

    def initialize(image:,
                   commands:,
                   config:,
                   concurrency:,
                   compute_type:,
                   timeout:,
                   env:,
                   buildspec:,
                   file_pattern:,
                   aggregator:,
                   access_key:,
                   secret_key:,
                   region:,
                   profile_name:,
                   debug:,
                   logger:)
      @logger = logger
      yaml = load!(config)

      @image = image
      @commands = commands
      @concurrency = yaml["concurrency"] || concurrency
      @compute_type = compute_name[ yaml["compute_type"] || compute_type ]
      @timeout =  yaml["timeout"] || timeout
      @environment_variables = codebuild_environments_format(yaml["environment_variables"] || env)
      @buildspec = buildspec_body!(yaml["buildspec"] || buildspec)
      @file_pattern = yaml["file_pattern"] || file_pattern
      @aggregator = aggregator_gem!(yaml["aggregator"] || aggregator)
      @credentials = aws_credentials(profile_name: yaml.dig("aws_credentials", "profile_name") || profile_name,
                                     access_key: yaml.dig("aws_credentials", "access_key") || access_key,
                                     secret_key: yaml.dig("aws_credentials", "secret_key") || secret_key)
      @region = yaml.dig("aws_credentials", "region") || region
      @debug = debug

      validate!
    end

    def debug?
      debug
    end

    def aws_client_options
      { credentials: credentials, region: region }.delete_if { |_k, v| v.nil? }
    end

    private

    attr_reader :credentials
    attr_reader :region
    attr_reader :debug
    attr_reader :logger

    def compute_name
      {
        "small" => "BUILD_GENERAL1_SMALL",
        "medium" => "BUILD_GENERAL1_MEDIUM",
        "large" => "BUILD_GENERAL1_LARGE"
      }
    end

    def codebuild_environments_format(env)
      env.map { |k, v| { name: k, value: v } }
    end

    def buildspec_body!(buildspec)
      if buildspec
        buildspec.is_a?(Hash) ? buildspec.to_yaml : Pathname.new(buildspec).read
      else
        Pathname.new(__dir__ + "/executor/buildspec.yml.erb").read
      end
    rescue Errno::ENOENT
      raise InvalidConfigException.new("Invalid location of custom buildspec. got: #{buildspec}")
    end

    def aws_credentials(profile_name:, access_key:, secret_key:)
      if profile_name
        Aws::SharedCredentials.new(profile_name: profile_name)
      elsif access_key && secret_key
        Aws::Credentials.new(access_key, secret_key)
      end
    end

    def aggregator_gem!(name)
      gem = Gem::Specification.select { |gem| gem.name == "drunker-aggregator-#{name}" }.max_by(&:version)
      raise InvalidConfigException.new("Invalid aggregator. `drunker-aggregator-#{name}` is already installed?") unless gem
      gem
    end

    def load!(config)
      yaml = YAML.load_file(config)
      validate_yaml!(yaml)
      yaml
    rescue Errno::ENOENT
      if config == ".drunker.yml"
        logger.debug("Config file not found. But it ignored because this is default config file.")
        {}
      else
        raise InvalidConfigException.new("Config file not found. got: #{config}")
      end
    rescue Psych::SyntaxError => exn
      raise InvalidConfigException.new("Invalid config file. message: #{exn.message}")
    end

    def validate_yaml!(yaml)
      valid_toplevel_keys = %w(concurrency compute_type timeout file_pattern environment_variables buildspec aggregator aws_credentials)
      invalid_keys = yaml.keys.reject { |k| valid_toplevel_keys.include?(k) }
      raise InvalidConfigException.new("Invalid config file keys: #{invalid_keys.join(",")}") unless invalid_keys.empty?

      if yaml["aws_credentials"]
        valid_aws_credentials_keys = %w(profile_name access_key secret_key region)
        invalid_keys = yaml["aws_credentials"].keys.reject { |k| valid_aws_credentials_keys.include?(k) }
        raise InvalidConfigException.new("Invalid config file keys: #{invalid_keys.join(",")}") unless invalid_keys.empty?
      end

      message = case
                when yaml["concurrency"] && !yaml["concurrency"].is_a?(Numeric)
                  "Invalid concurrency. It should be number (Not string). got: #{yaml["concurrency"]}"
                when yaml["compute_type"] && !%w(small medium large).include?(yaml["compute_type"])
                  "Invalid compute type. It should be one of small, medium, large. got: #{yaml["compute_type"]}"
                when yaml["timeout"] && !yaml["timeout"].is_a?(Numeric)
                  "Invalid timeout. It should be number (Not string). got: #{yaml["timeout"]}"
                when yaml["buildspec"] && !(yaml["buildspec"].is_a?(String) || yaml["buildspec"].is_a?(Hash))
                  "Invalid buildspec. It should be string or hash. got: #{yaml["buildspec"]}"
                when yaml["environment_variables"] && !yaml["environment_variables"]&.values&.all? { |v| v.is_a?(String) || v.is_a?(Numeric) }
                  "Invalid environment variables. It should be flatten hash. got: #{yaml["environment_variables"]}"
                when yaml["file_pattern"] && !yaml["file_pattern"].is_a?(String)
                  "Invalid file pattern. It should be string. got: #{yaml["file_pattern"]}"
                when yaml["aggregator"] && !yaml["aggregator"].is_a?(String)
                  "Invalid aggregator. It should be string. got: #{yaml["aggregator"]}"
                end

      raise InvalidConfigException.new(message) if message
    end

    def validate!
      message = case
                when concurrency <= 0
                  "Invalid concurrency. It should be bigger than 0. got: #{concurrency}"
                when !timeout.between?(5, 480)
                  "Invalid timeout range. It should be 5 and 480. got: #{timeout}"
                end

      raise InvalidConfigException.new(message) if message
    end
  end
end
