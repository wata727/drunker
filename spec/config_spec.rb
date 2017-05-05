require "spec_helper"

RSpec.describe Drunker::Config do
  let(:image) { "wata727/rubocop" }
  let(:commands) { %w(rubocop --fail-level=F FILES) }
  let(:concurrency) { 1 }
  let(:debug) { false }
  let(:access_key) { nil }
  let(:secret_key) { nil }
  let(:region) { nil }
  let(:profile_name) { nil }
  let(:config) do
    Drunker::Config.new(image: image,
                        commands: commands,
                        concurrency: concurrency,
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
      expect(config.instance_variable_get(:@debug)).to eq debug
      expect(config.instance_variable_get(:@credentials)).to be_nil
      expect(config.instance_variable_get(:@region)).to be_nil
    end

    context "when specifed region" do
      let(:region) { "us-east-1" }

      it "sets region" do
        expect(config.instance_variable_get(:@region)).to eq region
      end
    end

    context "when specifed profile_name" do
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
