module Drunker
  class Config
    attr_reader :image
    attr_reader :commands
    attr_reader :concurrency

    def initialize(image:, commands:, concurrency:, access_key:, secret_key:, region:, profile_name:, debug:)
      @image = image
      @commands = commands
      @concurrency = concurrency
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
  end
end
