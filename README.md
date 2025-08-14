# OH Setup

## Terraform Configuration

**Important**: Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and update with your AWS values:
- `subnet_id`
- `allowed_ip`

### Resources Created
- EC2 instance (m5.xlarge)
- Elastic IP attached to the instance


### TIPS
- Recreate EC2
terraform taint aws_instance.main
terraform apply -auto-approve


