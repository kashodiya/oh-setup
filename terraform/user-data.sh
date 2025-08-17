#!/bin/bash

# Redirect all output to log file and console
exec > >(tee /var/log/user-data.log) 2>&1

echo "[USER-DATA] Starting user data script execution..."
echo "[USER-DATA] Script start time: $(date)"
echo "[USER-DATA] Current user: $(whoami)"
echo "[USER-DATA] Current directory: $(pwd)"

# Get project name from Parameter Store
echo "[USER-DATA] Retrieving project name from Parameter Store..."
PROJECT_NAME=$(aws ssm get-parameter --name "/oh/project-name" --query "Parameter.Value" --output text --region us-east-1)
echo "[USER-DATA] Project name: $PROJECT_NAME"

# Get source zip location from Parameter Store
echo "[USER-DATA] Retrieving source zip location from Parameter Store..."
SOURCE_ZIP_LOCATION=$(aws ssm get-parameter --name "/$PROJECT_NAME/source-zip-location" --query "Parameter.Value" --output text --region us-east-1)
echo "[USER-DATA] Source zip location: $SOURCE_ZIP_LOCATION"

# Download and extract source files
echo "[USER-DATA] Downloading source files..."
cd /home/ec2-user
echo "[USER-DATA] Changed to directory: $(pwd)"

# Check if source zip location is valid
if [[ -z "$SOURCE_ZIP_LOCATION" || "$SOURCE_ZIP_LOCATION" == "None" ]]; then
    echo "[USER-DATA] Error: Source zip location not found in Parameter Store"
    exit 1
fi

# Download source zip
echo "[USER-DATA] Attempting to download from: $SOURCE_ZIP_LOCATION"
if aws s3 cp "$SOURCE_ZIP_LOCATION" ./source.zip; then
    echo "[USER-DATA] Source zip downloaded successfully"
    echo "[USER-DATA] Downloaded file size: $(ls -lh source.zip)"
else
    echo "[USER-DATA] Error: Failed to download source zip from $SOURCE_ZIP_LOCATION"
    exit 1
fi

# Extract source files into source folder
echo "[USER-DATA] Creating source directory and extracting files..."
mkdir -p source
if unzip -q source.zip -d source; then
    echo "[USER-DATA] Source files extracted successfully into source folder"
    echo "[USER-DATA] Contents after extraction: $(ls -la source/)"
else
    echo "[USER-DATA] Error: Failed to extract source.zip"
    exit 1
fi

# Set permissions only if ec2-setup directory exists
if [[ -d "/home/ec2-user/source/ec2-setup" ]]; then
    echo "[USER-DATA] Setting permissions for ec2-setup directory"
    chown -R ec2-user:ec2-user /home/ec2-user/source/ec2-setup
    chmod +x /home/ec2-user/source/ec2-setup/*.sh
    echo "[USER-DATA] Permissions set for ec2-setup directory"
    echo "[USER-DATA] ec2-setup contents: $(ls -la /home/ec2-user/source/ec2-setup/)"
else
    echo "[USER-DATA] Error: ec2-setup directory not found after extraction"
    echo "[USER-DATA] Available directories: $(ls -la source/)"
    exit 1
fi

# Run the main setup script
echo "[USER-DATA] Running main setup script..."
if [[ -f "/home/ec2-user/source/ec2-setup/main.sh" ]]; then
    echo "[USER-DATA] Executing main.sh"
    bash /home/ec2-user/source/ec2-setup/main.sh
    echo "[USER-DATA] main.sh completed with exit code: $?"
else
    echo "[USER-DATA] Error: main.sh not found in ec2-setup directory"
    exit 1
fi

echo "[USER-DATA] User data script execution completed."
echo "[USER-DATA] Script end time: $(date)"
echo "[USER-DATA] Log saved to /var/log/user-data.log"
