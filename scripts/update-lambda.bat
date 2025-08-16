@echo off
setlocal enabledelayedexpansion

:: Set project root directory
set "PROJECT_ROOT=%~dp0.."
set "CONTROLLER_DIR=%PROJECT_ROOT%\controller"
set "TEMP_DIR=%PROJECT_ROOT%\temp"
set "TERRAFORM_DIR=%PROJECT_ROOT%\terraform"

:: Load AWS profile from terraform.tfvars
for /f "usebackq tokens=1,2 delims== " %%a in ("%TERRAFORM_DIR%\terraform.tfvars") do (
    if "%%a"=="aws_profile" (
        set "AWS_PROFILE=%%b"
        set "AWS_PROFILE=!AWS_PROFILE:"=!"
    )
)

echo Updating Lambda function...
echo AWS Profile: %AWS_PROFILE%

:: Create zip file
cd /d "%CONTROLLER_DIR%"
powershell -ExecutionPolicy Bypass -Command "Compress-Archive -Path *.py -DestinationPath '%TEMP_DIR%\controller.zip' -Force"

:: Update Lambda function
aws lambda update-function-code --function-name oh-controller --zip-file fileb://%TEMP_DIR%/controller.zip --profile %AWS_PROFILE% --region us-east-1

echo Lambda function updated successfully!
