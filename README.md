# ACTV-01

Repositório para distribuição e execução remota de scripts em máquinas gerenciadas pelo Action1.

## Execução via Action1

O exemplo abaixo baixa um arquivo `.cmd` hospedado neste repositório, salva temporariamente na máquina e aguarda sua execução terminar.

```powershell
$Url = "https://raw.githubusercontent.com/jotaCorsino/actv-01/main/script.cmd"
$Destino = "$env:TEMP\script.cmd"

Write-Host "Baixando script..."
Invoke-WebRequest -Uri $Url -OutFile $Destino

if (-not (Test-Path $Destino)) {
    Write-Error "Falha ao baixar o arquivo."
    exit 1
}

Write-Host "Executando script..."
$Processo = Start-Process -FilePath $Destino -Wait -PassThru

Write-Host "Execução finalizada. Código: $($Processo.ExitCode)"

Remove-Item $Destino -Force -ErrorAction SilentlyContinue

exit $Processo.ExitCode
```

## Versão curta

```powershell
$u="https://raw.githubusercontent.com/jotaCorsino/actv-01/main/script.cmd"
$d="$env:TEMP\script.cmd"
Invoke-WebRequest -Uri $u -OutFile $d
Start-Process $d -Wait
Remove-Item $d -Force -ErrorAction SilentlyContinue
```

## Como usar

1. Disponibilize o arquivo desejado no repositório com o nome `script.cmd`.
2. Confirme que o endereço usado em `$Url` corresponde ao caminho real do arquivo.
3. No Action1, crie uma ação **Run PowerShell Script**.
4. Cole um dos scripts acima.
5. Execute a ação nos computadores selecionados.

> Como o repositório é público, arquivos disponíveis por meio de `raw.githubusercontent.com` podem ser acessados sem autenticação.