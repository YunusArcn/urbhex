"""Eski kayıtlardaki boş h3_res8 sütununu doldurur (tek seferlik onarım).

h3_res8, h3_res9'un ebeveyni olduğu için ek veri gerekmez.
Kullanım: python backfill_res8.py
"""
import h3

import db
from config import H3_RES_POP


def run() -> None:
    client = db.get_client()
    rows = client.table("incidents").select("id, h3_res9").is_("h3_res8", "null").execute().data
    print(f"[backfill] h3_res8'i boş {len(rows)} kayıt bulundu.")
    for row in rows:
        client.table("incidents").update(
            {"h3_res8": h3.cell_to_parent(row["h3_res9"], H3_RES_POP)}
        ).eq("id", row["id"]).execute()
    print("[backfill] Bitti.")


if __name__ == "__main__":
    run()
