# R278 fix the 12-pack: distinct wallpapers + working CDN downloads
time=2026-10-06 13:14:40
screen_locked_detected=False
lively_exe=C:\Program Files\Lively Wallpaper\Lively.exe
diag_curl_exit=28
   curl|  27  2.71M  27 768.0k   0      0  15555      0   03:03   00:50   02:13   8179
   curl|  27  2.71M  27 768.0k   0      0  15252      0   03:06   00:51   02:15   8191
   curl|  27  2.71M  27 768.0k   0      0  14958      0   03:10   00:52   02:18   8173
   curl|  27  2.71M  27 768.0k   0      0  14678      0   03:14   00:53   02:21   2812
   curl|  27  2.71M  27 768.0k   0      0  14409      0   03:17   00:54   02:23   2812
   curl|  28  2.71M  28 784.0k   0      0  14208      0   03:20   00:56   02:24   2756
   curl|  28  2.71M  28 784.0k   0      0  13961      0   03:24   00:57   02:27   2756
   curl|  28  2.71M  28 784.0k   0      0  13721      0   03:27   00:58   02:29   2761
   curl|  28  2.71M  28 784.0k   0      0  13490      0   03:31   00:59   02:32   2761* Operation timed out after 60009 milliseconds with 8
   curl| 
   curl| * closing connection #0
   curl| curl: (28) Operation timed out after 60009 milliseconds with 802816 out of 2851747 bytes received
diag_iwr_exit=0 out=True
diag_iwr_downloaded_ok=True
diag_page_exit=0 out=55699
page_mp4_links_found=15
   page| https://cdn.livelywallpaper.app/wallpapers/evening-window-view/preview.mp4
   page| https://cdn.livelywallpaper.app/wallpapers/evening-window-view/download.mp4
   page| https://cdn.livelywallpaper.app/wallpapers/evening-window-view/hd.mp4
   page| https://cdn.livelywallpaper.app/wallpapers/lo-fi-glow/preview.mp4
   page| https://cdn.livelywallpaper.app/wallpapers/butterfly-bloom-sword-spirit-forest/preview.mp4
   page| https://cdn.livelywallpaper.app/wallpapers/autumn-spirit-dance/preview.mp4
existing_pack_distinct=6 of 12
local_known| anime-live-r244
local_known| anime-ultra-r246
local_known| cute-anime-r247
local_known| mahiru-golden
local_known| meteor-girl
distinct_entries_after_dedupe=6
   keep| hotori <- 01-hotori.mp4
   keep| anime-live-r244 <- 02-local2.mp4
   keep| anime-ultra-r246 <- 03-local3.mp4
   keep| cute-anime-r247 <- 04-local4.mp4
   keep| meteor-girl <- 08-local8.mp4
   keep| mahiru-golden <- 09-local9.mp4
download evening-window-view                          OK via iwr(page) (25063 KB)
download midnight-sakura-train-station                OK via iwr(page) (31872 KB)
download peaceful-anime-tree-swing-live-wallpaper     OK via iwr(page) (21972 KB)
download gojo-satoru-train                            OK via curl(page) (66378 KB)
download tanjiro-kamado-crimson-moon                  OK via iwr(page) (9059 KB)
download itachi-uchiha-crimson-shadows                OK via curl(page) (16641 KB)
new_cdn_downloads=6 total_entries=12
pack_rebuilt files_kept=12 stale_removed=6
   cat 01 hotori                                       OK 2601KB
   cat 02 anime-live-r244                              OK 29551KB
   cat 03 anime-ultra-r246                             OK 9992KB
   cat 04 cute-anime-r247                              OK 10196KB
   cat 05 meteor-girl                                  OK 2177KB
   cat 06 mahiru-golden                                OK 1183KB
   cat 07 evening-window-view                          OK 25063KB
   cat 08 midnight-sakura-train-station                OK 31872KB
   cat 09 peaceful-anime-tree-swing-live-wallpaper     OK 21972KB
   cat 10 gojo-satoru-train                            OK 66378KB
   cat 11 tanjiro-kamado-crimson-moon                  OK 9059KB
   cat 12 itachi-uchiha-crimson-shadows                OK 16641KB
catalog_valid=12 distinct_hashes=12
switch_1_exit=0
pa ok=True
switch_2_exit=0
pb ok=True
   wallpaper_player| class=mpv owner=mpv.exe
switch_diff_ratio=0.887165
switch_proven=True
final_switch_1_exit=0
m1 ok=True
m2 ok=True
final_motion_ratio=0.993586
final_motion_avg=272.264
motion_final_proven=True
layer_final=True
WALLPAPER_PACK_DISTINCT_READY=True (need 12 valid distinct, >=6 fresh CDN downloads)
