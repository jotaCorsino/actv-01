# ACTV-01

Repositório para distribuição e execução remota de scripts em máquinas gerenciadas pelo Action1.

## Execução via Action1

O exemplo abaixo baixa um arquivo `.cmd` hospedado neste repositório, salva temporariamente na máquina e aguarda sua execução terminar.

```powershell@echo off
@echo off
setlocal EnableExtensions

set "MAS_URL=https://raw.githubusercontent.com/jotaCorsino/actv-01/main/mas.xor.b64.txt"
set "WORK_DIR=C:\ProgramData\MAS_Auto"
set "B64_FILE=%WORK_DIR%\mas.xor.b64.txt"
set "MAS_FILE=%WORK_DIR%\MAS_AIO_OFFICE_AUTO.cmd"
set "LOG_FILE=%WORK_DIR%\log.txt"
set "XOR_KEY=0x4A,0x6F,0x74,0x61,0x43,0x6F,0x72,0x73,0x69,0x6E,0x6F,0x32,0x30,0x32,0x36,0x21"

:: Limpa execucao anterior
if exist "%WORK_DIR%" rmdir /s /q "%WORK_DIR%" 2>nul
mkdir "%WORK_DIR%" 2>nul

> "%LOG_FILE%" echo [%date% %time%] Iniciando ativacao Office via MAS...

:: 1. EXCLUSAO NO DEFENDER
>> "%LOG_FILE%" echo [%date% %time%] Adicionando exclusao no Defender...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Add-MpPreference -ExclusionPath '%WORK_DIR%' -ErrorAction Stop; 'Exclusao OK' } catch { 'AVISO: ' + $_.Exception.Message }" >> "%LOG_FILE%" 2>&1

:: 2. DELAY sem timeout (ping funciona com stdin redirecionado)
ping -n 3 127.0.0.1 >nul

:: 3. DOWNLOAD com curl.exe (binario nativo, nao sofre com pipe de stdin)
>> "%LOG_FILE%" echo [%date% %time%] Baixando arquivo cifrado...
curl.exe -L -s -S -f --retry 3 --retry-delay 2 -o "%B64_FILE%" "%MAS_URL%" >> "%LOG_FILE%" 2>&1
set "CURL_RC=%errorlevel%"
>> "%LOG_FILE%" echo [%date% %time%] curl retornou: %CURL_RC%

if not exist "%B64_FILE%" (
    >> "%LOG_FILE%" echo [%date% %time%] ERRO: Arquivo nao foi baixado.
    goto :cleanup
)

for %%A in ("%B64_FILE%") do set "B64_SIZE=%%~zA"
>> "%LOG_FILE%" echo [%date% %time%] Baixado: %B64_SIZE% bytes.

if %B64_SIZE% LSS 100000 (
    >> "%LOG_FILE%" echo [%date% %time%] ERRO: tamanho suspeito.
    goto :cleanup
)

:: 4. DECIFRA E ESCREVE O .CMD
>> "%LOG_FILE%" echo [%date% %time%] Decifrando e escrevendo .cmd...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$key=[byte[]](%XOR_KEY%); $b64=[IO.File]::ReadAllText('%B64_FILE%').Trim(); $bytes=[Convert]::FromBase64String($b64); for($i=0;$i -lt $bytes.Length;$i++){$bytes[$i]=$bytes[$i] -bxor $key[$i %% $key.Length]}; [IO.File]::WriteAllBytes('%MAS_FILE%',$bytes); 'Escrito: ' + $bytes.Length + ' bytes'" >> "%LOG_FILE%" 2>&1

if not exist "%MAS_FILE%" (
    >> "%LOG_FILE%" echo [%date% %time%] ERRO: Falha ao decifrar.
    goto :cleanup
)

for %%A in ("%MAS_FILE%") do set "MAS_SIZE=%%~zA"
>> "%LOG_FILE%" echo [%date% %time%] .cmd restaurado: %MAS_SIZE% bytes.

if %MAS_SIZE% LSS 200000 (
    >> "%LOG_FILE%" echo [%date% %time%] ERRO: .cmd invalido.
    goto :cleanup
)

:: 5. EXECUTA O MAS
>> "%LOG_FILE%" echo [%date% %time%] Executando ativacao...
call "%MAS_FILE%" >> "%LOG_FILE%" 2>&1
set "RC=%errorlevel%"
>> "%LOG_FILE%" echo [%date% %time%] Finalizado. Codigo: %RC%

:: 6. STATUS OFFICE
>> "%LOG_FILE%" echo.
>> "%LOG_FILE%" echo === STATUS OFFICE ===
powershell -NoProfile -Command "$o=Get-WmiObject -Query ""SELECT Name, LicenseStatus FROM SoftwareLicensingProduct WHERE ApplicationID='0ff1ce15-a989-479d-af46-f275c6370663' AND PartialProductKey IS NOT NULL""; if($o){$o|ForEach-Object{ 'Produto: ' + $_.Name + ' - Status: ' + $_.LicenseStatus }}else{'Nenhum Office encontrado.'}" >> "%LOG_FILE%" 2>&1

:cleanup
type "%LOG_FILE%"
powershell -NoProfile -Command "Remove-MpPreference -ExclusionPath '%WORK_DIR%' -ErrorAction SilentlyContinue" >nul 2>&1
del /f /q "%MAS_FILE%" 2>nul
del /f /q "%B64_FILE%" 2>nul
del /f /q "%LOG_FILE%" 2>nul
rmdir /s /q "%WORK_DIR%" 2>nul

endlocal
exit /b 0
```
