--- task t154: windows-computer-use actual GUI smoke ---
time=2026-10-02 13:30:40
computer=LAPTOP-R77M5D6M user=文少
lab_root=C:\Users\??\[REDACTED]
collected=optimization_plan_r196.md
collected=windows-computer-use-verify_r196.txt
collected=source_inventory_r196.md
wcu_backend_exists=True
wcu_server_exists=True
sample_config_written=C:\Users\??\[REDACTED]\configs\[REDACTED].json
wcu_health_ok=True platform=Windows screenshot=True
notepad_started_pid=23508
wcu_activate_ok=False
wcu_type_ok=True length=29
wcu_save_ok=True
wcu_close_ok=True
notepad_force_closed=True
wcu_notepad_file=C:\Users\??\[REDACTED]\smoke\wcu_notepad_smoke.txt
wcu_notepad_marker_present=True typed_present=False
RUN_START=direct_notepad_gui_smoke_fixed
RUN_OUT|direct_notepad_gui_smoke_fixed| {"app":"notepad","appactivate":true,"file":"C:\\Users\\??\\[REDACTED]\\smoke\\notepad_gui_smoke.txt","marker_present":true,"typed_present":false}
direct_notepad_appactivate=True marker_present=True typed_present=False
RUN_START=pywinauto_notepad_smoke2
RUN_OUT|pywinauto_notepad_smoke2| {"pywinauto_available": true, "started": true, "typed_present": false, "file": "C:\\Users\\??\\[REDACTED]\\smoke\\[REDACTED].txt"}
pywinauto2_result={"pywinauto_available": true, "started": true, "typed_present": false, "file": "C:\\Users\\??\\[REDACTED]\\smoke\\[REDACTED].txt"}
FINAL_COMPUTER_USE_SMOKE: PARTIAL_CHECK_REPORT
