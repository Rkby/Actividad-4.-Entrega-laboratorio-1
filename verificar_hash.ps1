$ErrorActionPreference = 'Stop'
$archivo = Join-Path $PSScriptRoot 'logs\postgresql-lab01.log'
$esperado = 'A4EF66FDFEE1D9BC50BBA66BC4AB5B7E1FC8432EE02FBBECDE23E4B3AEC569FD'

if (-not (Test-Path -LiteralPath $archivo -PathType Leaf)) {
    Write-Error "No se encontró $archivo. Copia primero el LOG exportado a la carpeta logs."
    exit 1
}

$obtenido = (Get-FileHash -LiteralPath $archivo -Algorithm SHA256).Hash
Write-Host "SHA-256 calculado: $obtenido"
Write-Host "SHA-256 esperado:  $esperado"

if ($obtenido -eq $esperado) {
    Write-Host 'VERIFICACIÓN CORRECTA: el archivo coincide con el hash documentado.' -ForegroundColor Green
    exit 0
}

Write-Host 'ADVERTENCIA: el archivo no coincide. Pudo cambiar, redactarse o ser otro LOG.' -ForegroundColor Yellow
exit 2
