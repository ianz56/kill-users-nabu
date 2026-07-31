# Nabu CN System & Family Link Helper

Magisk module for Xiaomi Pad 5 (nabu) running MIUI / HyperOS China ROMs. This module resolves Google Family Link onboarding and downtime overlay crashes, enables GSF/GMS compatibility, manages background secondary users, and locks refresh-rate settings.

## Features

1. **Family Link & GMS Supervision System Integration**:
   - Packages `com.google.android.apps.kids.familylink`, `com.google.android.apps.kids.familylinkhelper`, and `com.google.android.gms.supervision` as system-privileged apps (`/system/product/priv-app/`).
   - Resolves multi-pane settings deep link crashes (`LAUNCH_MULTI_PANE_SETTINGS_DEEP_LINK`).
   - Fixes Family Link Helper force close (FC) and unblocks Google account onboarding ("Getting next steps...") in Second Space (User 11).

2. **System Default-Permissions & AppOps Enforcement Daemon**:
   - Provides `/system/product/etc/default-permissions/default-permissions-familylink.xml` with `fixed="true"` to lock all runtime permissions for Family Link apps across all users.
   - Includes a background daemon that periodically enforces `SYSTEM_ALERT_WINDOW` (display over other apps), `GET_USAGE_STATS`, `USE_FULL_SCREEN_INTENT`, and MIUI Autostart (`10008`) to ensure Downtime lock overlays work reliably.

3. **MIUI CN GSF / GMS Bypass**:
   - Creates a dummy `/system/product/priv-app/GmsCore` path to bypass MIUI China ROM's GSF package hiding logic.

4. **Multi-User Background Management**:
   - Automatically executes `am set-stop-user-on-switch true` so background secondary users are killed upon user switch.
   - Auto-switches back to User 0 if a secondary user remains inactive while the screen is off.

5. **Refresh Rate Management**:
   - Enforces a 60Hz display refresh lock across all users.

## Installation

1. Build or download `nabu-cn-familylink-helper-v1.0.8.zip`.
2. Flash the ZIP file via Magisk Manager or KernelSU.
3. Reboot your device.

## Author

Created & maintained by **Ian Perdiansah**.
