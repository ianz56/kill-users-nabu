#!/system/bin/sh
# Kill Users on Switch — Installation Script
# =============================================
# This runs during module installation via Magisk Manager / recovery.

# Print banner
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print "  Kill Users on Switch"
ui_print "  v1.0.0 by Ian Perdiansah"
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print ""
ui_print "  This module will automatically run:"
ui_print "  am set-stop-user-on-switch true"
ui_print "  on every boot."
ui_print ""
ui_print "  Background users will be stopped"
ui_print "  when you switch to another user."
ui_print ""
ui_print "  Action button in Magisk Manager:"
ui_print "  Instantly kill all background users."
ui_print ""

# Set proper permissions for scripts
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755

ui_print "  ✓ Installation complete!"
ui_print "  ✓ Reboot to activate."
ui_print ""
