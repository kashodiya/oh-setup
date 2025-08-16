@echo off
set "TERRAFORM_DIR=%~dp0..\terraform"
if not exist "%TERRAFORM_DIR%\outputs.env" (
    echo Error: outputs.env not found. Run 'terraform apply' first.
    exit /b 1
)
for /f "tokens=1,2 delims==" %%a in ("%TERRAFORM_DIR%\outputs.env") do (
    if "%%a"=="ELASTIC_IP" set EIP=%%b
)
echo IP address: %EIP%
@REM echo Testing connectivity...
@REM ping -n 1 %EIP% >nul 2>&1
@REM if %errorlevel% neq 0 (
@REM     echo Warning: Cannot ping %EIP%. Instance may not be ready or subnet lacks internet access.
@REM )
ssh -i "%TERRAFORM_DIR%\key.pem" ec2-user@%EIP%
