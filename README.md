# Kill Users on Switch — Magisk Module

Modul Magisk yang secara otomatis menjalankan `am set-stop-user-on-switch true` setiap kali perangkat di-boot. Dengan modul ini, ketika kamu berpindah user, user sebelumnya akan otomatis di-stop (killed) — tanpa perlu setting manual lagi.

## 🎯 Masalah yang Diselesaikan

Di Android multi-user, secara default semua user tetap **running** di background meskipun kamu sudah pindah ke user lain. Ini memakan RAM dan baterai.

Solusinya adalah menjalankan:

```
am set-stop-user-on-switch true
```

**Tapi** setting ini reset setiap reboot, sehingga harus dijalankan manual lagi. Modul ini mengotomasi hal tersebut.

## 📦 Cara Install

### Metode 1: Flash via Magisk Manager

1. Download file `kill-users-on-switch-v1.0.0.zip` dari [Releases](../../releases)
2. Buka **Magisk Manager** → **Modules** → **Install from storage**
3. Pilih file ZIP-nya
4. Reboot

### Metode 2: Build sendiri

1. Clone repo ini
2. Jalankan di terminal:
   ```
   cd kill-users
   zip -r kill-users-on-switch-v1.0.0.zip . -x ".git/*" "README.md" "build.ps1"
   ```
   Atau di Windows PowerShell:
   ```powershell
   .\build.ps1
   ```
3. Flash file ZIP yang dihasilkan via Magisk Manager

## 📁 Struktur Modul

```
kill-users/
├── META-INF/
│   └── com/google/android/
│       ├── update-binary      # Magisk installer bootstrap
│       └── updater-script     # Magisk module marker
├── module.prop                # Metadata modul (nama, versi, dll)
├── service.sh                 # Script utama — jalan saat boot
├── action.sh                  # Tombol Action di Magisk Manager
├── customize.sh               # Script instalasi — tampil saat flash
├── build.ps1                  # Build script (Windows)
└── README.md                  # File ini
```

## 🔍 Cara Kerja

### Otomatis saat Boot (`service.sh`)

1. **Boot** → Magisk menjalankan `service.sh` pada trigger `late_start`
2. **Tunggu boot selesai** → Script menunggu `sys.boot_completed == 1` (max 120 detik)
3. **Apply setting** → Menjalankan `am set-stop-user-on-switch true`
4. **Log** → Semua aktivitas dicatat di `/data/adb/modules/kill-users-on-switch/service.log`

### Tombol Action di Magisk Manager (`action.sh`)

Buka **Magisk Manager** → **Modules** → klik ikon ⚙️ **Action** pada modul ini.

Fungsinya:

- Re-enable `am set-stop-user-on-switch true`
- **Kill (stop) semua user** selain user utama (user 0)
- Menampilkan status user sebelum dan sesudah

Berguna kalau kamu mau kill user background secara manual tanpa harus buka terminal.

## 📋 Cek Log

Untuk melihat apakah modul berjalan dengan benar setelah reboot:

```bash
# Via ADB atau terminal root
cat /data/adb/modules/kill-users-on-switch/service.log
```

Contoh output:

```
2026-04-21 18:50:00 | Module started, waiting for boot to complete...
2026-04-21 18:50:10 | Boot completed after ~10s — applying setting...
2026-04-21 18:50:10 | am set-stop-user-on-switch true → Set to true
2026-04-21 18:50:13 | Current users after setting applied:
2026-04-21 18:50:13 |   Users:
2026-04-21 18:50:13 |           UserInfo{0:Ian Perdiansah:4c13} running
2026-04-21 18:50:13 |           UserInfo{10:security space:413}
2026-04-21 18:50:13 | Done ✓
```

## ⚙️ Versi yang Didukung

- **Magisk** v20.4+
- **Android** 10+ (API 29+)
- Tested pada Xiaomi Pad 5 (nabu)

## 📝 Lisensi

MIT License — bebas digunakan dan dimodifikasi.

## Info

- Created by Claude AI
