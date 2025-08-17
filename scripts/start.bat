@echo off
setlocal enabledelayedexpansion

:: Set project root directory
set "PROJECT_ROOT=%~dp0.."
set "TERRAFORM_DIR=%PROJECT_ROOT%\terraform"
set "SCRIPTS_DIR=%PROJECT_ROOT%\scripts"

:: Load environment variables from outputs.env
if exist "%TERRAFORM_DIR%\outputs.env" (
    for /f "usebackq tokens=1,2 delims==" %%a in ("%TERRAFORM_DIR%\outputs.env") do (
        set "%%a=%%b"
    )
)

:: Setup doskey shortcuts with absolute paths
doskey tf=cd /d "%TERRAFORM_DIR%" ^& terraform $*
doskey tfa=cd /d "%TERRAFORM_DIR%" ^& terraform apply --auto-approve
doskey tfd=cd /d "%TERRAFORM_DIR%" ^& terraform destroy
doskey tfi=cd /d "%TERRAFORM_DIR%" ^& terraform init -upgrade
doskey tfp=cd /d "%TERRAFORM_DIR%" ^& terraform plan
doskey recreate=call "%SCRIPTS_DIR%\recreate-ec2.bat"
doskey ssh=call "%SCRIPTS_DIR%\ssh-ec2.bat"
doskey logs=call "%SCRIPTS_DIR%\tail-logs.bat"
doskey rmhost=call "%SCRIPTS_DIR%\remove-host.bat"
doskey cdd=cd /d "%PROJECT_ROOT%"
doskey cds=cd /d "%SCRIPTS_DIR%"
doskey cdt=cd /d "%TERRAFORM_DIR%"
doskey openhands=start https://%ELASTIC_IP%:5000
doskey vscode=start https://%ELASTIC_IP%:5002
doskey portainer=start https://%ELASTIC_IP%:5003
doskey openwebui=start https://%ELASTIC_IP%:5004
doskey searxng=start https://%ELASTIC_IP%:5005
doskey litellm=start http://%ELASTIC_IP%:5001
doskey controller=start %CONTROLLER_URL%
doskey start=call "%SCRIPTS_DIR%\start.bat"

echo.
echo ========================================
echo    OH Setup - Developer Menu
echo ========================================
echo.
echo Directory Info:
echo   Project Root: %PROJECT_ROOT%
echo   Terraform Dir: %TERRAFORM_DIR%
echo   Scripts Dir: %SCRIPTS_DIR%
echo.
echo Environment Info:
echo   IP Address: %ELASTIC_IP%
echo   Instance ID: %INSTANCE_ID%
echo   Security Group: %SECURITY_GROUP_ID%
echo   Key Pair: %KEY_PAIR_NAME%
echo   Subnet ID: %SUBNET_ID%
echo   VPC ID: %VPC_ID%
echo   Controller URL: %CONTROLLER_URL%
echo.
echo Available Commands:
echo   1. tf [cmd]     - Run terraform command
echo   2. tfa          - Terraform apply --auto-approve
echo   3. tfd          - Terraform destroy
echo   4. tfi          - Terraform init -upgrade
echo   5. tfp          - Terraform plan
echo   6. recreate     - Recreate EC2 instance
echo   7. ssh          - SSH to EC2 instance
echo   8. logs         - Tail user data logs
echo   9. rmhost       - Remove host from known_hosts
echo  10. cdd          - Change to main project directory
echo  11. openhands    - Open OpenHands in browser
echo  12. vscode       - Open VSCode in browser
echo  13. portainer    - Open Portainer in browser
echo  14. openwebui    - Open Open WebUI in browser
echo  15. searxng      - Open SearXNG in browser
echo  16. litellm      - Open LiteLLM in browser
echo  17. controller   - Open AWS Controller in browser
echo  18. start        - Reload this menu
echo.
echo Services (after deployment):
echo   OpenHands:  https://%ELASTIC_IP%:5000
echo   VSCode:     https://%ELASTIC_IP%:5002
echo   Portainer:  https://%ELASTIC_IP%:5003
echo   Open WebUI: https://%ELASTIC_IP%:5004
echo   SearXNG:    https://%ELASTIC_IP%:5005
echo   LiteLLM:    http://%ELASTIC_IP%:5001
echo   Controller: %CONTROLLER_URL%
echo.
echo ========================================