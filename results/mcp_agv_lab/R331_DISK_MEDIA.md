# R331 disk media type + process check
time=2026-10-06 23:39:08
-- Get-PhysicalDisk rc=0
  pd| DeviceId Model                    MediaType BusType SizeGB
  pd| -------- -----                    --------- ------- ------
  pd| 0        BIWINTECH WookongM.2 1TB SSD       NVMe       954
-- Win32_DiskDrive rc=0
  dd| Model                    Index SizeGB InterfaceType
  dd| -----                    ----- ------ -------------
  dd| BIWINTECH WookongM.2 1TB     0    954 SCSI         
-- letter->partition map rc=0
  map| Antecedent : Win32_DiskPartition (DeviceID = "Disk #0, Partition #1")
  map| Dependent  : Win32_LogicalDisk (DeviceID = "C:")
  map| Antecedent : Win32_DiskPartition (DeviceID = "Disk #0, Partition #2")
  map| Dependent  : Win32_LogicalDisk (DeviceID = "D:")
  map| Antecedent : Win32_DiskPartition (DeviceID = "Disk #0, Partition #4")
  map| Dependent  : Win32_LogicalDisk (DeviceID = "E:")
-- windowed processes rc=0
  win| ApplicationFrameHost ??                                                                              
  win| cmd                  ?? ???: C:\Windows\System32\cmd.exe - winfr  D: E:\Recovery /extensive          
  win| cmd                  ???: ?????                                                                      
  win| Everything           ??? - Everything                                                                
  win| firefox              ?????? ? Mozilla Firefox                                                        
  win| msedge               Arena | Benchmark & Compare the Best AI Models ??? 20 ??? - ?? - Microsoft? Edge
  win| QQ                   QQ                                                                              
  win| SystemSettings       ??                                                                              
  win| Taskmgr              ?????                                                                           
  win| TextInputHost        Windows ????                                                                    
  win| v2rayN               v2rayN - V7.24.9 - X64 - ????????                                               
  win| WindowsTerminal      C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe                       
E: free now: 289313MB / 732562MB
WDR folder files now: 561 (561 at 23:32)
R331_DISK_MEDIA_COMPLETE=True
