--- task t151: desktop stable verify + GreenVPN autostart ---
--- A: GreenVPN autostart verify/install ---
greenvpn_task_OK=GreenVPN-Autostart
greenvpn_exe_exists=True path=E:\NsfocusVPN\NsfocusVPN.exe
greenvpn_startup_cmd_exists=True
greenvpn_launcher_ps1_exists=True
greenvpn_desktop_launcher_exists=True
greenvpn_process_count_now=4
greenvpn_log_tail=2026-10-02 13:08:53 launcher start
greenvpn_log_tail=2026-10-02 13:08:53 delay 45s
greenvpn_log_tail=2026-10-02 13:09:38 kill-before enabled
greenvpn_log_tail=2026-10-02 13:09:43 start E:\NsfocusVPN\NsfocusVPN.exe
greenvpn_log_tail=2026-10-02 13:09:49 second-kick wait 120s
greenvpn_log_tail=2026-10-02 13:11:49 second-kick: process exists; leave it running (no blind kill)
greenvpn_log_tail=2026-10-02 13:11:49 launcher done
FINAL_GREENVPN_AUTOSTART: INSTALLED_STARTUP_AND_SCHEDULED_TASK
--- B: desktop Antigravity bridge stable verify ---
desktop_verifier_staged=OK
desktop_stable| # Desktop Antigravity bridge stable verify
desktop_stable| time=2026-10-02 13:12:30
desktop_stable| [REDACTED] user=bni
desktop_stable| [REDACTED]
desktop_stable| [REDACTED].15.1.0
desktop_stable| [REDACTED]
desktop_stable| [REDACTED]
desktop_stable| [REDACTED]:\Users\BNI\AppData\Roaming\Antigravity\User\settings.json -> True
desktop_stable| [REDACTED]:\Users\BNI\AppData\Roaming\Antigravity IDE\User\settings.json -> True
desktop_stable| [REDACTED]
desktop_stable| [REDACTED]: NOT_STABLE
desktop_stable| # Desktop Antigravity bridge stable verify
desktop_stable| time=2026-10-02 13:12:30
desktop_stable| [REDACTED] user=bni
desktop_stable| [REDACTED]
desktop_stable| [REDACTED].15.1.0
desktop_stable| [REDACTED]
desktop_stable| [REDACTED]
desktop_stable| [REDACTED]:\Users\BNI\AppData\Roaming\Antigravity\User\settings.json -> True
desktop_stable| [REDACTED]:\Users\BNI\AppData\Roaming\Antigravity IDE\User\settings.json -> True
desktop_stable| [REDACTED]
desktop_stable| [REDACTED]: NOT_STABLE
collected=antigravity_bridge_desktop_stable_r194.md
