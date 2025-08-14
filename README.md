# OH Setup

## Terraform Configuration

**Important**: Update the VPC ID and subnet ID in `terraform/main.tf` to match your AWS account:
- `vpc_id` (line 7)
- `subnet_id` (line 13)

### Resources Created
- EC2 instance (m5.xlarge)
- Elastic IP attached to the instance


### TIPS
- Recreate EC2
terraform taint aws_instance.main
terraform apply -auto-approve


