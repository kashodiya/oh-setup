@echo off
pushd "%~dp0\..\terraform"
if not exist outputs.env (
    echo Error: outputs.env not found. Run 'terraform apply' first.
    exit /b 1
)
for /f "tokens=1,2 delims==" %%a in (outputs.env) do (
    if "%%a"=="ELASTIC_IP" set EIP=%%b
)
echo Removing host key for %EIP%...
ssh-keygen -R %EIP%
popd