require "spec_helper"

RSpec.describe Drunker::Config do
  let(:image) { "wata727/rubocop" }
  let(:commands) { %w(rubocop --fail-level=F FILES) }
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
  let(:config) do
    Drunker::Config.new(image: image,
                        commands: commands,
                        concurrency: concurrency,
                        compute_type: compute_type,
                        timeout: timeout,
                        env: env,
                        buildspec: buildspec,
                        debug: debug,
                        access_key: access_key,
                        secret_key: secret_key,
                        region: region,
                        profile_name: profile_name)
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

      it "sets custom buildspec" do
        expect { config }.to raise_error(Drunker::Config::InvalidConfigException, "Invalid location of custom buildspec. got: buildspec.yml.erb")
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
end
