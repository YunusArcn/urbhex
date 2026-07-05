# URBHEX web uygulamasini baslatir.
# Kullanim:  .\run_app.ps1        (proje kok klasorunden)
# Anahtarlar bot\.env dosyasindan okunur:
#   SUPABASE_URL=...
#   SUPABASE_ANON_KEY=...   <- Supabase Dashboard > Settings > API "anon public"

$envFile = Join-Path $PSScriptRoot "bot\.env"
if (-not (Test-Path $envFile)) { Write-Error "bot\.env bulunamadi"; exit 1 }

$vars = @{}
foreach ($line in Get-Content $envFile) {
    if ($line -match "^\s*([A-Z_]+)\s*=\s*(.+?)\s*$") { $vars[$Matches[1]] = $Matches[2] }
}

if (-not $vars["SUPABASE_ANON_KEY"]) {
    Write-Error "bot\.env icinde SUPABASE_ANON_KEY satiri yok. Supabase Dashboard > Settings > API sayfasindaki 'anon public' anahtari ekleyin."
    exit 1
}

Set-Location (Join-Path $PSScriptRoot "app")
flutter run -d chrome --web-port 3000 `
    --dart-define=SUPABASE_URL=$($vars["SUPABASE_URL"]) `
    --dart-define=SUPABASE_ANON_KEY=$($vars["SUPABASE_ANON_KEY"])
