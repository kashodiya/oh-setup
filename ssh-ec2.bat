@echo off
cd terraform

REM Read variables from outputs.env
for /f "tokens=1,2 delims==" %%a in (outputs.env) do (
    set %%a=%%b
)

REM SSH to EC2 instance
ssh -i key.pem ec2-user@%ELASTIC_IP%