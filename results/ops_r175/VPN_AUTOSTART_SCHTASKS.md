--- task t132: Green VPN schtasks ASCII autostart ---
target=E:\NsfocusVPN\NsfocusVPN.exe
helper_written=E:\NsfocusVPN\git-sync-start-green-vpn.cmd
startup_cmd=C:\Users\??\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\GreenVPN-Autostart.cmd exists=True
schtasks_create_exit=1 out=schtasks.exe : ??: ??????????? E:\0github\git-sync\git-pull-arena-01a0fa39\code\tasks\t132_vpn_schtasks_ascii.ps1:57 ??: 13??+     $out = (& schtasks /Create /TN $taskName /SC ONLOGON /TR $helper  ...??+             ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~??    + CategoryInfo          : NotSpecified: (??: ?????:String) [], RemoteException??    + FullyQualifiedErrorId : NativeCommandError
schtasks_query_exit=1
   query| +     $q = (& schtasks /Query /TN $taskName /FO LIST /V 2>&1 | Out-Stri ...
GetScheduledTask_WARN=??????TaskName??????git-sync-autostart-green-vpn?? MSFT_ScheduledTask ???????????????
FINAL: VPN_SCHTASKS_PARTIAL createOk=False queryOk=False
