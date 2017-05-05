require "spec_helper"

RSpec.describe Drunker::Executor::IAM do
  let(:aws_opts) { double("AWS options stub") }
  let(:config) { double(aws_client_options: aws_opts) }
  let(:client) { double("client stub") }
  let(:iam) { Drunker::Executor::IAM.new(source: source, artifact: artifact, config: config, logger: Logger.new("/dev/null")) }
  let(:resource) { double("IAM stub") }
  let(:role) { double(name: "drunker-codebuild-service-role-1483196400") }
  let(:policy) { double(arn: "example-arn", policy_name: "drunker-codebuild-service-policy-1483196400") }
  let(:source) { double(location: "source_location") }
  let(:artifact) { double(bucket: double(name: "artifact_bucket")) }
  before do
    Timecop.freeze(Time.local(2017))
    allow(Aws::IAM::Client).to receive(:new).and_return(client)
    allow(Aws::IAM::Resource).to receive(:new).and_return(resource)
    allow(resource).to receive(:create_role).and_return(role)
    allow(resource).to receive(:create_policy).and_return(policy)
    allow(role).to receive(:attach_policy)
  end
  after { Timecop.return }

  describe "#initialize" do
    it "uses IAM client with config" do
      expect(Aws::IAM::Client).to receive(:new).with(aws_opts).and_return(client)
      expect(Aws::IAM::Resource).to receive(:new).with(client: client).and_return(resource)
      iam
    end

    it "creates IAM role" do
      json = {
        Version: "2012-10-17",
        Statement: [
          {
            Effect: "Allow",
            Principal: {
              Service: "codebuild.amazonaws.com",
            },
            Action: "sts:AssumeRole",
          }
        ],
      }.to_json
      expect(resource).to receive(:create_role).with(role_name: "drunker-codebuild-servie-role-1483196400", assume_role_policy_document: json)

      iam
    end

    it "creates IAM policy" do
      json = {
        Version: "2012-10-17",
        Statement: [
          {
            Effect: "Allow",
            Resource: "*",
            Action: [
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:PutLogEvents",
            ]
          },
          {
            Effect: "Allow",
            Resource: [
              "arn:aws:s3:::source_location"
            ],
            Action: [
              "s3:GetObject",
              "s3:GetObjectVersion",
            ]
          },
          {
            Effect: "Allow",
            Resource: [
              "arn:aws:s3:::artifact_bucket/*"
            ],
            Action: [
              "s3:PutObject"
            ]
          }
        ]
      }.to_json
      expect(resource).to receive(:create_policy).with(policy_name: "drunker-codebuild-service-policy-1483196400", policy_document: json)

      iam
    end

    it "attaches policy to role" do
      expect(role).to receive(:attach_policy).with(policy_arn: "example-arn")

      iam
    end

    it "sets role" do
      expect(iam.role).to eq role
    end
  end

  describe "#delete" do
    before do
      allow(role).to receive(:detach_policy)
      allow(policy).to receive(:delete)
      allow(role).to receive(:delete)
    end

    it "detaches policy from role" do
      expect(role).to receive(:detach_policy).with(policy_arn: "example-arn")

      iam.delete
    end

    it "deletes policy" do
      expect(policy).to receive(:delete)

      iam.delete
    end

    it "deletes role" do
      expect(role).to receive(:delete)

      iam.delete
    end
  end
end
