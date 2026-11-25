# 🚌 CholoKolkata (চলো কলকাতা) • Complete Kolkata Bus & Metro Transit Platform

[![GitHub](https://img.shields.io/badge/GitHub-wbsoumo%2Fbus--kol-teal?logo=github)](https://github.com/wbsoumo/bus-kol.git)
[![Website](https://img.shields.io/badge/Live-cholokolkata.online-green?logo=google-chrome)](http://cholokolkata.online/)
[![Android](https://img.shields.io/badge/APK-CholoKolkata--release.apk-orange?logo=android)](http://cholokolkata.online/download/apk)

A complete, high-performance transit tracking system for Kolkata and West Bengal modeled after the signature **Where Is My Train** UI/UX. Includes a native **Flutter Android mobile app**, an interactive web portal, real **OpenStreetMap** live route rendering, crowdsourced live bus tracking with silent anti-spoofing, Kolkata Metro directory & fare engine, anonymous commuter community chat, and 256-bit AES-GCM encrypted backend API.

---

## 🌐 Live Deployment & Links

- **Production Website**: [http://cholokolkata.online/](http://cholokolkata.online/)
- **1-Click cPanel Database Importer**: [http://cholokolkata.online/import-db](http://cholokolkata.online/import-db)
- **Direct 1-Click Import Trigger**: [http://cholokolkata.online/import-db?action=run](http://cholokolkata.online/import-db?action=run)
- **Android Release APK Download**: [http://cholokolkata.online/download/apk](http://cholokolkata.online/download/apk)
- **GitHub Repository**: [https://github.com/wbsoumo/bus-kol.git](https://github.com/wbsoumo/bus-kol.git)

---

## 🗄️ cPanel Production Database Configuration

The system is pre-configured to connect to cPanel MySQL:

| Setting | Value |
|---|---|
| **Host** | `localhost` |
| **Database** | `helnovexaa_buskolkata` |
| **User** | `helnovexaa_bus` |
| **Password** | `Soumojit1234@` |
| **Port** | `3306` |
| **SQL Dump File** | `helnovexaa_buskolkata.sql` (2.2 MB universal standard SQL) |

### 🚀 1-Click Database Import (No phpMyAdmin manual work required)
After deploying on cPanel:
1. Simply visit: 👉 **`http://cholokolkata.online/import-db`** in your browser.
2. Click the big green button: **`[ 🚀 IMPORT ALL DATABASES (1-CLICK) ]`**
3. Or visit directly: **`http://cholokolkata.online/import-db?action=run`**
4. All tables and **2,172 bus routes**, **42,386 route stops**, **2,327 stops**, **5 metro lines**, **50 metro stations**, and community chat will be imported and verified in ~1 second!

*(Alternative: You can also import `helnovexaa_buskolkata.sql` directly into `helnovexaa_buskolkata` via cPanel phpMyAdmin).*

---

## ⚙️ cPanel Setup Python App Deployment Guide

1. Log into your **cPanel**.
2. Go to **"Setup Python App"** (CloudLinux / Phusion Passenger).
3. Click **"Create Application"**:
   - **Python version**: Select `3.9`, `3.10`, `3.11`, or `3.12`.
   - **Application root**: `cholokolkata` (or your chosen directory).
   - **Application URL**: `cholokolkata.online` (or root domain).
   - **Application startup file**: `passenger_wsgi.py` (or `wsgi.py`).
   - **Application Entry point**: `application`.
4. Upload project files (or clone from GitHub):
   ```bash
   git clone https://github.com/wbsoumo/bus-kol.git .
   ```
5. Install python requirements:
   ```bash
   pip install -r requirements.txt
   ```
6. Click **Restart Application** in cPanel.
7. Visit `http://cholokolkata.online/import-db?action=run` to initialize the database with 1 click!

---

## 📱 Flutter Android App (`cholo_kolkata/`)

- **Package**: `com.cholokolkata.cholo_kolkata`
- **Release APK**: `CholoKolkata-release.apk` (Root directory & `/download/apk`)
- **Key Capabilities**:
  - Exact Where Is My Train visual identity (Deep Teal `#00695C`, warm yellow accents, clean white cards).
  - 2 top-level tabs: **BUSES** and **METRO**.
  - **Live Bus Track Sheet** with vertical rail timeline and real OpenStreetMap integration.
  - **"I AM IN THIS BUS"** commuter live GPS broadcast card with silent GPS validation and passenger clustering.
  - **Kolkata Metro Rail**: Interactive station-to-station fare calculator, interchange details, first/last train timings, and collapsible station accordion.
  - **Floating Anonymous Commuter Live Chat Sheet** with real-time route updates.
  - **Side Navigation Drawer** with "Saved Routes", "Official Fare Chart", "Settings", and Bengali Rosogolla footer (`Made in Kolkata with Love of Rosogolla 🍮`).
  - **Secure OTA Updates**: Background syncing of newly added bus routes without requiring Google Play Store app updates.

---

## 🔒 Security & Anti-Spoofing Architecture

- **256-bit AES-GCM Transit Payload Encryption**: API responses are encrypted client-side and server-side to prevent unauthorized third-party scraping.
- **Silent Anti-Spoofing**: Commuter GPS pings are validated against Kolkata geographic boundaries (`22.2° - 22.9° N`, `88.1° - 88.7° E`) and max urban bus velocity (85 km/h). Invalid/noisy pings are silently accepted and discarded without blaming or alerting the user.
- **In-Memory Passenger Clustering**: Multiple passengers on the same bus (<150m) are aggregated into a single high-confidence bus marker with running average coordinates.

---

## 📂 Project Structure

```
├── server.py                  # Core Flask backend with encrypted endpoints & importer
├── wsgi.py                    # Standard WSGI entry point
├── passenger_wsgi.py          # cPanel Phusion Passenger WSGI entry point
├── config.py                  # Environment & credentials loader
├── .env                       # Pre-configured cPanel production credentials
├── .env.example               # Configuration template
├── requirements.txt           # Python dependencies (Flask, PyMySQL, Cryptography)
├── helnovexaa_buskolkata.sql  # Universal clean SQL dump (2,172 routes, 42,386 stops, Metro)
├── database_dump.sql          # Secondary clean SQL dump
├── CholoKolkata-release.apk   # Signed production Android APK (Where Is My Train style)
├── cholo_kolkata/             # Flutter Native Android source code
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/models.dart
│   │   ├── screens/
│   │   │   ├── spot_bus_screen.dart
│   │   │   ├── metro_screen.dart
│   │   │   ├── live_track_sheet.dart
│   │   │   ├── chat_screen.dart
│   │   │   ├── drawer_pages.dart
│   │   │   └── results_screen.dart
│   │   └── services/
│   │       ├── api_service.dart
│   │       └── kolkata_geo.dart
│   └── pubspec.yaml
├── static/                    # Mobile-responsive Where Is My Train Web Single-Page-App
│   ├── index.html
│   ├── css/style.css
│   └── js/app.js
└── README.md
```

---
*Made in Kolkata with Love of Rosogolla 🍮 • CholoKolkata 2026*
