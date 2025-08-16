@echo off
setlocal enabledelayedexpansion

:: Set project root directory
set "PROJECT_ROOT=%~dp0.."
set "TERRAFORM_DIR=%PROJECT_ROOT%\terraform"

:: Load AWS profile from terraform.tfvars
for /f "usebackq tokens=1,2 delims== " %%a in ("%TERRAFORM_DIR%\terraform.tfvars") do (
    if "%%a"=="aws_profile" (
        set "AWS_PROFILE=%%b"
        set "AWS_PROFILE=!AWS_PROFILE:"=!"
    )
)

echo Getting Lambda logs...
echo AWS Profile: %AWS_PROFILE%
echo.

:: List all log streams first
echo Available log streams:
aws logs describe-log-streams --log-group-name "/aws/lambda/oh-controller" --profile %AWS_PROFILE% --region us-east-1 --query "logStreams[*].logStreamName" --output table
echo.

:: Get the latest log stream (use the first one from the list)
set "LOG_STREAM=2025/08/16/[$LATEST]2e68bc2de0354913aaac2c022a1c32e0"

echo Using log stream: %LOG_STREAM%
echo.
echo Recent log events:
aws logs get-log-events --log-group-name "/aws/lambda/oh-controller" --log-stream-name "%LOG_STREAM%" --profile %AWS_PROFILE% --region us-east-1 --query "events[*].message" --output text

:end

pause