require 'cluster'
require 'json'
require 'jenkins'

# AWSCluster represents a k8s cluster on AWS cloud provider
class AWSCluster < Cluster
  def initialize(prefix, tf_vars_path)
    assume_role if Jenkins.environment?
    super(prefix, tf_vars_path)
  end

  def env_variables
    variables = super
    variables['PLATFORM'] = 'aws'
    variables
  end

  def check_prerequisites
    raise 'AWS credentials not defined' unless credentials_defined?
    raise 'TF_VAR_tectonic_aws_ssh_key is not defined' unless ssh_key_defined?

    super
  end

  def credentials_defined?
    credential_names = %w[AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY]
    EnvVar.set?(credential_names)
  end

  def ssh_key_defined?
    EnvVar.set?(%w[TF_VAR_tectonic_aws_ssh_key])
  end

  def assume_role
    role_name = ENV['TECTONIC_INSTALLER_ROLE']

    role_arn = JSON.parse(
      `aws iam get-role --role-name="#{role_name}"`
    )['Role']['Arn']

    credentials = request_credentials(role_arn)

    ENV['AWS_ACCESS_KEY_ID'] = credentials['AccessKeyId']
    ENV['AWS_SECRET_ACCESS_KEY'] = credentials['SecretAccessKey']
    ENV['AWS_SESSION_TOKEN'] = credentials['SessionToken']
  end

  def request_credentials(role_arn)
    cmd = "aws sts assume-role --role-arn='#{role_arn}'"\
          ' --role-session-name=tectonic-installer'
    puts cmd
    JSON.parse(`#{cmd}`)['Credentials']
  end
end
