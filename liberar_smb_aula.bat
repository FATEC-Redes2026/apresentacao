@echo off
chcp 65001 >nul
setlocal

REM ============================================================
REM  Libera a pasta Documentos\Aula via SMB (rede)
REM  Usuario de acesso: Fatec  /  Senha: A12345678b
REM ============================================================

set "USUARIO=Fatec"
set "SENHA=A12345678b"
set "COMPARTILHAMENTO=Aula"

REM --- Pede permissao de administrador se necessario ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Solicitando permissao de administrador...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo.
echo === Localizando a pasta Documentos ===
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "[Environment]::GetFolderPath('MyDocuments')"`) do set "DOCS=%%D"
set "PASTA=%DOCS%\Aula"

if not exist "%PASTA%" (
    echo Pasta nao encontrada, criando: %PASTA%
    mkdir "%PASTA%"
) else (
    echo Pasta encontrada: %PASTA%
)

echo.
echo === Criando/atualizando o usuario %USUARIO% ===
net user %USUARIO% >nul 2>&1
if %errorlevel%==0 (
    net user %USUARIO% %SENHA% >nul
    echo Usuario ja existia, senha atualizada.
) else (
    net user %USUARIO% %SENHA% /add /passwordchg:no /fullname:"Acesso Rede Fatec" >nul
    echo Usuario criado.
)
powershell -NoProfile -Command "Set-LocalUser -Name '%USUARIO%' -PasswordNeverExpires $true"

echo.
echo === Ativando servicos de compartilhamento ===
sc config LanmanServer start= auto >nul
net start LanmanServer >nul 2>&1
sc config FDResPub start= auto >nul
net start FDResPub >nul 2>&1

echo.
echo === Configurando rede como Privada e liberando o firewall ===
powershell -NoProfile -Command "Get-NetConnectionProfile | Where-Object {$_.NetworkCategory -ne 'DomainAuthenticated'} | Set-NetConnectionProfile -NetworkCategory Private"
REM Grupos por ID (funciona em Windows em portugues ou ingles)
REM -28502 = Compartilhamento de Arquivos e Impressoras / -32752 = Descoberta de Rede
powershell -NoProfile -Command "Enable-NetFirewallRule -Group '@FirewallAPI.dll,-28502'; Enable-NetFirewallRule -Group '@FirewallAPI.dll,-32752'"

echo.
echo === Compartilhando a pasta ===
net share %COMPARTILHAMENTO% /delete /y >nul 2>&1
net share %COMPARTILHAMENTO%="%PASTA%" /GRANT:%USUARIO%,CHANGE /REMARK:"Pasta de aula"

REM Permissao NTFS (ler, gravar, apagar) para o usuario
icacls "%PASTA%" /grant "%USUARIO%:(OI)(CI)M" /T >nul

echo.
echo ============================================================
echo  PRONTO! Acesse pela rede com:
echo.
echo    Windows:  \\%COMPUTERNAME%\%COMPARTILHAMENTO%
echo    Mac:      smb://IP_DESTE_PC/%COMPARTILHAMENTO%
echo.
echo    Usuario:  %USUARIO%
echo    Senha:    %SENHA%
echo.
echo  IP deste PC:
ipconfig | findstr /i "IPv4"
echo ============================================================
echo.
pause
