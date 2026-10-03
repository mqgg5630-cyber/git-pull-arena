# Google Drive + computer-use setup r249
time=2026-10-03 20:24:52 +08:00
host=LAPTOP-R77M5D6M

## Google Drive rclone setup
remote=gdrive_jzthjyz:
account_hint=jzthjyz@gmail.com
scope=drive
probe_write_allowed=True
oauth_instruction_note=D:\??\[REDACTED].txt
setup| rclone_existing=C:\Users\??\AppData\Local\Programs\rclone\rclone.exe
setup| rclone=C:\Users\??\AppData\Local\Programs\rclone\rclone.exe
setup| rclone_version| rclone v1.75.1
setup| rclone_version| - os/version: Microsoft Windows 11 Pro 25H2 25H2 (64 bit)
setup| rclone_version| - os/kernel: 10.0.26200.8875 (x86_64)
setup| rclone_version| - os/type: windows
setup| [REDACTED]
setup| account_hint=jzthjyz@gmail.com
setup| [REDACTED]
setup| powershell.exe : 2026/10/03 20:24:57 NOTICE: Make sure your Redirect URL is set to "http://127.0.0.1:53682/" in your cu
setup| stom config.
setup| ???? ?:1 ??: 2
setup| +  & $using:psExe -NoProfile -ExecutionPolicy Bypass -File $using:setup ...
setup| +  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
setup|     + CategoryInfo          : NotSpecified: (2026/10/03 20:2... custom config.:String) [], RemoteException
setup|     + FullyQualifiedErrorId : NativeCommandError
setup| 2026/10/03 20:24:57 NOTICE: If your browser doesn't open automatically go to the following link: http://127.0.0.1:53682
setup| /auth?[REDACTED]
setup| 2026/10/03 20:24:57 NOTICE: Log in and authorize rclone for access
setup| 2026/10/03 20:24:57 NOTICE: Waiting for code...
setup| 2026/10/03 20:28:34 NOTICE: Got code
setup| [gdrive_jzthjyz]
setup| type = drive
setup| scope = drive
setup| client_id = 
setup| client_secret = 
setup| token = {"access_token":"[REDACTED-OAUTH]","token_type":"Bearer","refresh_token":"[REDACTED-OAUTH]","expiry":"2026-10-03T21:28:34.1588922+08:00","expires_in":3599}
setup| team_drive = 
setup| oauth_reconnect_start=True
setup| If a browser opens, sign in locally and approve. Do not paste tokens into chat.
setup| 2026/10/03 20:28:35 NOTICE: Make sure your Redirect URL is set to "http://127.0.0.1:53682/" in your custom config.
setup| 2026/10/03 20:28:35 NOTICE: If your browser doesn't open automatically go to the following link: http://127.0.0.1:53682
setup| /auth?[REDACTED]
setup| 2026/10/03 20:28:35 NOTICE: Log in and authorize rclone for access
setup| 2026/10/03 20:28:35 NOTICE: Waiting for code...
setup| 2026/10/03 20:28:43 NOTICE: Got code
setup| verify_about_start=True
setup| 2026/10/03 20:28:44 NOTICE: gdrive_jzthjyz: This remote uses rclone's shared Google Drive client_id, which is being ret
setup| ired and will stop working during 2026. Create your own client_id to avoid interruption: https://rclone.org/drive/#maki
setup| ng-your-own-client-id
setup| Total:   5 TiB
setup| Used:    983.909 MiB
setup| Free:    4.999 TiB
setup| Trashed: 0 B
setup| Other:   48.688 MiB
setup| GDRIVE_RCLONE_READY=True
setup| remote=gdrive_jzthjyz:
health| # Cloud interop health report
health| time=2026-10-03 20:28:49 +08:00
health| host=LAPTOP-R77M5D6M
health| ## Git
health| [REDACTED]
health| head=355b5bd check: request round 251 (awaiting local check)
health| ## Google Drive / rclone
health| rclone_present=True path=C:\Users\??\AppData\Local\Programs\rclone\rclone.exe
health| [REDACTED]: present=False
health| ## Kaggle
health| kaggle_cli=False
health| kaggle_json=False path=C:\Users\??\.kaggle\kaggle.json
health| ## Tailscale / machines
health| tailscale_cli=True path=E:\Tailscale\tailscale.exe
health| [REDACTED]
health| ## Muse protocol
health| muse_protocol_present=True
health| muse_poller_present=True
health| muse_smoke_state=done
health| [REDACTED].zip
health| CLOUD_INTEROP_HEALTH_DONE
GDRIVE_RCLONE_READY=True
GDRIVE_PROBE_WRITE_OK=False

computer_use_report=E:\0github\git-sync\git-pull-arena-01a0ff69\results\computer_use\COMPUTER_USE_LAPTOP_R249.md
computer_use_json=E:\0github\git-sync\git-pull-arena-01a0ff69\results\computer_use\COMPUTER_USE_LAPTOP_R249.json
COMPUTER_USE_LAPTOP_OK=True
GDRIVE_SETUP_OK=False
