"""h3 uyumluluk katmanı.

Windows Smart App Control bazı makinelerde h3'ün imzasız DLL'ini engelliyor
("Uygulama Denetimi ilkesi bu dosyayı engelledi"). Gerçek h3 yükleniyorsa
aynen kullanılır; yüklenemiyorsa kaba bir kare-grid YEDEĞİ devreye girer:

  - hücre kimliği: "g{res}_{i}_{j}"  (gerçek H3 kimlikleriyle karışmaz)
  - merkez ve ebeveyn hesabı kendi içinde tutarlıdır
  - GitHub Actions (Linux) gerçek h3 kullanır → üretim verisi her zaman gerçek H3

Kullanım: `import h3compat as h3` — API birebir aynı üç fonksiyon.
"""
try:
    from h3 import cell_to_latlng, cell_to_parent, latlng_to_cell  # noqa: F401

    USING_REAL_H3 = True
except Exception:
    USING_REAL_H3 = False
    # res → derece adımı (H3'ün o çözünürlükteki hücre boyutuna yakın)
    _STEPS = {7: 0.02, 8: 0.007, 9: 0.0025}

    def latlng_to_cell(lat: float, lng: float, res: int) -> str:
        s = _STEPS[res]
        return f"g{res}_{round(lat / s)}_{round(lng / s)}"

    def cell_to_latlng(cell: str) -> tuple[float, float]:
        res, i, j = cell[1:].split("_")
        s = _STEPS[int(res)]
        return int(i) * s, int(j) * s

    def cell_to_parent(cell: str, res: int) -> str:
        if not cell.startswith("g"):
            raise ValueError(
                "Gerçek H3 kimliği yedek grid ile işlenemez; bu komutu h3'ün "
                "çalıştığı ortamda (örn. GitHub Actions) çalıştırın."
            )
        lat, lng = cell_to_latlng(cell)
        return latlng_to_cell(lat, lng, res)

    print("[h3compat] UYARI: h3 DLL'i Windows tarafından engellendi — yedek "
          "grid aktif. Uygulama normal çalışır; bulutta gerçek H3 kullanılır.")
