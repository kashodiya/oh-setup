# OH Setup

## Prerequisites

Ensure you have:
- A VPC with internet access
- A public subnet with auto-assign public IP enabled
- An internet gateway attached to the VPC
- Route table configured for internet access (0.0.0.0/0 → IGW)

## Terraform Configuration

**Important**: Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and update with your AWS values:
- `subnet_id`
- `allowed_ip`

### Resources Created
- EC2 instance (m5.xlarge)
- Elastic IP attached to the instance


### TIPS
- Recreate EC2
```bash
terraform taint aws_instance.main
terraform apply -auto-approve
```

