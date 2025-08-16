@echo off
set "TERRAFORM_DIR=%~dp0..\terraform"
if not exist "%TERRAFORM_DIR%\outputs.env" (
    echo Error: outputs.env not found. Run 'terraform apply' first.
    exit /b 1
)
for /f "tokens=2 delims==" %%i in ('findstr "ELASTIC_IP" "%TERRAFORM_DIR%\outputs.env"') do set PUBLIC_IP=%%i
ssh -i "%TERRAFORM_DIR%\key.pem" ec2-user@%PUBLIC_IP% "tail -f /var/log/user-data.log"