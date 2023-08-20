# HackUpdate
```
usage: HackUpdate.command [-h] [-e EFI] [-d DISK] [-f FOLDER_PATH] [-b] [-x]
                          [-o] [-p] [-t] [-n] [-g] [-s SETTINGS]

HackUpdate - a py script that automates other scripts.

options:
  -h, --help            show this help message and exit
  -e EFI, --efi EFI     the EFI to consider - ask, boot, bootloader, or mount
                        point/identifier
  -d DISK, --disk DISK  the mount point/identifier to target - EFI or not
                        (overrides --efi)
  -f FOLDER_PATH, --folder-path FOLDER_PATH
                        an explicit path to use for the EFI (overrides --efi
                        and --disk)
  -b, --skip-building-kexts
                        skip building kexts via Lilu and Friends
  -x, --skip-extracting-kexts
                        skip updating kexts via KextExtractor
  -o, --skip-opencore   skip building and updating OpenCore via OC-Update
  -p, --skip-plist-compare
                        skip comparing config.plist to latest sample.plist via
                        OCConfigCompare
  -t, --no-git          don't attempt to update script repos with git pull
  -n, --no-header       prevents clearing the screen and printing the header
                        at script start
  -g, --debug-subscripts
                        streams the output of the scripts HackUpdate calls for
                        debug purposes
  -s SETTINGS, --settings SETTINGS
                        path to settings.json file to use (default is
                        ./Scripts/settings.json)
```
 
***

By default, HackUpdate assumes the following directory structure:

```
└── Parent Directory
    ├── HackUpdate
    │   └── HackUpdate.command
    ├── Lilu-and-Friends
    │   └── Run.command
    ├── KextExtractor
    │   └── KextExtractor.command
    ├── OC-Update
    │   └── OC-Update.command
    └── OCConfigCompare
        └── OCConfigCompare.command
```

By default, Hackupdate will use the following CLI args for each:

* Lilu And Friends: `-r -p Default`
* KextExtractor: `-d folder_or_bootloader_efi kexts_path` (will resolve the `folder_or_bootloader_efi` and `kexts_path`)
* OC-Update: `-n -d folder_or_bootloader_efi` (will resolve the `folder_or_bootloader_efi`)
* OCConfigCompare: `-m off -w -u config_path` (will resolve the `config_path`)

***

The above can be configured via `settings.json` file (either placed in HackUpdate's `Scripts` directory, or passed via the `-s` option) with the following layout:

```json
{
  "debug_subscripts": false,
  "efi": "bootloader", 
  "disk": null,
  "no_git": false,
  "folder_path" : null,
  "no_header": false,
  "skip_building_kexts" : false,
  "skip_extracting_kexts" : false,
  "skip_opencore" : false,
  "skip_plist_compare" : false,
  "lnf": "../Lilu-and-Friends", 
  "lnfrun": "Run.command", 
  "lnf_args": [], 
  "ke": "../KextExtractor", 
  "kerun": "KextExtractor.command", 
  "ke_args": [], 
  "oc": "../OC-Update", 
  "ocrun": "OC-Update.command", 
  "oc_args": [], 
  "occ": "../OCConfigCompare", 
  "occrun": "OCConfigCompare.command", 
  "occ_args": [], 
  "occ_unmount": false,
  "preflight": [
    {
      "path": "/path/to/tool",
      "args": [
        "arguments"
      ],
      "message": "Whatever you want to print during the task",
      "abort_on_fail": true
    }
  ],
  "postflight": [
    {
      "path": "/path/to/tool",
      "args": [
        "arguments"
      ],
      "message": "Whatever you want to print during the task",
      "abort_on_fail": true
    }
  ],
}
```
* `efi`: Can be `boot`, `bootloader`, or a mount point/disk identifier.  Will resolve to an attached EFI partition.  If not found, will prompt.
* `disk`: Overrides `efi`, can be a mount point/disk identifier.  Treated explicitly, will not resolve to or prompt for an EFI partition.
* `folder_path`: Overrides `disk` and `efi` and should point to the target EFI or OC folder.
* `*_args`: Should only be included if customizing - empty lists will be ignored, and default settings will be used instead.
* `occ_unmount`: Sets whether we unmount the target disk if OCConfigCompare finds differences.

Arguments allow for placeholder subsitution via the following:

* `[[disk]]`: the target disk/efi identifier
* `[[mount_point]]`: the target disk/efi mount point, if any
* `[[folder_path]]`: the target folder, if any - overrides `disk` and `mount_point`
* `[[config_path]]`: resolves config.plist based on the `folder_path` or `mount_point`
* `[[oc_path]]`: resolves OpenCore.efi based on the `folder_path` or `mount_point`
* `[[lnf]]`: the path to the Lilu-and-Friends folder
* `[[ke]]`: the path to the KextExtractor folder
* `[[oc]]`: the path to the OC-Update folder
* `[[occ]]`: the path to the OCConfigCompare folder

Custom tasks can be run at different stages of the HackUpdate process.  The order the tasks are executed is as follows:

* `preflight`: runs after finding/mounting the EFI and running `caffeinate`
  * If present, runs regardless of which stages are enabled - as long as at least one is
* `pre_lnf` or `post_lnf`: runs before or after the Lilu and Friends kext building stage respectively
* `pre_ke` or `post_ke`: runs before or after the KextExtractor kext extraction stage respectively
* `pre_oc` or `post_oc`: runs before or after the OC-Update OpenCore building stage respetively
* `pre_occ` or `post_occ`: runs before or after the OCConfigCompare plist compare stage respectively
* `postflight`: runs after all other stages, but before unmounting the EFI
  * If present, runs regardless of which stages are enabled - as long as at least one is

Each custom task is optional - but if defined, should be formatted as an array of dictionaries, each containing the following keys:

* `path`: the full path to the target binary
* `args`: an optional array of string arguments to pass to the command
* `message`: an optional string message to display when the task runs
* `abort_on_fail` an optional boolean value that sets whether we should stop if the task returns a non-zero status (defaults to `false`)

All custom task `args` allow for the same variable substitutions as the `*_args`.


Any settings omitted from a custom `settings.json` will fall back to defaults.

***

## To install:

Download [the zip](https://github.com/corpnewt/HackUpdate/archive/refs/heads/master.zip) of this repo, or do the following one line at a time in Terminal:

    git clone https://github.com/corpnewt/HackUpdate
    cd HackUpdate
    chmod +x HackUpdate.command
    
Then run with either `./HackUpdate.command` or by double-clicking *HackUpdate.command*
