# OH Setup

## Prerequisites

Ensure you have:
- A VPC with internet access
- A public subnet with auto-assign public IP enabled
- An internet gateway attached to the VPC
- Route table configured for internet access (0.0.0.0/0 → IGW)

## Terraform Configuration

### Setup Variables

1. Copy the example variables file:
   ```bash
   cp terraform/terraform.tfvars.example terraform/terraform.tfvars
   ```

2. Update `terraform/terraform.tfvars` with your values:
   - `subnet_id` - Your VPC subnet ID (e.g., "subnet-xxxxxxxxxxxxxxxxx")
   - `allowed_ips` - List of IP addresses with CIDR notation (e.g., ["1.2.3.4/32", "5.6.7.8/32"])
   - `openhands_litellm_key` - Your LiteLLM API key
   - `openhands_vscode_token` - Your VS Code connection token

### Resources Created
- EC2 instance (m5.xlarge)
- Elastic IP attached to the instance


## Scripts

The `scripts/` folder contains utility batch files:

- `recreate-ec2.bat` - Recreate the EC2 instance
- `remove-host.bat` - Remove host from SSH known_hosts
- `ssh-ec2.bat` - SSH into the EC2 instance
- `tail-logs.bat` - Live tail user data script logs

### TIPS
- Recreate EC2
```bash
terraform taint aws_instance.main
terraform apply -auto-approve
```

