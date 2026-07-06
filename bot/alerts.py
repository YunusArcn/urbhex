"""Güvenlik Alarmı: yeni olay, kayıtlı konumların yakınındaysa bildirim + e-posta.

Premium özellik — lansman döneminde tüm kullanıcılara ücretsiz açık
(favorites.alert_enabled varsayılanı true; ücretlendirme V2'de bu bayrağa bağlanacak).

E-posta: .env içinde SMTP_* değişkenleri doluysa gönderilir; boşsa sessizce
atlanır ve yalnızca uygulama içi bildirim düşer. Gmail için:
  SMTP_HOST=smtp.gmail.com  SMTP_PORT=587  SMTP_USER=adres@gmail.com
  SMTP_PASS=<uygulama şifresi>  (Google Hesap > Güvenlik > Uygulama şifreleri)
"""
import math
import os
import smtplib
from email.mime.text import MIMEText

ALERT_RADIUS_M = 2000  # kayıtlı konumun 2 km çevresi

_TYPE_LABELS = {
    "cinayet": "Cinayet", "silahli_saldiri": "Silahlı saldırı", "gasp": "Gasp",
    "yaralama": "Yaralama", "haneye_tecavuz": "Haneye tecavüz", "kavga": "Kavga",
    "hirsizlik": "Hırsızlık", "uyusturucu": "Uyuşturucu",
    "trafik_kazasi": "Trafik kazası", "diger": "Asayiş olayı",
}


def _haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    r = 6371000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = math.radians(lat2 - lat1), math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def _send_email(to: str, title: str, body: str) -> None:
    host = os.environ.get("SMTP_HOST", "").strip()
    if not host:
        return  # SMTP yapılandırılmamış — sadece uygulama içi bildirim
    msg = MIMEText(
        f"{body}\n\nHaritada gör: https://urbhex.com\n\n"
        "Bu e-postayı, Urbhex'te kayıtlı konumunuz için Güvenlik Alarmı açık "
        "olduğu için aldınız. Ayarlar sayfasından kapatabilirsiniz.",
        "plain", "utf-8",
    )
    msg["Subject"] = f"Urbhex Alarm: {title}"
    msg["From"] = os.environ.get("SMTP_FROM", os.environ.get("SMTP_USER", ""))
    msg["To"] = to
    with smtplib.SMTP(host, int(os.environ.get("SMTP_PORT", "587")), timeout=20) as s:
        s.starttls()
        s.login(os.environ["SMTP_USER"], os.environ["SMTP_PASS"])
        s.send_message(msg)


def dispatch_for_incident(incident: dict) -> None:
    """Yeni eklenen olay için alarm kontrolü. Hata boru hattını asla durdurmaz."""
    import db  # döngüsel importu kırmak için fonksiyon içinde

    client = db.get_client()
    favs = (client.table("favorites")
            .select("user_id, label, lat, lng")
            .eq("alert_enabled", True).execute().data)
    hits = [f for f in favs if _haversine_m(
        f["lat"], f["lng"], incident["lat"], incident["lng"]) <= ALERT_RADIUS_M]
    if not hits:
        return

    user_ids = list({f["user_id"] for f in hits})
    profiles = {p["id"]: p for p in (client.table("profiles")
                .select("id, email").in_("id", user_ids).execute().data)}

    type_label = _TYPE_LABELS.get(incident["event_type"], "Asayiş olayı")
    for f in hits:
        title = f"{f['label']} yakınında: {type_label}"
        body = f"{incident['summary']} ({incident.get('district', '')}, {incident['occurred_on']})"
        client.table("notifications").insert({
            "user_id": f["user_id"],
            "incident_id": incident.get("id"),
            "favorite_label": f["label"],
            "title": title,
            "body": body,
        }).execute()
        email = (profiles.get(f["user_id"]) or {}).get("email")
        if email:
            try:
                _send_email(email, title, body)
            except Exception as exc:
                print(f"[alerts] e-posta gönderilemedi ({email}): {exc}")
    print(f"[alerts] {len(hits)} kullanıcıya alarm gönderildi: {title}")
