# R312 full-path UAC trigger + helper v4 run
time=2026-10-06 20:08:59
screen_locked_detected=False
ps_full_exists=True cmd_full_exists=True helper_exists=True
showing heads-up popup (UAC is coming NOW)
== elevation attempt A (full paths) ==
FATAL: Traceback (most recent call last):
  File "E:\0github\git-sync\git-pull-arena-01a10bf3\code\tasks\t263_uac_fullpath_r312.py", line 94, in <module>
    res=attempt('A')
        ^^^^^^^^^^^^
  File "E:\0github\git-sync\git-pull-arena-01a10bf3\code\tasks\t263_uac_fullpath_r312.py", line 57, in attempt
    lf=launcher(variant)
       ^^^^^^^^^^^^^^^^^
  File "E:\0github\git-sync\git-pull-arena-01a10bf3\code\tasks\t263_uac_fullpath_r312.py", line 41, in launcher
    ).format(ps=PSFULL,h=str(HELPER),e=str(UACERR))
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
ValueError: unexpected '{' in field name

R312_FINAL=crashed
