module Drunker
  class Executor
    class IAM
      attr_reader :role

      def initialize(source:, artifact:)
        iam = Aws::IAM::Resource.new
        @role = iam.create_role(
            role_name: "drunker-codebuild-servie-role",
            assume_role_policy_document: role_json,
        )
        @policy = iam.create_policy(
            policy_name: "drunker-codebuild-service-policy",
            policy_document: policy_json(source: source, artifact: artifact)
        )
        role.attach_policy(policy_arn: policy.arn)
      end

      def delete
        role.detach_policy(policy_arn: policy.arn)
        policy.delete
        role.delete
      end

      private

      attr_reader :policy

      def role_json
        {
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
      end

      def policy_json(source:, artifact:)
        {
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
                "arn:aws:s3:::#{source.location}"
              ],
              Action: [
                "s3:GetObject",
                "s3:GetObjectVersion",
              ]
            },
            {
              Effect: "Allow",
              Resource: [
                "arn:aws:s3:::#{artifact.bucket.name}/*"
              ],
              Action: [
                "s3:PutObject"
              ]
            }
          ]
        }.to_json
      end
    end
  end
end
