@echo off
set "PROJECT_ROOT=%~dp0.."
set "TERRAFORM_DIR=%PROJECT_ROOT%\terraform"
if not exist "%TERRAFORM_DIR%\terraform.tfvars" (
    echo Error: terraform.tfvars not found.
    exit /b 1
)
for /f "tokens=3" %%i in ('findstr "aws_profile" "%TERRAFORM_DIR%\terraform.tfvars"') do set PROFILE=%%i
set PROFILE=%PROFILE:"=%
echo Getting Parameter Store values using profile: %PROFILE%
echo.

aws ssm get-parameters --names "/oh/litellm-key" "/oh/source-zip-location" "/oh/elastic-ip" "/oh/project-name" --with-decryption --profile %PROFILE% --region us-east-1 --query "Parameters[*].[Name,Value]" --output table
