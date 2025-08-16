@echo off
setlocal
cd /d "%~dp0\.."
for /f "tokens=2 delims==" %%a in ('findstr "ELASTIC_IP" terraform\outputs.env') do set ELASTIC_IP=%%a

echo Updating Caddy configuration on %ELASTIC_IP%...
scp -i "terraform\key.pem" -r caddy ec2-user@%ELASTIC_IP%:/tmp/
ssh -i "terraform\key.pem" ec2-user@%ELASTIC_IP% "sudo cp -R /tmp/caddy/* /etc/caddy/ && sudo systemctl reload caddy && echo 'Caddy updated successfully'"