# Drunker

Distributed CLI runner on [AWS CodeBuild](https://aws.amazon.com/codebuild/). This is a wrapper for handling CodeBuild container more easily.

## Installation

    $ gem install drunker

## Usage

All you need to use Drunker is the Docker image name of the container you want to use and the command you want to execute (Of course, AWS credentials is also necessary). For example, you can run [RSpec](https://github.com/rspec/rspec) on CodeBuild with the following command.

```
$ bundle install --path=vendor/bundle
$ drunker run --env=BUNDLE_PATH:vendor/bundle/ruby/2.4.0 --timeout=5 ruby:2.4.1 bundle exec rspec
```

First, specify the Docker image name, and then the command you want to execute. After that, Drunker archives files under the current directory and uploads it to S3 and creates a CodeBuild project and the required IAM role.

When preparation is completed, run builds, download artifacts from S3, and display it on your terminal. Resources created by Drunker are automatically deleted. Also, in this example, timeout and environment variables used inside containers are specified by options.

You can see execution result (e.g. STDOUT, STDERR and exit status) from output like the following.

```
-------------------------------------------------------------------------------------------
BUILD_ID: drunker-executor-1494139943:10c9c785-bae0-4a2d-b5eb-927528943626
RESULT: SUCCESS
STDOUT: .....................................................................................................................................

Finished in 5.9 seconds (files took 0.17053 seconds to load)
133 examples, 0 failures

STDERR:
EXIT_STATUS: 0
-------------------------------------------------------------------------------------------
```

### Parallel Build

The essence of Drunker is parallel build. For example, if you want to run RSpec in parallel, you can do it easily with the following command.

```
$ drunker run --concurrency=3 --file-pattern="spec/**/*_spec.rb" --env=BUNDLE_PATH:vendor/bundle/ruby/2.4.0 --timeout=5 ruby:2.4.1 bundle exec rspec FILES
```

`FILES` included in the execution command has a special meaning. This is interpolated into the list of filenames according to the number of parallels. For example, in this case, it will be the following command (filename changes for each build):

```
$ bundle exec rspec spec/aggregator_spec.rb spec/artifact_spec.rb ...
```

The target file is all files matching the glob pattern `**/*`. However, you can change this with `--file-pattern` option. You can see the execution result as the following:

```
-------------------------------------------------------------------------------------------
BUILD_ID: drunker-executor-1494140968:59c0b89f-099e-482c-8995-659f8b6b8523
RESULT: SUCCESS
STDOUT: ................

Finished in 0.12019 seconds (files took 0.14562 seconds to load)
16 examples, 0 failures

STDERR:
EXIT_STATUS: 0
-------------------------------------------------------------------------------------------


-------------------------------------------------------------------------------------------
BUILD_ID: drunker-executor-1494140968:f6cb0396-3005-44ca-8221-33b29cbbd309
RESULT: SUCCESS
STDOUT: ..........................................................................

Finished in 0.15774 seconds (files took 0.19026 seconds to load)
74 examples, 0 failures

STDERR:
EXIT_STATUS: 0
-------------------------------------------------------------------------------------------


-------------------------------------------------------------------------------------------
BUILD_ID: drunker-executor-1494140968:620c471e-19e7-48da-95e7-42cd66728455
RESULT: SUCCESS
STDOUT: ...........................................

Finished in 5.56 seconds (files took 0.14991 seconds to load)
43 examples, 0 failures

STDERR:
EXIT_STATUS: 0
-------------------------------------------------------------------------------------------
```

What is surprising is that do not require your local machine specs at all even if you increase the number of parallels. You can increase the number of parallels within the bounds of common sense.

### EC2 Container Registry

Do you want to use private images? You can also specify the image of [EC2 Container Registry](https://aws.amazon.com/ecr/). Following example:

```
$ drunker run account-ID.dkr.ecr.us-east-1.amazonaws.com/your-Amazon-ECR-repo-name:latest ruby task.rb
```

For details, please see [Amazon ECR Sample for AWS CodeBuild](http://docs.aws.amazon.com/codebuild/latest/userguide/sample-ecr.html).

## Available Options

Please show `drunker help run`

```
Usage:
  drunker run [IMAGE] [COMMAND]

Options:
  [--config=CONFIG]              # Location of config file
                                 # Default: .drunker.yml
  [--concurrency=N]              # Build concurrency
                                 # Default: 1
  [--compute-type=COMPUTE_TYPE]  # Container compute type
                                 # Default: small
                                 # Possible values: small, medium, large
  [--timeout=N]                  # Build timeout in minutes, should be between 5 and 480
                                 # Default: 60
  [--env=key:value]              # Environment variables in containers
  [--buildspec=BUILDSPEC]        # Location of custom buildspec
  [--file-pattern=FILE_PATTERN]  # FILES target file pattern, can use glob to specify, but files beginning with a dot are ignored.
                                 # Default: **/*
  [--loglevel=LOGLEVEL]          # Output log level
                                 # Default: info
                                 # Possible values: debug, info, warn, error, fatal
  [--debug], [--no-debug]        # Enable debug mode. This mode does not delete the AWS resources created by Drunker
  [--access-key=ACCESS_KEY]      # AWS access key token used by Drunker
  [--secret-key=SECRET_KEY]      # AWS secret key token used by Drunker
  [--region=REGION]              # AWS region in which resources is created by Drunker
  [--profile-name=PROFILE_NAME]  # AWS shared credentials profile name used by Drunker

Run a command on CodeBuild
```

## Configuration

By default, it loads `.drunker.yml`. In the configuration file, many options can be written in advance. Following example:

```yaml
concurrency: 10
compute_type: medium
timeout: 5
file_pattern: spec/**/*_spec.rb
environment_variables:
  RAILS_ENV: test
  SECRET_KEY_BASE: super secret
aws_credentials:
  access_key: AWS_ACCESS_KEY_ID
  secret_key: AWS_SECRET_ACCESS_KEY
  region: us-east-1
```

If you want to create a configuration file with a different name, specify the file name with --config option.

```
$ drunker run --config=.custom_drunker.yml ruby:2.4.1 bundle exec rspec
```

### Credentials

Drunker supports various credential providers. It is used with the following priority:

- Specified shared credentials
- Static credentials
- Environment credentials
- Default shared credentials

#### Static Credentials

If you have access key and secret key, you can specify these credentials.

```
$ drunker run --access-key=AWS_ACCESS_KEY_ID --secret-key=AWS_SECRET_ACCESS_KEY --region=us-east-1 owner_name/image_name ruby task.rb
```

```yaml
aws_credentials:
  access_key: AWS_ACCESS_KEY_ID
  secret_key: AWS_SECRET_ACCESS_KEY
  region: us-east-1
```

#### Shared Credentials

If you have [shared credentials](https://aws.amazon.com/blogs/security/a-new-and-standardized-way-to-manage-credentials-in-the-aws-sdks/), you can specify credentials profile name. However Drunker supports only `~/.aws/credentials` as shared credentials location.

```
$ drunker run --profile-name=PROFILE_NAME --region=us-east-1 owner_name/image_name ruby task.rb
```

```yaml
aws_credentials:
  profile_name: PROFILE_NAME
  region: us-east-1
```

## Customize Build Specification

Do you want to customize the build specification more? You can change the `buildspec.yml` that is used by Drunker. The default `buildspec.yml` is [here](https://github.com/wata727/drunker/tree/master/lib/drunker/executor/buildspec.yml.erb). For example, if you want to run `bundle install` in the install phase, create the `custom_buildspec.yml` like the following.

```yaml
version: 0.1
phases:
  install:
    commands:
      - bundle install
  build:
    commands:
      - <%= commands.join(" ") %> 1> <%= stdout %> 2> <%= stderr %>; echo $? > <%= exit_status %>
artifacts:
  files:
    - <%= stdout %>
    - <%= stderr %>
    - <%= exit_status %>
```

Actual commands and output files are interpolated by ERB. Please see [here](http://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html) for how to write `buildspec.yml`. After that, specify the file path with the `--buildspec` option.

```
$ drunker run --buildspec=custom_buildspec.yml owner_name/image_name ruby task.rb
```

Also, you can specify it in the configuration file.

```yaml
buildspec: custom_buildspec.yml
```

In configuration file, you can also be described inline style.

```yaml
buildspec:
  version: 0.1
  phases:
    install:
      commands:
        - bundle install
    build:
      commands:
        - <%= commands.join(" ") %> 1> <%= stdout %> 2> <%= stderr %>; echo $? > <%= exit_status %>
  artifacts:
    files:
      - <%= stdout %>
      - <%= stderr %>
      - <%= exit_status %>
```

## Customize Output

TODO: Write about custom aggregator (exit status etc...)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/wata727/drunker. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

