# URBHEX yayin derlemesi — canliya yuklenecek paketi uretir.
# Kullanim (proje kok klasorunden):  .\build_web.ps1
# Cikti: app\build\web  -> bu klasoru Cloudflare Pages'e surukle-birak.
# Anahtarlar bot\.env dosyasindan okunur (SUPABASE_URL, SUPABASE_ANON_KEY).

$envFile = Join-Path $PSScriptRoot "bot\.env"
if (-not (Test-Path $envFile)) { Write-Error "bot\.env bulunamadi"; exit 1 }

$vars = @{}
foreach ($line in Get-Content $envFile) {
    if ($line -match "^\s*([A-Z_]+)\s*=\s*(.+?)\s*$") { $vars[$Matches[1]] = $Matches[2] }
}
if (-not $vars["SUPABASE_ANON_KEY"]) {
    Write-Error "bot\.env icinde SUPABASE_ANON_KEY yok"; exit 1
}

Set-Location (Join-Path $PSScriptRoot "app")
flutter build web --release `
    --dart-define=SUPABASE_URL=$($vars["SUPABASE_URL"]) `
    --dart-define=SUPABASE_ANON_KEY=$($vars["SUPABASE_ANON_KEY"])

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Derleme hazir: app\build\web" -ForegroundColor Green
    Write-Host "Simdi Cloudflare Pages > Create new deployment ile bu klasoru yukle." -ForegroundColor Green
    explorer (Join-Path $PSScriptRoot "app\build\web")
}
