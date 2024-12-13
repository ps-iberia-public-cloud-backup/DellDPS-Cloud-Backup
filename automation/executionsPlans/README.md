# AWS Provider: This example uses AWS to deploy a VM. You can switch to another provider (e.g., Azure, GCP) by updating the provider block.
# Instance Resource: The aws_instance resource defines the EC2 instance. The user_data field is used to pass a script to the instance to execute when it starts. This is where the setup.sh script is run.
# Variables: Variables are defined in variables.tf, which you can customize when applying the Terraform plan.
# Outputs: The output block displays the public IP of the created instance.

terraform init
terraform plan -out=tfplan
terraform apply tfplan
