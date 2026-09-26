# ACTV-01

Repositório para distribuição e execução remota de scripts em máquinas gerenciadas pelo Action1.

## Execução via Action1

O exemplo abaixo baixa um arquivo `.cmd` hospedado neste repositório, salva temporariamente na máquina e aguarda sua execução terminar.

```powershell@echo off
@echo off
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

:: Usa > (nao >>) para sobrescrever log antigo
echo [%date% %time%] Iniciando ativacao Office via MAS... > "%LOG_FILE%"

:: ============================================================
:: 1. EXCLUSAO NO DEFENDER
:: ============================================================
echo [%date% %time%] Adicionando exclusao no Defender... >> "%LOG_FILE%"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { Add-MpPreference -ExclusionPath '%WORK_DIR%' -ErrorAction Stop; Write-Host 'Exclusao OK' } catch { Write-Host ('AVISO: ' + $_.Exception.Message) }" >> "%LOG_FILE%" 2>&1

:: ping eh o workaround universal para timeout quando stdin esta redirecionado
:: -n 6 = 6 pings com 1s de intervalo = ~5 segundos
ping -n 6 127.0.0.1 >nul

:: ============================================================
:: 2. DOWNLOAD COM curl.exe (nativo do Windows 10 1803+)
:: ============================================================
echo [%date% %time%] Baixando arquivo cifrado... >> "%LOG_FILE%"

:: Remove arquivo antigo se existir
if exist "%B64_FILE%" del /f /q "%B64_FILE%" 2>nul

:: -L = segue redirects
:: -s = silencioso
:: -S = mostra erros mesmo em silencioso
:: -f = falha em HTTP 4xx/5xx
:: -o = arquivo de saida
:: --retry 3 = tenta 3x
curl.exe -L -s -S -f --retry 3 --retry-delay 2 -o "%B64_FILE%" "%MAS_URL%" >> "%LOG_FILE%" 2>&1
set "CURL_RC=%errorlevel%"

echo [%date% %time%] curl retornou: %CURL_RC% >> "%LOG_FILE%"

if not exist "%B64_FILE%" (
    echo [%date% %time%] ERRO: Arquivo nao foi baixado. >> "%LOG_FILE%"
    goto :cleanup
)

for %%A in ("%B64_FILE%") do set "B64_SIZE=%%~zA"
echo [%date% %time%] Baixado: %B64_SIZE% bytes. >> "%LOG_FILE%"

:: Sanidade: se for menor que 100 KB, provavelmente eh pagina de erro
if %B64_SIZE% LSS 100000 (
    echo [%date% %time%] ERRO: arquivo suspeito ^(%B64_SIZE% bytes^). >> "%LOG_FILE%"
    echo --- primeiros 200 chars do arquivo: >> "%LOG_FILE%"
    powershell -NoProfile -Command "Get-Content '%B64_FILE%' -TotalCount 1 | ForEach-Object { $_.Substring(0, [Math]::Min(200, $_.Length)) }" >> "%LOG_FILE%" 2>&1
    goto :cleanup
)

:: ============================================================
:: 3. DECIFRA E ESCREVE COMO .cmd
:: ============================================================
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

:: ============================================================
:: 4. EXECUTA O MAS
:: ============================================================
echo [%date% %time%] Executando ativacao... >> "%LOG_FILE%"
call "%MAS_FILE%" >> "%LOG_FILE%" 2>&1
set "RC=%errorlevel%"
echo [%date% %time%] Finalizado. Codigo: %RC% >> "%LOG_FILE%"

:: ============================================================
:: 5. VERIFICA STATUS
:: ============================================================
echo. >> "%LOG_FILE%"
echo === STATUS OFFICE === >> "%LOG_FILE%"

powershell -NoProfile -Command ^
    "$o = Get-WmiObject -Query ""SELECT Name, LicenseStatus FROM SoftwareLicensingProduct WHERE ApplicationID='0ff1ce15-a989-479d-af46-f275c6370663' AND PartialProductKey IS NOT NULL""; if ($o) { $o | ForEach-Object { Write-Host ('Produto: ' + $_.Name + ' - Status: ' + $_.LicenseStatus) } } else { Write-Host 'Nenhum Office encontrado.' }" >> "%LOG_FILE%" 2>&1

:: ============================================================
:: 6. LIMPEZA
:: ============================================================
:cleanup

:: Mostra o log no output do Action1
type "%LOG_FILE%"

:: Remove exclusao do Defender
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Remove-MpPreference -ExclusionPath '%WORK_DIR%' -ErrorAction SilentlyContinue" >nul 2>&1

:: Remove arquivos
del /f /q "%MAS_FILE%" 2>nul
del /f /q "%B64_FILE%" 2>nul
del /f /q "%LOG_FILE%" 2>nul
rmdir /s /q "%WORK_DIR%" 2>nul

exit /b 0
```
