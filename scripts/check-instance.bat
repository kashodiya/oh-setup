@echo off
cd /d "%~dp0\..\terraform"
for /f %%i in ('jq -r .instance_id outputs.json') do set INSTANCE_ID=%%i
echo Instance ID: %INSTANCE_ID%
aws ec2 describe-instances --instance-ids %INSTANCE_ID% --query "Reservations[0].Instances[0].State.Name" --output text