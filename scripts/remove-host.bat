@echo off
set "TERRAFORM_DIR=%~dp0..\terraform"
if not exist "%TERRAFORM_DIR%\outputs.env" (
    echo Error: outputs.env not found. Run 'terraform apply' first.
    exit /b 1
)
for /f "tokens=1,2 delims==" %%a in ('type "%TERRAFORM_DIR%\outputs.env"') do (
    if "%%a"=="ELASTIC_IP" set "EIP=%%b"
)
if not defined EIP (
    echo Error: ELASTIC_IP not found in outputs.env
    exit /b 1
)
echo Removing host key for %EIP%...
ssh-keygen -R "%EIP%"