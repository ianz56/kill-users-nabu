# Kill Users on Switch — Magisk Module

Modul Magisk untuk Xiaomi Pad 5 / nabu yang otomatis menjalankan `am set-stop-user-on-switch true` setiap boot, menghentikan user lama saat berpindah user, dan memaksa refresh rate tetap **60Hz** agar tidak mudah balik ke mode dinamis/120Hz setelah user switch.

## 🎯 Masalah yang Diselesaikan

Di Android multi-user, secara default user lama bisa tetap **running** di background meskipun kamu sudah pindah ke user lain. Ini bisa memakan RAM dan baterai, terutama kalau user lain masih membuka game.

Solusinya adalah menjalankan:

```sh
am set-stop-user-on-switch true
```

**Tapi** setting ini reset setiap reboot, sehingga harus dijalankan manual lagi. Modul ini mengotomasi hal tersebut.

## 🐞 Catatan Bug Refresh Rate Xiaomi Pad 5

Pada Xiaomi Pad 5 / nabu, refresh-rate lock lewat `settings put system peak_refresh_rate 60.0` saja kadang tidak cukup. Setelah pindah user, display state MIUI/HyperOS bisa tetap nyangkut ke mode dinamis/120Hz dan efeknya bisa terasa di semua user sampai reboot.

Mulai `v1.0.1`, modul ini memperkuat refresh-rate lock dengan cara:

- Apply refresh lock ke **semua user** saat daemon mulai
- Re-apply refresh lock setiap foreground user berubah
- Re-apply refresh lock berkala selama daemon hidup
- Menulis key refresh rate ke `system`, `secure`, dan `global`
- Best-effort poke ke DisplayManager memakai mode native Xiaomi Pad 5 `1600x2560@60`

Kalau command DisplayManager tidak tersedia di ROM kamu, modul tetap jalan karena command tersebut dibuat silent-fail.

## 📦 Cara Install

### Metode 1: Flash via Magisk Manager

1. Download file `kill-users-on-switch-v1.0.1.zip` dari [Releases](../../releases)
2. Buka **Magisk Manager** → **Modules** → **Install from storage**
3. Pilih file ZIP-nya
4. Reboot

### Metode 2: Build sendiri

1. Clone repo ini
2. Jalankan di terminal:
   ```sh
   cd kill-users-nabu
   zip -r kill-users-on-switch-v1.0.1.zip . -x ".git/*" "README.md" "build.ps1"
   ```
   Atau di Windows PowerShell:
   ```powershell
   .\build.ps1
   ```
3. Flash file ZIP yang dihasilkan via Magisk Manager

## 🚀 Build Otomatis & Release

Repo ini punya GitHub Actions workflow di `.github/workflows/build-release.yml`.

Workflow akan:

- Membaca `id`, `name`, `version`, dan `versionCode` dari `module.prop`
- Membuat ZIP dengan format `kill-users-on-switch-v1.0.1.zip`
- Upload ZIP sebagai artifact di tab **Actions**
- Membuat atau memperbarui **GitHub Release** kalau workflow dijalankan dari tag `v*` atau manual dengan opsi release aktif

### Rilis via tag

```sh
git tag v1.0.1
git push origin v1.0.1
```

Setelah tag dipush, GitHub Actions akan build ZIP dan membuat release otomatis.

### Rilis manual dari GitHub

1. Buka tab **Actions**
2. Pilih workflow **Build and Release Magisk Module**
3. Klik **Run workflow**
4. Set `release` ke `true`
5. Isi `tag` jika mau custom, atau kosongkan untuk memakai versi dari `module.prop`

Kalau `release=false`, workflow hanya build ZIP dan menyimpannya sebagai artifact tanpa membuat release.

## 📁 Struktur Modul

```text
kill-users-nabu/
├── META-INF/
│   └── com/google/android/
│       ├── update-binary      # Magisk installer bootstrap
│       └── updater-script     # Magisk module marker
├── module.prop                # Metadata modul (nama, versi, dll)
├── service.sh                 # Script utama — jalan saat boot
├── action.sh                  # Tombol Action di Magisk Manager
├── auto_switch.sh             # Daemon auto-switch ke user 0 + refresh lock
├── customize.sh               # Script instalasi — tampil saat flash
├── build.ps1                  # Build script (Windows)
└── README.md                  # File ini
```

## 🔍 Cara Kerja

### Otomatis saat Boot (`service.sh`)

1. **Boot** → Magisk menjalankan `service.sh` pada trigger `late_start`
2. **Tunggu boot selesai** → Script menunggu `sys.boot_completed == 1` (max 120 detik)
3. **Apply setting** → Menjalankan `am set-stop-user-on-switch true`
4. **Launch daemon** → Menjalankan `auto_switch.sh` di background untuk monitor user aktif + enforce 60Hz
5. **Log** → Semua aktivitas dicatat di `/data/adb/modules/kill-users-on-switch/service.log`

### Auto-Switch Daemon (`auto_switch.sh`)

Daemon background yang mencegah boros baterai & RAM kalau kamu lupa switch balik ke user utama, sekaligus re-apply refresh rate 60Hz supaya tidak kembali ke mode dinamis/120Hz setelah user switch.

Cara kerjanya:

- Saat daemon mulai → paksa refresh rate semua user ke `60Hz`
- Setiap 10 detik → cek status layar dan user aktif
- Kalau foreground user berubah → paksa refresh rate user aktif ke `60Hz`
- Setiap 60 detik → re-apply refresh rate untuk user aktif
- Kalau **layar mati** + kamu di **user selain 0** → mulai hitung mundur **10 menit**
- Kalau **10 menit berlalu** → otomatis `am switch-user 0` (user secondary auto-stop karena `stop-on-switch`)
- Kalau **layar nyala** sebelum timeout → timer di-reset, tidak jadi switch

Refresh-rate keys yang ditulis:

```sh
settings --user <id> put system peak_refresh_rate 60.0
settings --user <id> put system min_refresh_rate 60.0
settings --user <id> put system user_refresh_rate 60
settings --user <id> put system miui_refresh_rate 60
settings --user <id> put secure user_refresh_rate 60
settings put global peak_refresh_rate 60.0
settings put global min_refresh_rate 60.0
settings put global user_refresh_rate 60
settings put global miui_refresh_rate 60
cmd display set-user-preferred-display-mode 1600 2560 60
```

Timeout bisa diubah di `auto_switch.sh` variabel `TIMEOUT` (default: 600 detik = 10 menit).

Re-apply interval bisa diubah di `auto_switch.sh` variabel `REFRESH_REAPPLY_INTERVAL` (default: 60 detik).

### Tombol Action di Magisk Manager (`action.sh`)

Buka **Magisk Manager** → **Modules** → klik ikon ⚙️ **Action** pada modul ini.

Fungsinya:

- Re-enable `am set-stop-user-on-switch true`
- Re-apply refresh rate 60Hz untuk semua user
- Menulis refresh-rate lock ke `system`, `secure`, dan `global`
- Best-effort poke DisplayManager ke `1600x2560@60`
- **Kill (stop) semua user** selain user utama (user 0)
- Menampilkan status user sebelum dan sesudah

Berguna kalau kamu mau kill user background secara manual tanpa harus buka terminal.

## 📋 Cek Log

Untuk melihat apakah modul berjalan dengan benar setelah reboot:

```sh
# Log boot & setting
cat /data/adb/modules/kill-users-on-switch/service.log

# Log auto-switch daemon
cat /data/adb/modules/kill-users-on-switch/auto_switch.log
```

Contoh output service.log:

```text
2026-04-21 18:50:00 | Module started, waiting for boot to complete...
2026-04-21 18:50:10 | Boot completed after ~10s — applying setting...
2026-04-21 18:50:10 | am set-stop-user-on-switch true → Set to true
2026-04-21 18:50:13 | Current users after setting applied:
2026-04-21 18:50:13 |   Users:
2026-04-21 18:50:13 |           UserInfo{0:Ian Perdiansah:4c13} running
2026-04-21 18:50:13 |           UserInfo{10:security space:413}
2026-04-21 18:50:13 | Done ✓
2026-04-21 18:50:13 | Starting auto-switch daemon...
2026-04-21 18:50:13 | Auto-switch daemon launched (PID: 1234)
```

Contoh output auto_switch.log:

```text
2026-04-21 19:00:00 | Auto-switch daemon started (refresh=60Hz, timeout=600s, poll=10s, reapply=60s)
2026-04-21 19:00:00 | Applying refresh lock for all users...
2026-04-21 19:00:01 | Refresh lock applied for user 0 (peak=60.0, min=60.0, user=60, miui=60, secure_user=60, global_peak=60.0)
2026-04-21 19:00:02 | Refresh lock applied for user 10 (peak=60.0, min=60.0, user=60, miui=60, secure_user=60, global_peak=60.0)
2026-04-21 20:15:30 | Screen off on user 10 — timer started (600s)
2026-04-21 20:25:30 | Timeout reached (600s) — switching to user 0...
2026-04-21 20:25:31 | am switch-user 0 → Success
2026-04-21 20:25:36 | Current user is now: 0
```

## ⚙️ Versi yang Didukung

- **Magisk** v20.4+
- **Android** 10+ (API 29+)
- Tested pada Xiaomi Pad 5 (nabu)

## 📝 Lisensi

MIT License — bebas digunakan dan dimodifikasi.

## Info

- Created by Claude AI
