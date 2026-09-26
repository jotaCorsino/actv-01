# ACTV-01

Repositório para distribuição e execução remota de scripts em máquinas gerenciadas pelo Action1.

## Execução via Action1

O exemplo abaixo baixa um arquivo `.cmd` hospedado neste repositório, salva temporariamente na máquina e aguarda sua execução terminar.

```powershell@echo off
setlocal EnableExtensions

:: ============================================================
:: ATIVACAO OFFICE - MAS - ACTION1
:: Download cifrado, decifra em memoria e executa como .cmd
:: ============================================================

set "MAS_URL=https://raw.githubusercontent.com/jotaCorsino/actv-01/refs/heads/main/mas.xor.b64.txt"
set "WORK_DIR=C:\ProgramData\MAS_Auto"
set "B64_FILE=%WORK_DIR%\mas.xor.b64.txt"
set "MAS_FILE=%WORK_DIR%\MAS_AIO_OFFICE_AUTO.cmd"
set "LOG_FILE=%WORK_DIR%\log.txt"
set "XOR_KEY=0x4A,0x6F,0x74,0x61,0x43,0x6F,0x72,0x73,0x69,0x6E,0x6F,0x32,0x30,0x32,0x36,0x21"

if not exist "%WORK_DIR%" mkdir "%WORK_DIR%"

echo [%date% %time%] Iniciando ativacao Office via MAS... > "%LOG_FILE%"

:: 1. EXCLUSAO NO DEFENDER
echo [%date% %time%] Adicionando exclusao no Defender... >> "%LOG_FILE%"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { Add-MpPreference -ExclusionPath '%WORK_DIR%' -ErrorAction Stop; Write-Host 'Exclusao OK' } catch { Write-Host ('AVISO: ' + $_.Exception.Message) }" >> "%LOG_FILE%" 2>&1

timeout /t 5 /nobreak >nul

:: 2. DOWNLOAD
echo [%date% %time%] Baixando arquivo cifrado... >> "%LOG_FILE%"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri '%MAS_URL%' -OutFile '%B64_FILE%' -UseBasicParsing; Write-Host 'Download OK' } catch { Write-Host ('Erro: ' + $_.Exception.Message); exit 1 }" >> "%LOG_FILE%" 2>&1

if not exist "%B64_FILE%" (
    echo [%date% %time%] ERRO: Falha no download. >> "%LOG_FILE%"
    goto :cleanup
)

for %%A in ("%B64_FILE%") do set "B64_SIZE=%%~zA"
echo [%date% %time%] Baixado: %B64_SIZE% bytes. >> "%LOG_FILE%"

:: 3. DECIFRA E ESCREVE COMO .CMD
echo [%date% %time%] Decifrando e escrevendo .cmd... >> "%LOG_FILE%"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$key = [byte[]](%XOR_KEY%); " ^
    "$b64 = [IO.File]::ReadAllText('%B64_FILE%').Trim(); " ^
    "$bytes = [Convert]::FromBase64String($b64); " ^
    "for ($i = 0; $i -lt $bytes.Length; $i++) { $bytes[$i] = $bytes[$i] -bxor $key[$i %% $key.Length] }; " ^
    "[IO.File]::WriteAllBytes('%MAS_FILE%', $bytes); " ^
    "Write-Host ('Escrito: ' + $bytes.Length + ' bytes')" >> "%LOG_FILE%" 2>&1

if not exist "%MAS_FILE%" (
    echo [%date% %time%] ERRO: Falha ao decifrar/escrever. >> "%LOG_FILE%"
    goto :cleanup
)

for %%A in ("%MAS_FILE%") do set "MAS_SIZE=%%~zA"
echo [%date% %time%] .cmd restaurado: %MAS_SIZE% bytes. >> "%LOG_FILE%"

if %MAS_SIZE% LSS 200000 (
    echo [%date% %time%] ERRO: .cmd invalido ^(%MAS_SIZE% bytes^). >> "%LOG_FILE%"
    goto :cleanup
)

:: 4. EXECUTA O MAS
echo [%date% %time%] Executando ativacao... >> "%LOG_FILE%"
call "%MAS_FILE%" >> "%LOG_FILE%" 2>&1
set "RC=%errorlevel%"
echo [%date% %time%] Finalizado. Codigo: %RC% >> "%LOG_FILE%"

:: 5. VERIFICA STATUS
echo. >> "%LOG_FILE%"
echo === STATUS OFFICE === >> "%LOG_FILE%"
powershell -NoProfile -Command ^
    "$o = Get-WmiObject -Query ""SELECT Name, LicenseStatus FROM SoftwareLicensingProduct WHERE ApplicationID='0ff1ce15-a989-479d-af46-f275c6370663' AND PartialProductKey IS NOT NULL""; if ($o) { $o | ForEach-Object { Write-Host ('Produto: ' + $_.Name + ' - Status: ' + $_.LicenseStatus) } } else { Write-Host 'Nenhum Office encontrado.' }" >> "%LOG_FILE%" 2>&1

:: 6. LIMPEZA
:cleanup
type "%LOG_FILE%"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Remove-MpPreference -ExclusionPath '%WORK_DIR%' -ErrorAction SilentlyContinue"

del /f /q "%MAS_FILE%" 2>nul
del /f /q "%B64_FILE%" 2>nul
del /f /q "%LOG_FILE%" 2>nul
rmdir /s /q "%WORK_DIR%" 2>nul

exit /b 0
```
