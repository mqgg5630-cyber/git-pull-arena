# R326 restore-point / backup census (read-only, non-elevated)
time=2026-10-06 23:07:29
get_computerrestorepoint rc=1 out=Get-ComputerRestorePoint : ????  | ???? ?:1 ??: 1 | + Get-ComputerRestorePoint -ErrorAction Continue | Select-Object Sequen ... | + ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ |     + CategoryInfo          : InvalidOperation: (:) [Get-ComputerRestorePoint]?ManagementException |     + FullyQualifiedErrorId : GetWMIMa
wmi_systemrestore rc=1 out=Get-CimInstance : ????  | ???? ?:1 ??: 1 | + Get-CimInstance -Namespace root/default -ClassName SystemRestore -Err ... | + ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ |     + CategoryInfo          : PermissionDenied: (root/default:SystemRestore:String) [Get-CimInstance], CimException |     + F
wmi_systemrestoreconfig rc=0 out=DiskPercent       : 15 | MyKey             : SR | RPGlobalInterval  :  | RPLifeInterval    :  | RPSessionInterval : 0 | PSComputerName    :
vssadmin rc=2 out=vssadmin 1.1 - ????????????? | (C) ???? 2001-2013 Microsoft Corp. |  | ??:  ???????????????????????????????? | ??????????
reg SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore: RPSessionInterval=0; SRInitDone=1; LastMainenanceTaskRunTimeStamp=134356087989546138
reg SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore: FileNotFoundError(2, '???????????', None, 2, None)
fhsvc rc=0 out=Status    : Stopped | StartType : Manual
filehistory_config_exists=False
wbengine rc=0 out=Status    : Stopped | StartType : Manual
disks: C:               3 107374178304  40474165248 | D:               3 147346944000  54360027136 | E:               3 768147976192 303521746944
R326_RESTORE_CENSUS_COMPLETE=True
