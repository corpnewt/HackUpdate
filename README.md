# HackUpdate
```
usage: HackUpdate.command [-h] [-e EFI] [-d DISK] [-f FOLDER_PATH] [-b] [-x]
                          [-o] [-p] [-n] [-s SETTINGS]

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
  -n, --no-header       prevents clearing the screen and printing the header
                        at script start
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
* OCConfigCompare: `-w -u config_path` (will resolve the `config_path`)

***

The above can be configured via `settings.json` file (either placed in HackUpdate's `Scripts` directory, or passed via the `-s` option) with the following layout:

```json
{
  "efi": "bootloader", 
  "disk": null, 
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
  "occ_unmount": false
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

Any settings omitted from a custom `settings.json` will fall back to defaults.

***

## To install:

Download [the zip](https://github.com/corpnewt/HackUpdate/archive/refs/heads/master.zip) of this repo, or do the following one line at a time in Terminal:

    git clone https://github.com/corpnewt/HackUpdate
    cd HackUpdate
    chmod +x HackUpdate.command
    
Then run with either `./HackUpdate.command` or by double-clicking *HackUpdate.command*
