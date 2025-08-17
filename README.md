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


### Source Deployment Scheme

1. **Terraform zips source files**: The `ec2-setup/` directory is automatically zipped during terraform apply
2. **Upload to S3**: Zip file is uploaded to S3 bucket with unique naming
3. **Parameter Store**: S3 location is stored in AWS Parameter Store as `/{project_name}/source-zip-location`
4. **EC2 User Data**: Instance downloads zip from S3, extracts to `/home/ec2-user/`, and runs installation scripts
5. **Installation Flow**: `user-data.sh` → `main.sh` → individual install scripts

## Complete EC2 Setup Process

### Phase 1: Infrastructure Provisioning
1. **Terraform Apply**: Creates AWS resources (EC2, S3, Parameter Store)
2. **Source Upload**: Zips and uploads `ec2-setup/` to S3
3. **Instance Launch**: EC2 instance starts with user-data script

### Phase 2: Initial Bootstrap (`user-data.sh`)
1. **Download Source**: Retrieves zip file from S3 using Parameter Store location
2. **Extract Files**: Unzips to `/home/ec2-user/source/`
3. **Launch Main Script**: Executes `main.sh` with proper permissions

### Phase 3: System Setup (`main.sh`)
1. **System Update**: Updates all system packages via `yum update -y`
2. **Configuration Retrieval**: Gets secrets from Parameter Store:
   - LiteLLM API key
   - Admin password for basic auth
3. **Docker Installation**: Installs Docker and creates shared network
4. **Docker Compose**: Installs Docker Compose for container orchestration
5. **Directory Structure**: Creates `/home/ec2-user/docker/` with app subdirectories

### Phase 4: Application Installation
Each application is installed via dedicated scripts:

1. **OpenHands** (`setup-openhands-app.sh`)
   - AI coding assistant platform
   - Runs on port 3000 (HTTP)
   - Proxied via Caddy on port 5000 (HTTPS)

2. **LiteLLM** (`setup-litellm.sh`)
   - LLM proxy server for OpenHands
   - Handles API key management
   - Internal service communication

3. **Open WebUI** (`setup-open-webui.sh`)
   - Web interface for LLM interactions
   - Alternative UI for AI conversations

4. **SearXNG** (`setup-searxng.sh`)
   - Privacy-focused search engine
   - Provides web search capabilities

5. **Portainer** (`setup-portainer.sh`)
   - Docker container management UI
   - Runs on port 3003 (HTTP)
   - Proxied via Caddy on port 5003 (HTTPS)

6. **VSCode Server** (`install-vscode-server.sh`)
   - Browser-based code editor
   - Runs on port 3002 (HTTP)
   - Proxied via Caddy on port 5002 (HTTPS)

7. **Caddy** (`install-caddy.sh`)
   - Reverse proxy and HTTPS termination
   - Provides SSL certificates and basic auth
   - Routes traffic from ports 5000-7000 to apps on 3000-5000

### Phase 5: Service Configuration
1. **Caddy Setup**: Configures reverse proxy rules for each application
2. **SSL Certificates**: Automatic HTTPS certificate generation
3. **Basic Authentication**: Admin user setup with hashed password
4. **Service Start**: All applications launched via Docker/systemd

### Installation Timeline
- **0-2 minutes**: Infrastructure creation and instance launch
- **2-5 minutes**: System updates and Docker installation
- **5-8 minutes**: Application container downloads and setup
- **8-10 minutes**: Service configuration and startup
- **Total**: ~10 minutes for complete deployment

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

## Controller Interface

The setup includes a web-based controller for managing your EC2 instance:

### Features
- **EC2 Control**: Start/stop your instance remotely
- **Status Monitoring**: Real-time instance state and IP address
- **App Links**: Dynamic list of available applications when instance is running
- **Authentication**: Password-protected access

### App Links Configuration
The controller dynamically displays links to your applications by reading configuration from AWS Parameter Store (`/{project_name}/apps-config`). This configuration is automatically created during terraform deployment and includes:

- **OpenHands** (Port 5000): AI Coding Assistant
- **VSCode** (Port 5002): Browser IDE  
- **Portainer** (Port 5003): Docker Management
- **Open WebUI** (Port 5004): LLM Interface
- **SearXNG** (Port 5005): Search Engine

The app links only appear when your EC2 instance is running and has a public IP address.

### Access
After deployment, access the controller URL from:
- `terraform/outputs.env` file
- `scripts/start.bat` command output

## Deployment Flow

1. **Prepare**: Update `terraform.tfvars` with your configuration
2. **Deploy**: Run `terraform apply --auto-approve`
3. **Monitor**: Use `scripts/tail-logs.bat` to watch installation progress
4. **Control**: Use the web controller to manage your instance
5. **Access**: Applications available when instance is running:
   - OpenHands: `https://{public_ip}:5000`
   - VSCode: `https://{public_ip}:5002`
   - Portainer: `https://{public_ip}:5003`

### Monitoring Installation Progress
```bash
# Watch real-time logs
scripts/tail-logs.bat

# Use web controller to monitor instance status
# Controller URL available in terraform output

# Check specific service status on EC2
sudo systemctl status openvscode-server
docker ps
docker logs <container_name>
```

### Controller Management
```bash
# Update controller code
scripts/update-lambda.bat

# View controller logs
scripts/lambda-logs.bat
```

## Commands
```bash
# On Windows
terraform apply --auto-approve
terraform init -upgrade
# On EC2
sudo systemctl cat openvscode-server
docker restart portainer
```