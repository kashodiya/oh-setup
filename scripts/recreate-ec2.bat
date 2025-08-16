@echo off
cd /d "%~dp0\..\terraform"
terraform taint aws_instance.main
terraform apply -auto-approve
cd /d "%~dp0"