# 📚 DOKUMENTASI LENGKAP PROYEK: NABU CN SYSTEM & FAMILY LINK HELPER

**Nama Perangkat:** Xiaomi Pad 5 (Codename: `nabu`)  
**Versi ROM:** Xiaomi HyperOS / MIUI China ROM (`WNSCNXM`, Android 14 / SDK 34)  
**Versi Modul Terakhir:** `v1.0.30` (VersionCode: `31`)  
**Repository GitHub:** `https://github.com/ianz56/nabu-cn-familylink-helper.git`  
**Lokasi Kode Lokal:** `C:\Users\ianpe\kill-users-nabu`  

---

## 🎯 1. LATAR BELAKANG & TUJUAN UTAMA PROYEK

Tablet Xiaomi Pad 5 menjalankan ROM China yang memiliki banyak pembatasan sistem bawaan (*Chinese ROM Restrictions*). Proyek ini dibuat sebagai **Modul Magisk All-in-One** untuk menyelesaikan masalah-masalah utama berikut:

1. **Multi-User Management & Auto-Kill**:
   - Di Android multi-user (User 0 = Orang Tua, User 11 = Anak), user di latar belakang yang tidak aktif memakan RAM & baterai secara agresif.
   - Diperlukan fitur **Stop-User-on-Switch** otomatis agar saat berpindah user (misal ke User 0), User 11 langsung dimatikan total (*killed*).
   - Diperlukan fitur **Auto-Switch ke User 0 saat Layar Mati** (*Screen Off*) demi keamanan dan menghemat baterai.

2. **Dukungan Penuh Google Play Services (GMS) & GSF di ROM China**:
   - ROM China membatasi fitur GMS, GSF ID, dan Google Advertising ID (AAID).
   - Perbaikan masalah sertifikasi Play Protect, Google Checkin, dan penghindaran konflik update GMS.

3. **Family Link & Supervision Sebagai Aplikasi Sistem Privilese (*Privileged System Apps*)**:
   - Memasukkan `FamilyLink`, `FamilyLinkHelper`, dan `Supervision` ke dalam `/system/product/priv-app/` dengan `privapp-permissions.xml` dan `default-permissions.xml` lengkap.
   - Mengaktifkan izin hak akses sistem `OBSERVE_APP_USAGE`, `CHANGE_APP_IDLE_STATE`, `PACKAGE_USAGE_STATS`, `SYSTEM_ALERT_WINDOW`, `USE_FULL_SCREEN_INTENT` (AppOps 133), dan `SCHEDULE_EXACT_ALARM` agar pemantauan batas waktu layar (*screen time*) dan *auto-lock* Family Link berfungsi 100% tanpa stuck di 0 menit.
   - Mempertahankan agar Play Store tetap bebas meng-update aplikasi Family Link/Supervision tanpa menghapus status privilese sistem.

4. **Pengunci Refresh-Rate & Bahasa Space Anak**:
   - Mengunci *refresh rate* layar secara permanen di 60Hz.
   - Mengatur preferensi Bahasa Indonesia (`id-ID`) untuk Space Anak (User 11).

5. **Play Integrity Spoofing (`MEETS_DEVICE_INTEGRITY`)**:
   - Menyamarkan properti Bootloader Unlocked (`verifiedbootstate=green`, `flash.locked=1`) agar lulus `MEETS_DEVICE_INTEGRITY`.

---

## 🛠️ 2. ARSITEKTUR & FILE UTAMA MODUL MAGISK

Semua file modul tersimpan di `C:\Users\ianpe\kill-users-nabu`:

| Nama File / Folder | Fungsi & Rincian Deskripsi |
| :--- | :--- |
| **`module.prop`** | Metadata modul Magisk (`id=nabu-cn-familylink-helper`, `version=v1.0.30`, `versionCode=31`). |
| **`service.sh`** | Skrip utama *late-start service* yang berjalan setiap booting. Menjalankan `am set-stop-user-on-switch true`, memberikan izin *root pm grant* & *AppOps*, mengeksekusi `resetprop` Play Integrity, dan mengaktifkan DroidGuard/GMS. |
| **`auto_switch.sh`** | Skrip latar belakang daemon yang memantau status layar & pergantian user. Berjalan saat beralih user untuk memastikan izin Family Link, AppOps, dan pengunci 60Hz tetap aktif di User 0 dan User 11. |
| **`system.prop`** | Properti sistem yang diinjeksi saat booting: memperbolehkan GMS (`ro.miui.support_gms=1`), Google ClientID (`android-google`), Ad ID (`ro.com.google.gms.ad_id=1`), dan Play Integrity Spoofing (`ro.boot.verifiedbootstate=green`, `ro.boot.flash.locked=1`). |
| **`customize.sh`** | Skrip instalasi Magisk yang berjalan saat modul di-flash di Magisk Manager. |
| **`build.py`** | Skrip Python builder untuk mengonversi newline LF (`\n`) otomatis pada skrip `.sh` dan memaketkan ZIP rilis (`nabu-cn-familylink-helper-v1.0.30.zip`). |
| **`system/product/priv-app/`** | Berisi APK sistem bawaan modul: `FamilyLink`, `FamilyLinkHelper`, `Supervision`, `Phonesky` (Play Store), `GooglePackageInstaller`. |
| **`system/product/etc/permissions/`** | XML Izin Privilese: `privapp-permissions-familylink.xml`, `privapp-permissions-supervision.xml`, `cn.google.services.xml`. |
| **`system/product/etc/default-permissions/`** | `default-permissions-familylink.xml` untuk memberikan izin default secara otomatis. |

---

## 📜 3. RIWAYAT PERJALANAN & EVOLUSI PERBAIKAN (V1.0.19 - V1.0.30)

Berikut ringkasan kronologis perbaikan dari awal hingga versi terbaru:

### 🔹 v1.0.19 - v1.0.22 (Pemberian Izin Sistem & Penanganan Update Play Store)
- **Family Link Screen Time Stuck 0**: Mengidentifikasi bahwa saat Play Store meng-update Supervision/Family Link ke `/data/app/`, izin privilese `OBSERVE_APP_USAGE` terlepas. Menambahkan `privapp-permissions-familylink.xml` dan otomatisasi `pm grant` di `service.sh` & `auto_switch.sh`.
- **Mempertahankan Auto-Update**: Menghapus pembersihan otomatis folder `/data/app/` Family Link agar aplikasi dapat terus diperbarui oleh Play Store tanpa merusak pemantauan layar.
- **Google Advertising ID (AAID) Fix**: Menambahkan fitur `AD_ID` ke `cn.google.services.xml` dan membuat otomatisasi file `ad_id.xml` di shared_prefs GMS.

### 🔹 v1.0.23 - v1.0.26 (Eksperimen GSF, Penanganan GMS Preview, & Revert `gservices.db`)
- **Penyebab GMS Rusak/Hilang**: Ditemukan bahwa Play Store sempat mengunduh update `com.google.android.gms` versi Preview Beta Android 16 (`versionCode=262931035`, `minSdk=35`). Karena tablet menggunakan Android 14, GMS mengalami *crash* & hilang.
- **Eksperimen `gservices.db` & Pemulihan (`v1.0.26`)**: Pembuatan file `gservices.db` tiruan manual sempat menyebabkan `IOException` saat login Google. Pembuatan database buatan tersebut telah **dihapus total di v1.0.26**, mengembalikan autentikasi GSF murni.
- **Stabilisasi GMS**: Menghapus skrip pembersih yang menyebabkan loop penghapusan GMS, memulihkan GMS stabil bawaan sistem (`PrebuiltGmsCoreVic.apk`, `v253434035`) secara permanen di User 0 dan User 11.

### 🔹 v1.0.27 - v1.0.29 (Izin Lanjutan & Fitur Layar Penuh)
- **Stabilisasi GMS Permanen (`v1.0.27`)**: Memastikan GMS tidak pernah terhapus lagi saat booting.
- **Izin `WRITE_SETTINGS` (`v1.0.28`)**: Mengaktifkan izin `android.permission.WRITE_SETTINGS` dan AppOps-nya untuk GMS di semua user.
- **Izin `USE_FULL_SCREEN_INTENT` & `SCHEDULE_EXACT_ALARM` (`v1.0.29`)**: Memberikan izin `USE_FULL_SCREEN_INTENT` (AppOps 133) dan `SCHEDULE_EXACT_ALARM` untuk Supervision, Family Link, dan GMS agar popup penguncian layar penuh dan alarm batas waktu tepat waktu.

### 🔹 v1.0.30 (Play Integrity `MEETS_DEVICE_INTEGRITY` Spoofing)
- **Spoofing Status Bootloader**: Menambahkan properti penyamaran bootloader (`ro.boot.verifiedbootstate=green`, `ro.boot.flash.locked=1`, `ro.boot.veritymode=enforcing`, dll.) via `system.prop` dan `resetprop` di `service.sh` untuk meningkatkan Play Integrity dari *Basic* ke **`MEETS_DEVICE_INTEGRITY`**.

---

## 🔑 4. STATUS FITUR SAAT INI (VERIFIKASI TERAKHIR)

| Fitur | Status | Catatan Teknis |
| :--- | :---: | :--- |
| **Stop User On Switch** | ✅ AKTIF | `am set-stop-user-on-switch true` berjalan otomatis di booting. User 11 langsung mati saat pindah ke User 0. |
| **Auto Switch Screen Off** | ✅ AKTIF | Pindah otomatis ke User 0 saat layar dimatikan (*screen off*). |
| **Google Advertising ID (AAID)** | ✅ AKTIF | Berjalan normal (menampilkan ID Iklan aktif, tidak lagi `00000...`). |
| **GMS Core & Play Store** | ✅ AKTIF | Berjalan di versi stabil (`v253434035`). Opsi login Google & Play Store normal tanpa `IOException`. |
| **Family Link & Supervision** | ✅ AKTIF | Izin `OBSERVE_APP_USAGE`, `PACKAGE_USAGE_STATS`, `SYSTEM_ALERT_WINDOW`, `USE_FULL_SCREEN_INTENT`, `SCHEDULE_EXACT_ALARM` aktif. Fitur *screen time* & *auto-lock* berjalan normal. |
| **Bahasa Space Anak (User 11)** | ✅ AKTIF | Konfigurasi sistem User 11 diatur ke Bahasa Indonesia (`id-ID`). |
| **Refresh Rate Lock** | ✅ AKTIF | Terkunci di 60Hz. |
| **Play Integrity** | ✅ AKTIF | Properti `green` & `locked` disuntikkan via `resetprop` di `service.sh` untuk mengejar `MEETS_DEVICE_INTEGRITY`. |

---

## 🚀 5. PANDUAN PENGEMBANGAN / KELANJUTAN (UNTUK CHAT BARU)

Jika Anda memulai perbincangan di **Chat Baru (New Conversation)**, berikan petunjuk singkat berikut ke AI:

> *"Saya ingin melanjutkan pengembangan modul Magisk `nabu-cn-familylink-helper` (terakhir v1.0.30) di `C:\Users\ianpe\kill-users-nabu`. Silakan baca file dokumentasi proyek di `README.md` / `PROJECT_DOCUMENTATION.md` untuk memahami seluruh arsitektur dan status terakhir."*

### Perintah Penting untuk Build & Flash:
1. **Build Modul Baru**:
   ```powershell
   cd C:\Users\ianpe\kill-users-nabu
   python build.py
   ```
2. **Flash Modul ke Tablet via ADB**:
   ```powershell
   adb push nabu-cn-familylink-helper-v1.0.30.zip /data/local/tmp/
   adb shell "su -c 'magisk --install-module /data/local/tmp/nabu-cn-familylink-helper-v1.0.30.zip'"
   ```
3. **Push ke GitHub**:
   ```powershell
   git add .
   git commit -m "Pesan commit"
   git pull --rebase
   git push origin main
   ```
