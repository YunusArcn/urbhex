# URBHEX bolge tarama iscisini dongu modunda baslatir.
# Uygulamayi kullanirken bunu AYRI bir PowerShell penceresinde acik tut:
# "Bu bolgede haber tara" butonu 20-40 sn icinde sonuc dondurur.
Set-Location (Join-Path $PSScriptRoot "bot")
python scan_worker.py --loop
