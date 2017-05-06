module Drunker
  class Config
    attr_reader :image
    attr_reader :commands
    attr_reader :concurrency
    attr_reader :compute_type
    attr_reader :timeout
    attr_reader :environment_variables

    class InvalidConfigException < StandardError; end

    def initialize(image:, commands:, concurrency:, compute_type:, timeout:, env:, access_key:, secret_key:, region:, profile_name:, debug:)
      @image = image
      @commands = commands
      @concurrency = concurrency
      @compute_type = compute_name[compute_type]
      @timeout = timeout
      @environment_variables = codebuild_environments_format(env)
      @credentials = if profile_name
                      Aws::SharedCredentials.new(profile_name: profile_name)
                     elsif access_key && secret_key
                      Aws::Credentials.new(access_key, secret_key)
                     end
      @region = region
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
