module Drunker
  class Executor
    class IAM
      attr_reader :role

      def initialize(source:, artifact:, logger:)
        @logger = logger
        timestamp = Time.now.to_i.to_s
        iam = Aws::IAM::Resource.new

        @role = iam.create_role(
            role_name: "drunker-codebuild-servie-role-#{timestamp}",
            assume_role_policy_document: role_json,
        )
        logger.info("Created IAM role: #{role.name}")
        @policy = iam.create_policy(
            policy_name: "drunker-codebuild-service-policy-#{timestamp}",
            policy_document: policy_json(source: source, artifact: artifact)
        )
        logger.info("Created IAM policy: #{policy.policy_name}")
        role.attach_policy(policy_arn: policy.arn)
        logger.debug("Attached #{policy.policy_name} to #{role.name}")
      end

      def delete
        role.detach_policy(policy_arn: policy.arn)
        logger.debug("Detached #{policy.policy_name} from #{role.name}")
        policy.delete
        logger.info("Deleted IAM policy: #{policy.policy_name}")
        role.delete
        logger.info("Deleted IAM role: #{role.name}")
      end

      private

      attr_reader :policy
      attr_reader :logger

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
