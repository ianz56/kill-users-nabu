#!/system/bin/sh
# Kill Users on Switch — Action Button
# ======================================
# This script runs when you tap the "Action" button in Magisk Manager.
# It stops all users except the primary user (user 0).

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Kill Users on Switch — Action"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

REFRESH_RATE=60
CURRENT_USER=$(am get-current-user 2>/dev/null)

# Ensure stop-on-switch is enabled
RESULT=$(am set-stop-user-on-switch true 2>&1)
echo "[*] am set-stop-user-on-switch true"
echo "    -> $RESULT"
echo ""

if [ -n "$CURRENT_USER" ]; then
  settings --user "$CURRENT_USER" put system peak_refresh_rate "${REFRESH_RATE}.0" >/dev/null 2>&1
  settings --user "$CURRENT_USER" put system min_refresh_rate "${REFRESH_RATE}.0" >/dev/null 2>&1
  settings --user "$CURRENT_USER" put system user_refresh_rate "$REFRESH_RATE" >/dev/null 2>&1
  settings --user "$CURRENT_USER" put system miui_refresh_rate "$REFRESH_RATE" >/dev/null 2>&1

  echo "[*] Lock refresh rate ke ${REFRESH_RATE}Hz untuk user $CURRENT_USER"
  echo "    -> peak=$(settings --user "$CURRENT_USER" get system peak_refresh_rate 2>/dev/null), min=$(settings --user "$CURRENT_USER" get system min_refresh_rate 2>/dev/null)"
  echo ""
fi

# Get list of running user IDs (exclude user 0)
echo "[*] Scanning for running background users..."
echo ""

KILLED=0

# Parse 'pm list users' output to find running users
# Format: UserInfo{ID:Name:flags} running
pm list users 2>/dev/null | while IFS= read -r line; do
  # Skip lines that don't contain UserInfo
  case "$line" in
    *UserInfo*) ;;
    *) continue ;;
  esac

  # Extract user ID
  USER_ID=$(echo "$line" | sed -n 's/.*UserInfo{\([0-9]*\):.*/\1/p')

  # Skip if we couldn't parse the ID or if it's user 0
  [ -z "$USER_ID" ] && continue
  [ "$USER_ID" = "0" ] && continue

  # Check if this user is running
  case "$line" in
    *running*)
      echo "    User $USER_ID is running — stopping..."
      STOP_RESULT=$(am stop-user $USER_ID 2>&1)
      echo "    -> $STOP_RESULT"
      KILLED=$((KILLED + 1))
      ;;
    *)
      echo "    User $USER_ID is already stopped"
      ;;
  esac
done

echo ""
echo "[*] Current user status:"
pm list users 2>/dev/null | while IFS= read -r line; do
  echo "    $line"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Done!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
