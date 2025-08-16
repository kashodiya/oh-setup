@echo off
for /f "tokens=2 delims==" %%i in ('findstr "ELASTIC_IP" "%~dp0\..\terraform\outputs.env"') do set PUBLIC_IP=%%i
ssh -i "%~dp0\..\terraform\key.pem" ec2-user@%PUBLIC_IP% "tail -f /var/log/user-data.log"