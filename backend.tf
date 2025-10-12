# Define the S3 backend for remote state storage
# NOTE: The bucket must be created manually before running 'terraform init'
terraform {
  backend "s3" {
    bucket       = "amin-terraform-s33"
    key          = "terraform/dev/terraform.state.tf"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true

    # Cross-account role_arn CANNOT use interpolation (var. or data.). It can be
    # configured using a new profile in your aws config file.
    # to set your Backend Account ID securely
    # Create a new profile under ur ~/.aws/config
    # Use the profile name defined in your ~/.aws/config

    # profile        = "backend-assumer"
  }
}

