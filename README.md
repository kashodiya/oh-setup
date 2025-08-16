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
   - `project_name` - Project name used as prefix for all AWS resources (e.g., "my-project")
   - `subnet_id` - Your VPC subnet ID (e.g., "subnet-xxxxxxxxxxxxxxxxx")
   - `allowed_ips` - List of IP addresses with CIDR notation (e.g., ["1.2.3.4/32", "5.6.7.8/32"])
   - `openhands_litellm_key` - Your LiteLLM API key
   - `openhands_vscode_token` - Your VS Code connection token

### Source Deployment Scheme

1. **Terraform zips source files**: The `ec2-setup/` directory is automatically zipped during terraform apply
2. **Upload to S3**: Zip file is uploaded to S3 bucket with unique naming
3. **Parameter Store**: S3 location is stored in AWS Parameter Store as `/{project_name}/source-zip-location`
4. **EC2 User Data**: Instance downloads zip from S3, extracts to `/home/ec2-user/`, and runs installation scripts
5. **Installation Flow**: `user-data.sh` → `main.sh` → individual install scripts

### Resources Created
- EC2 instance (m5.xlarge)
- Elastic IP attached to the instance
- S3 bucket for source files
- Parameter Store entries for configuration

### Port Scheme

The setup uses a structured port allocation scheme:

- **Application Ports (3000-5000)**: Direct HTTP access to EC2 applications (blocked by security group)
- **Caddy Proxy Ports (5000-7000)**: HTTPS proxied versions of applications (allowed by security group)

Caddy acts as a reverse proxy, providing:
- HTTPS termination for HTTP-only applications
- Basic authentication for applications without built-in auth
- Consistent SSL/TLS encryption across all services

**Port Mapping Example**:
- App on port 3000 → Caddy proxy on port 5000
- App on port 3001 → Caddy proxy on port 5001
- App on port 3002 → Caddy proxy on port 5002

**Caddy Configuration**:
- Each application has its own Caddy config file
- Config files located in `/etc/caddy/apps/` on the EC2 instance
- One config file per app (e.g., `app-3000.conf`, `vscode-3002.conf`)
- Main Caddyfile imports all configs from this directory
- Admin user created in `/etc/caddy/users.txt` with hashed password for basic auth
- Password hash generated using `caddy hash-password` command
- Password sourced from `admin_password` variable in terraform.tfvars


## Scripts

The `scripts/` folder contains utility batch files:

- `recreate-ec2.bat` - Recreate the EC2 instance
- `remove-host.bat` - Remove host from SSH known_hosts
- `ssh-ec2.bat` - SSH into the EC2 instance
- `tail-logs.bat` - Live tail user data script logs
- `show-params.bat` - Display Parameter Store values

### TIPS
- Recreate EC2
```bash
terraform taint aws_instance.main
terraform apply -auto-approve
```

## Deployment Flow

1. **Prepare**: Update `terraform.tfvars` with your configuration
2. **Deploy**: Run `terraform apply --auto-approve`
3. **Monitor**: Use `scripts/tail-logs.bat` to watch installation progress
4. **Access**: Services available after ~5-10 minutes:
   - OpenHands: `https://{public_ip}:3000`
   - VSCode: `https://{public_ip}:3002`
   - Portainer: `https://{public_ip}:3003`

## Commands
```bash
# On Windows
terraform apply --auto-approve
terraform init -upgrade
# On EC2
sudo systemctl cat openvscode-server
docker restart portainer
```