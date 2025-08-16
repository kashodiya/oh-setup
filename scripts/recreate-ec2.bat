@echo off
set "TERRAFORM_DIR=%~dp0..\terraform"
cd /d "%TERRAFORM_DIR%"
terraform taint aws_instance.main
call "%~dp0remove-host.bat"
terraform apply -auto-approve