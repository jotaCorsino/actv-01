@echo off
setlocal EnableExtensions

:: ============================================================
:: ATIVACAO OFFICE - MAS AUTOMATICO - ACTION1
:: Baixa, executa e remove o script de ativacao
:: ============================================================

:: --- CONFIGURACOES ---
set "MAS_URL=https://raw.githubusercontent.com/jotaCorsino/actv-01/refs/heads/main/MAS_AIO_OFFICE_AUTO.bat"
set "WORK_DIR=C:\ProgramData\MAS_Auto"
set "MAS_FILE=%WORK_DIR%\MAS_AIO_OFFICE_AUTO.bat"
set "LOG_FILE=%WORK_DIR%\activation_log.txt"

:: --- PREPARACAO ---
if not exist "%WORK_DIR%" mkdir "%WORK_DIR%"

echo [%date% %time%] Iniciando ativacao do Office via MAS... > "%LOG_FILE%"

:: --- DOWNLOAD ---
echo [%date% %time%] Baixando script de ativacao... >> "%LOG_FILE%"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { Invoke-WebRequest -Uri '%MAS_URL%' -OutFile '%MAS_FILE%' -UseBasicParsing; Write-Host 'Download OK' } catch { Write-Host $_.Exception.Message; exit 1 }" >> "%LOG_FILE%" 2>&1

if not exist "%MAS_FILE%" (
    echo [%date% %time%] ERRO: Falha ao baixar o arquivo. >> "%LOG_FILE%"
    type "%LOG_FILE%"
    exit /b 1
)

:: --- VERIFICACAO DE INTEGRIDADE (tamanho minimo) ---
for %%A in ("%MAS_FILE%") do set "FILE_SIZE=%%~zA"

if not defined FILE_SIZE (
    echo [%date% %time%] ERRO: Arquivo nao encontrado apos download. >> "%LOG_FILE%"
    type "%LOG_FILE%"
    exit /b 1
)

if %FILE_SIZE% LSS 200000 (
    echo [%date% %time%] ERRO: Arquivo invalido ^(%FILE_SIZE% bytes^). Download pode ter sido truncado. >> "%LOG_FILE%"
    del /f /q "%MAS_FILE%"
    type "%LOG_FILE%"
    exit /b 1
)

echo [%date% %time%] Download concluido. Tamanho: %FILE_SIZE% bytes. >> "%LOG_FILE%"

:: --- EXECUCAO ---
echo [%date% %time%] Executando ativacao... >> "%LOG_FILE%"

:: O Action1 executa como SYSTEM, entao nao ha necessidade de elevacao adicional.
:: O script MAS_AIO_OFFICE_AUTO.bat ja foi modificado para rodar /Ohook e sair.
call "%MAS_FILE%" >> "%LOG_FILE%" 2>&1
set "RC=%errorlevel%"

echo [%date% %time%] Execucao finalizada. Codigo de retorno: %RC% >> "%LOG_FILE%"

:: --- VERIFICACAO POS-EXECUCAO ---
echo. >> "%LOG_FILE%"
echo === STATUS DO OFFICE === >> "%LOG_FILE%"

powershell -NoProfile -Command ^
    "try { $office = Get-WmiObject -Query ""SELECT Name, LicenseStatus FROM SoftwareLicensingProduct WHERE ApplicationID='0ff1ce15-a989-479d-af46-f275c6370663' AND PartialProductKey IS NOT NULL""; if ($office) { $office | ForEach-Object { Write-Host ('Produto: ' + $_.Name + ' - Status: ' + $_.LicenseStatus) } } else { Write-Host 'Nenhum produto Office encontrado.' } } catch { Write-Host 'Erro ao consultar status.' }" >> "%LOG_FILE%" 2>&1

:: --- LIMPEZA ---
echo. >> "%LOG_FILE%"
echo [%date% %time%] Removendo arquivos temporarios... >> "%LOG_FILE%"
del /f /q "%MAS_FILE%" 2>nul
rmdir /s /q "%WORK_DIR%" 2>nul

:: --- EXIBIR LOG NO ACTION1 ---
type "%LOG_FILE%"

exit /b %RC%