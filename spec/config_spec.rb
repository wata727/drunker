require "spec_helper"

RSpec.describe Drunker::Config do
  let(:image) { "wata727/rubocop" }
  let(:commands) { %w(rubocop --fail-level=F FILES) }
  let(:config_file) { ".drunker.yml" }
  let(:concurrency) { 1 }
  let(:compute_type) { "small" }
  let(:timeout) { 60 }
  let(:env) { {} }
  let(:buildspec) { nil }
  let(:debug) { false }
  let(:access_key) { nil }
  let(:secret_key) { nil }
  let(:region) { nil }
  let(:profile_name) { nil }
  let(:logger) { Logger.new("/dev/null") }
  let(:config) do
    Drunker::Config.new(image: image,
                        commands: commands,
                        config: config_file,
                        concurrency: concurrency,
                        compute_type: compute_type,
                        timeout: timeout,
                        env: env,
                        buildspec: buildspec,
                        debug: debug,
                        access_key: access_key,
                        secret_key: secret_key,
                        region: region,
                        profile_name: profile_name,
                        logger: logger)
  end
  let(:credentials) { double("credentials stub") }

  describe "#initialize" do
    it "sets attributes" do
      expect(config.image).to eq image
      expect(config.commands).to eq commands
      expect(config.concurrency).to eq concurrency
      expect(config.compute_type).to eq "BUILD_GENERAL1_SMALL"
      expect(config.timeout).to eq 60
      expect(config.buildspec).to eq Pathname(__dir__ + "/../lib/drunker/executor/buildspec.yml.erb").cleanpath
      expect(config.environment_variables).to eq([])
      expect(config.instance_variable_get(:@debug)).to eq debug
      expect(config.instance_variable_get(:@credentials)).to be_nil
      expect(config.instance_variable_get(:@region)).to be_nil
    end

    context "when specified medium as compute_type" do
      let(:compute_type) { "medium" }

      it "sets medium compute name" do
        expect(config.compute_type).to eq "BUILD_GENERAL1_MEDIUM"
      end
    end

    context "when specified large as compute_type" do
      let(:compute_type) { "large" }

      it "sets large compute name" do
        expect(config.compute_type).to eq "BUILD_GENERAL1_LARGE"
      end
    end

    context "when specified environment variables" do
      let(:env) do
        { "RAILS_ENV" => "test", "SECRET_KEY_BASE" => "super_secret" }
      end

      it "sets environment variables" do
        expect(config.environment_variables).to eq([
                                                      { name: "RAILS_ENV", value: "test" },
                                                      { name: "SECRET_KEY_BASE", value: "super_secret" }
                                                   ])
      end
    end

    context "when specified custom buildspec" do
      let(:buildspec) { Pathname(__dir__ + "/fixtures/buildspec.yml.erb").to_s }

      it "sets custom buildspec" do
        expect(config.buildspec).to eq Pathname(__dir__ + "/fixtures/buildspec.yml.erb").cleanpath
      end
    end

    context "when specified region" do
      let(:region) { "us-east-1" }

      it "sets region" do
        expect(config.instance_variable_get(:@region)).to eq region
      end
    end

    context "when specified profile_name" do
      let(:profile_name) { "PROFILE_NAME" }

      it "sets shared credentials" do
        expect(Aws::SharedCredentials).to receive(:new).with(profile_name: profile_name).and_return(credentials)
        expect(config.instance_variable_get(:@credentials)).to eq credentials
      end
    end

    context "when specified both keys" do
      let(:access_key) { "AWS_ACCESS_KEY_ID" }
      let(:secret_key) { "AWS_SECRET_ACCESS_KEY" }

      it "sets credentials" do
        expect(Aws::Credentials).to receive(:new).with(access_key, secret_key).and_return(credentials)
        expect(config.instance_variable_get(:@credentials)).to eq credentials
      end
    end

    context "when specified config file" do
      let(:config_file) { Pathname(__dir__ + "/fixtures/.drunker.yml") }
      let(:buildspec_path) { double(file?: true) }

      before do
        allow(Pathname).to receive(:new).with("buildspec.yml.erb").and_return(buildspec_path)
        allow(Aws::SharedCredentials).to receive(:new).with(profile_name: "PROFILE_NAME").and_return(credentials)
      end

      it "sets atrributes from config file" do
        expect(config.concurrency).to eq 10
        expect(config.compute_type).to eq "BUILD_GENERAL1_MEDIUM"
        expect(config.timeout).to eq 5
        expect(config.buildspec).to eq buildspec_path
        expect(config.environment_variables).to eq([
                                                     { name: "RAILS_ENV", value: "test" },
                                                     { name: "SECRET_KEY_BASE", value: "super secret" }
                                                   ])
        expect(config.instance_variable_get(:@credentials)).to eq credentials
        expect(config.instance_variable_get(:@region)).to eq "us-east-1"
      end
    end

    context "when specified small config file" do
      let(:config_file) { Pathname(__dir__ + "/fixtures/.custom_drunker.yml") }

      before do
        expect(Aws::Credentials).to receive(:new).with("AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY").and_return(credentials)
      end

      it "sets atrributes from config file and arguments" do
        expect(config.concurrency).to eq concurrency
        expect(config.compute_type).to eq "BUILD_GENERAL1_SMALL"
        expect(config.timeout).to eq 60
        expect(config.buildspec).to eq Pathname(__dir__ + "/../lib/drunker/executor/buildspec.yml.erb").cleanpath
        expect(config.environment_variables).to eq([])
        expect(config.instance_variable_get(:@credentials)).to eq credentials
        expect(config.instance_variable_get(:@region)).to be_nil
      end
    end

    context "when specified invalid concurrency" do
      let(:concurrency) { 0 }

      it "raises InvalidConfigException" do
        expect { config }.to raise_error(Drunker::Config::InvalidConfigException, "Invalid concurrency. It should be bigger than 0. got: 0")
      end
    end

    context "when specified invalid timeout" do
      let(:timeout) { 1 }

      it "raises InvalidConfigException" do
        expect { config }.to raise_error(Drunker::Config::InvalidConfigException, "Invalid timeout range. It should be 5 and 480. got: 1")
      end
    end

    context "when specified invalid custom buildspec" do
      let(:buildspec) { Pathname("buildspec.yml.erb").to_s }

      it "raises InvalidConfigException" do
        expect { config }.to raise_error(Drunker::Config::InvalidConfigException, "Invalid location of custom buildspec. got: buildspec.yml.erb")
      end
    end

    context "when specified invalid config file path" do
      let(:config_file) { ".invalid_drunker.yml" }

      it "raises InvalidConfigException" do
        expect { config }.to raise_error(Drunker::Config::InvalidConfigException, "Config file not found. got: .invalid_drunker.yml")
      end
    end

    context "when specified invalid syntax config file" do
      let(:config_file) { Pathname(__dir__ + "/fixtures/.invalid_drunker.yml") }

      it "raises InvalidConfigException" do
        expect { config }.to raise_error(Drunker::Config::InvalidConfigException, "Invalid config file. message: (#{config_file.to_s}): did not find expected node content while parsing a flow node at line 2 column 1")
      end
    end
  end

  describe "#debug?" do
    it "returns false" do
      expect(config.debug?).to be false
    end

    context "when enabled debug mode" do
      let(:debug) { true }
      it "returns true" do
        expect(config.debug?).to be true
      end
    end
  end

  describe "#aws_client_options" do
    context "when does not set anything" do
      it "returns empty hash" do
        expect(config.aws_client_options).to eq({})
      end
    end

    context "when sets only credentials" do
      before { config.instance_variable_set(:@credentials, credentials) }

      it "returns hash including only crdentials" do
        expect(config.aws_client_options).to eq(credentials: credentials)
      end
    end

    context "when sets only region" do
      before { config.instance_variable_set(:@region, "us-east-1") }

      it "returns hash including only region" do
        expect(config.aws_client_options).to eq(region: "us-east-1")
      end
    end

    context "when sets credentials and region" do
      before do
        config.instance_variable_set(:@credentials, credentials)
        config.instance_variable_set(:@region, "us-east-1")
      end

      it "returns hash including crdentials and region" do
        expect(config.aws_client_options).to eq(credentials: credentials, region: "us-east-1")
      end
    end
  end

  describe "#validate_yaml!" do
    let(:yaml) { {} }

    context "when specified invalid key" do
      let(:yaml) do
        { "invalid_key" => "invalid!" }
      end

      it "raises InvalidConfigException" do
        expect { config.send(:validate_yaml!, yaml) }.to raise_error(Drunker::Config::InvalidConfigException, "Invalid config file keys: invalid_key")
      end
    end

    context "when specified invalid key in aws_credentials" do
      let(:yaml) do
        { "aws_credentials" => { "invalid_key" => "invalid!" } }
      end

      it "raises InvalidConfigException" do
        expect { config.send(:validate_yaml!, yaml) }.to raise_error(Drunker::Config::InvalidConfigException, "Invalid config file keys: invalid_key")
      end
    end

    context "when specified invalid concurrency" do
      let(:yaml) do
        { "concurrency" => "invalid" }
      end

      it "raises InvalidConfigException" do
        expect { config.send(:validate_yaml!, yaml) }.to raise_error(Drunker::Config::InvalidConfigException, "Invalid concurrency. It should be number (Not string). got: invalid")
      end
    end

    context "when specified invalid compute_type" do
      let(:yaml) do
        { "compute_type" => "big" }
      end

      it "raises InvalidConfigException" do
        expect { config.send(:validate_yaml!, yaml) }.to raise_error(Drunker::Config::InvalidConfigException, "Invalid compute type. It should be one of small, medium, large. got: big")
      end
    end

    context "when specified invalid timeout" do
      let(:yaml) do
        { "timeout" => { "minutes" => 10 } }
      end

      it "raises InvalidConfigException" do
        expect { config.send(:validate_yaml!, yaml) }.to raise_error(Drunker::Config::InvalidConfigException, "Invalid timeout. It should be number (Not string). got: {\"minutes\"=>10}")
      end
    end

    context "when specified invalid buildspec" do
      let(:yaml) do
        { "buildspec" => 10 }
      end

      it "raises InvalidConfigException" do
        expect { config.send(:validate_yaml!, yaml) }.to raise_error(Drunker::Config::InvalidConfigException, "Invalid buildspec. It should be string. got: 10")
      end
    end

    context "when specified invalid environment_variables" do
      let(:yaml) do
        {
          "environment_variables" => {
              "RAILS_ENV" => "test",
              "SECRET_KEY_BASE" => {
                "value" => "super secret"
              }
          }
        }
      end

      it "raises InvalidConfigException" do
        expect { config.send(:validate_yaml!, yaml) }.to raise_error(Drunker::Config::InvalidConfigException, "Invalid environment variables. It should be flatten hash. got: {\"RAILS_ENV\"=>\"test\", \"SECRET_KEY_BASE\"=>{\"value\"=>\"super secret\"}}")
      end
    end
  end
end
