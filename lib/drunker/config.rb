module Drunker
  class Config
    attr_reader :image
    attr_reader :commands
    attr_reader :concurrency
    attr_reader :compute_type

    def initialize(image:, commands:, concurrency:, compute_type:, access_key:, secret_key:, region:, profile_name:, debug:)
      @image = image
      @commands = commands
      @concurrency = concurrency
      @compute_type = compute_name[compute_type]
      @credentials = if profile_name
                      Aws::SharedCredentials.new(profile_name: profile_name)
                     elsif access_key && secret_key
                      Aws::Credentials.new(access_key, secret_key)
                     end
      @region = region
      @debug = debug
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
  end
end
