# Cloud interop health report
time=2026-10-03 20:32:33 +08:00
host=LAPTOP-R77M5D6M

## Git
branch=arena/01a0ff69-git-pull-arena
head=bdd71f6 check: request round 252 (awaiting local check)

## Google Drive / rclone
rclone_present=True path=C:\Users\文少\AppData\Local\Programs\rclone\rclone.exe
gdrive_remote=gdrive_jzthjyz: present=False
gdrive_about_ok=False
gdrive_about_detail=rclone.exe : Usage: | 所在位置 E:\0github\git-sync\git-pull-arena-01a0ff69\skills\cloud-interop\scripts\interop-health.ps1:24 字符: 19 | +     try { return (& $exe @args 2>&1 | Out-String).Trim() } catch { re ... | +                   ~~~~~~~~~~~~~~~~~ |     + CategoryInfo          : NotSpecified: (Usage::String) [], RemoteException |     + FullyQualifiedErrorId : NativeCommandError |   |   rclone [flags] |   rclone [command] |  | Available commands: |   about       Get quota information from the remote. |   archive     Perform an action on an archive. |   authorize   Remote authorization. |   backend     Run a backend-specific command. |   bisync      Perform bidirectional synchronization between two paths. |   cat         Concatenates any files and sends them to stdout. |   check       Checks the files in the source and destination match. |   checksum    Checks the files in the destination against a SUM file. |   cleanup     Clean up the remote if possible. |   completion  Output completion script for a given shell. |   config      Enter an interactive configuration session. |   convmv      Convert file and directory names in place. |   copy        Copy files from source to dest, skipping identical files. |   copyto      Copy files from source to dest, skipping identical files. |   copyurl     Copy the contents of the URL supplied content to dest:path. |   cryptcheck  Cryptcheck checks the integrity of an encrypted remote. |   cryptdecode Cryptdecode returns unencrypted file names. |   dedupe      Interactively find duplicate filenames and delete/rename them. |   delete      Remove the files in path. |   deletefile  Remove a single file from remote. |   gendocs     Output markdown docs for rclone to the directory supplied. |   gitannex    Speaks with git-annex over stdin/stdout. |   gui         Open the web based GUI. |   hashsum     Produces a hashsum file for all the objects in the path. |   help        Show help for rclone commands, flags and backends. |   link        Generate public link to file/folder. |   listremotes List all the remotes in the config file and defined in environment variables. |   ls          List the objects in the path with size and path. |   lsd         List all directories/containers/buckets in the path. |   lsf         List directories and objects in remote:path formatted for parsing. |   lsjson      List directories and objects in the path in JSON format. |   lsl         List the objects in path with modification time, size and path. |   md5sum      Produces an md5sum file for all the objects in the path. |   mkdir       Make the path if it doesn't already exist. |   mount       Mount the remote as file system on a mountpoint. |   move        Move files from source to dest. |   moveto      Move file or directory from source to dest. |   ncdu        Explore a remote with a text based user interface. |   obscure     Obscure password for use in the rclone config file. |   purge       Remove the path and all of its contents. |   rc          Run a command against a running rclone. |   rcat        Copies standard input to file on remote. |   rcd         Run rclone listening to remote control commands only. |   rmdir       Remove the empty directory at path. |   rmdirs      Remove empty directories under the path. |   selfupdate  Update the rclone binary. |   serve       Serve a remote over a protocol. |   settier     Changes storage class/tier of objects in remote. |   sha1sum     Produces an sha1sum file for all the objects in the path. |   size        Prints the total size and number of objects in remote:path. |   sync        Make source and dest identical, modifying destination only. |   test        Run a test command |   touch       Create new file or change file modification time. |   tree        List the contents of the remote in a tree like fashion. |   version     Show the version number. |  | Use "rclone [command] --help" for more information about a command. | Use "rclone help flags" for to see the global flags. | Use "rclone help backends" for a list of supported services.

## Kaggle
kaggle_cli=False
kaggle_json=False path=C:\Users\文少\.kaggle\kaggle.json

## Tailscale / machines
tailscale_cli=True path=E:\Tailscale\tailscale.exe
tailscale_status_parse_warn=True

## Muse protocol
muse_protocol_present=True
muse_poller_present=True
muse_smoke_state=done
muse_smoke_artifact=sources/muse/muse_out_smoke_20261003_1718.zip

CLOUD_INTEROP_HEALTH_DONE
