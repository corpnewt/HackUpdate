#!/usr/bin/env python
# 0.0.0
from Scripts import bdmesg, disk, run, utils
import os, sys, json, shutil, argparse, subprocess, datetime, time

class HackUpdate:
    def __init__(self, **kwargs):
        self.r  = run.Run()
        self.d  = disk.Disk()
        self.u  = utils.Utils("HackUpdate")
        self.boot_manager = bdmesg.get_bootloader_uuid()
        # Get the tools we need
        self.script_folder = "Scripts"
        self.settings = None
        cwd = os.getcwd()
        os.chdir(os.path.dirname(os.path.realpath(__file__)))
        # Load the settings if they exist
        try:
            settings_file = self.u.check_path(kwargs.get("settings","./Scripts/settings.json"))
            if settings_file: # The path resolved properly
                self.settings = json.load(open(settings_file))
        except: pass
        # Fall back on defaults in the event they don't exist, or don't load
        if not self.settings:
            self.settings = {
                # Default settings here
                "efi"  : "bootloader", # ask, boot, bootloader, or the mount point/disk#s#
                "disk" : None, # Overrides efi, and is an explicit mount point/identifier (not resolved to EFI)
                "folder_path" : None, # Overrides disk and efi, and is a direct path to the EFI folder
                "no_header": False,
                "skip_building_kexts" : False,
                "skip_extracting_kexts" : False,
                "skip_opencore" : False,
                "skip_plist_compare" : False,
                "lnf"  : "../Lilu-and-Friends",
                "lnfrun" : "Run.command",
                # "lnf_args" : ["-p", "Default"], # List of customized Lilu and Friends args
                "ke" : "../KextExtractor",
                "kerun" : "KextExtractor.command",
                # "ke_args" : [], # List of customized KextExtractor args
                "oc" : "../OC-Update",
                "ocrun" : "OC-Update.command",
                # "oc_args" : [], # List of customized OC-Update args
                "occ" : "../OCConfigCompare",
                "occrun" : "OCConfigCompare.command",
                # "occ_args" : [], # List of customized OCConfigCompare args
                "occ_unmount": False # Whether we unmount if differences are found or not
            }
        # Let's strip empty *_args entries
        empty_args = []
        for key in self.settings:
            if key.endswith("_args") and isinstance(self.settings[key],(list,tuple)) and not self.settings[key]:
                empty_args.append(key)
        for key in empty_args:
            self.settings.pop(key,None)
        # Setup some colors
        self.c = {
            "r":u"\u001b[31;1m",
            "g":u"\u001b[32;1m",
            "b":u"\u001b[36;1m",
            "c":u"\u001b[0m"
        }
        os.chdir(cwd)

    def get_time(self,t):
        # A helper function to return a human readable time string from seconds
        try:
            dt = datetime.timedelta(seconds=int(t))
            time_tuple = (
                ("week",int(dt.days/7)),
                ("day",int(dt.days%7)),
                ("hour",int(dt.seconds/3600)),
                ("minute",int(dt.seconds%3600/60)),
                ("second",int(dt.seconds%3600%60))
            )
            msg_parts = ["{:,} {}{}".format(x[1],x[0],"" if x[1]==1 else "s") for x in time_tuple if x[1]]
        except:
            msg_parts = [] # Something went wrong - use an empty list
        return ", ".join(msg_parts) if len(msg_parts) else "0 seconds"

    def resolve_args(self, args, disk = None, folder_path = None):
        # Walk the passed list of args and replace instances of the following
        # case-sensitive placeholders:
        #
        # [[disk]]:        the target disk/efi identifier
        # [[mount_point]]: the target disk/efi mount point, if any
        # [[folder_path]]: the target folder, if any - overrides disk and mount_point
        # [[config_path]]: resolves config.plist based on the folder_path or mount_point
        # [[oc_path]]:     resolves OpenCore.efi based on the folder_path or mount_point
        # [[lnf]]:         the path to Lilu-and-Friends
        # [[ke]]:          the path to KextExtractor
        # [[oc]]:          the path to OC-Update
        # [[occ]]:         the path to OCConfigCompare
        #

        d = self.d.get_identifier(disk)
        m = self.d.get_mount_point(disk)
        f = self.u.check_path(folder_path) if folder_path else None
        c = None
        o = None
        if f:
            # Check for f/EFI/OC/config.plist, f/OC/config.plist or f/config.plist
            path_check = ("EFI","OC")
            for i in range(len(path_check)+1):
                c_check = os.path.join(f,*path_check[i:],"config.plist")
                o_check = os.path.join(f,*path_check[i:],"OpenCore.efi")
                if os.path.isfile(c_check):
                    c = c_check
                if os.path.isfile(o_check):
                    o = o_check
        elif m:
            c_check = os.path.join(m,"EFI","OC","config.plist")
            o_check = os.path.join(m,"EFI","OC","OpenCore.efi")
            if os.path.isfile(c_check):
                c = c_check
            if os.path.isfile(o_check):
                o = o_check

        cwd = os.getcwd()
        os.chdir(os.path.dirname(os.path.realpath(__file__)))
        lnf = os.path.realpath(self.settings.get("lnf","../Lilu-and-Friends"))
        ke  = os.path.realpath(self.settings.get("ke","../KextExtractor"))
        oc  = os.path.realpath(self.settings.get("oc","../OC-Update"))
        occ = os.path.realpath(self.settings.get("occ","../OCConfigCompare"))
        os.chdir(cwd)

        new_args = []
        for arg in args:
            if f: # Only worry about the folder_path and config_path
                arg = arg.replace("[[folder_path]]",f)
                if c: arg = arg.replace("[[config_path]]",c)
                if o: arg = arg.replace("[[oc_path]]",o)
            elif d: # Only get the disk, mount_point, and config_path if accessible
                arg = arg.replace("[[disk]]",d)
                if m:
                    arg = arg.replace("[[mount_point]]",m)
                    if c: arg = arg.replace("[[config_path]]",c)
                    if o: arg = arg.replace("[[oc_path]]",o)
            arg = arg.replace("[[lnf]]",lnf).replace("[[ke]]",ke).replace("[[oc]]",oc).replace("[[occ]]",occ)
            new_args.append(arg)
        return new_args

    def get_efi(self,allow_main=True):
        while True:
            self.d.update()
            pad = 4
            disk_string = "\n"
            if not self.settings.get("full"):
                boot_disk = self.d.get_parent(self.boot_manager)
                mounts = self.d.get_mounted_volume_dicts()
                for i,d in enumerate(mounts,start=1):
                    disk_string += "{}. {} ({})".format(str(i).rjust(2), d["name"], d["identifier"])
                    if boot_disk and self.d.get_parent(d["identifier"]) == boot_disk:
                        disk_string += " *"
                    disk_string += "\n"
            else:
                mounts = self.d.get_disks_and_partitions_dict()
                disks = list(mounts)
                for i,d in enumerate(disks,start=1):
                    disk_string+= "{}. {}:\n".format(str(i).rjust(2),d)
                    if mounts[d].get("scheme"):
                        disk_string += "      {}\n".format(mounts[d]["scheme"])
                    if mounts[d].get("physical_stores"):
                        disk_string += "      Physical Store{} on {}\n".format(
                            "" if len(mounts[d]["physical_stores"])==1 else "s",
                            ", ".join(mounts[d]["physical_stores"])
                        )
                    parts = mounts[d]["partitions"]
                    part_list = []
                    for p in parts:
                        name = "Container for {}".format(p["container_for"]) if "container_for" in p else p["name"]
                        p_text = "        - {} ({})".format(name, p["identifier"])
                        if self.boot_manager and p["disk_uuid"] == self.boot_manager:
                            # Got boot manager
                            p_text += " *"
                        part_list.append(p_text)
                    if len(part_list):
                        disk_string += "\n".join(part_list) + "\n"
            disk_string += "\nS. Switch to {} Output\n".format("Slim" if self.settings.get("full") else "Full")
            disk_string += "B. Select the Boot Drive's EFI\n"
            if self.boot_manager:
                disk_string += "C. Select the Booted EFI (Clover/OC)\n"
            disk_string += ("\nM. Main" if allow_main else "") + "\nQ. Quit\n"
            if self.boot_manager:
                disk_string += "\n(* denotes the booted EFI (Clover/OC)"
            height = max(len(disk_string.split("\n"))+pad,24)
            if self.settings.get("resize_window",True): self.u.resize(80,height)
            self.u.head()
            print(disk_string)
            menu = self.u.grab("Pick the drive containing your EFI:  ")
            if not len(menu):
                continue
            if menu.lower() == "q":
                if self.settings.get("resize_window",True): self.u.resize(80,24)
                self.u.custom_quit()
            elif allow_main and menu.lower() == "m":
                if self.settings.get("resize_window",True): self.u.resize(80,24)
                return
            elif menu.lower() == "s":
                self.settings["full"] = not self.settings.get("full")
                continue
            elif menu.lower() == "b":
                disk = "/"
                iden = self.d.get_efi("/")
            elif menu.lower() == "c" and self.boot_manager:
                disk = self.boot_manager
                iden = self.d.get_efi(self.boot_manager)
            else:
                try: disk = mounts[int(menu)-1]["identifier"] if isinstance(mounts,list) else list(mounts)[int(menu)-1]
                except: disk = menu
            if self.settings.get("resize_window",True): self.u.resize(80,24)
            iden = self.d.get_identifier(disk)
            if not iden:
                self.u.head("Invalid Disk")
                print("")
                print("'{}' is not a valid disk!".format(disk))
                print("")
                self.u.grab("Returning in 3 seconds...", timeout=3)
                continue
            # Valid disk!
            efi = self.d.get_efi(iden)
            if not efi:
                self.u.head("No EFI Partition")
                print("")
                print("There is no EFI partition associated with {}!".format(iden))
                print("")
                self.u.grab("Returning in 3 seconds...", timeout=3)
                continue
            return efi

    def main(self):
        if not self.settings.get("no_header"):
            self.u.head()
            print("")
        # Gather some values
        oc_diff = False
        efi = None
        folder_path = None
        efi_mounted = True # To avoid attempting to unmount a disk we didn't mount
        
        # Get our phases
        skip_building_kexts = self.settings.get("skip_building_kexts",False)
        skip_extracting_kexts = self.settings.get("skip_extracting_kexts",False)
        skip_opencore = self.settings.get("skip_opencore",False)
        skip_plist_compare = self.settings.get("skip_plist_compare",False)
        
        cwd = os.getcwd()
        os.chdir(os.path.dirname(os.path.realpath(__file__)))
        lnf = os.path.realpath(self.settings.get("lnf","../Lilu-and-Friends"))
        ke  = os.path.realpath(self.settings.get("ke","../KextExtractor"))
        oc  = os.path.realpath(self.settings.get("oc","../OC-Update"))
        occ = os.path.realpath(self.settings.get("occ","../OCConfigCompare"))
        os.chdir(cwd)
        # Check if we've disabled all steps
        if all((skip_building_kexts,skip_extracting_kexts,skip_opencore,skip_plist_compare)):
            print("All steps skipped, nothing to do.")
            print("\nDone.\n")
            exit()
        if all((skip_extracting_kexts,skip_opencore,skip_plist_compare)):
            print("Target EFI/disk not needed - only building kexts...")
        else:
            if self.settings.get("folder_path"): # We have an explicit folder - use it
                print("Resolving custom folder path \"{}\"...".format(self.settings["folder_path"]))
                folder_path = self.u.check_path(self.settings["folder_path"])
                if not folder_path:
                    print(" - Unable to locate!")
                    exit(1)
            elif self.settings.get("disk"): # We have an explicit disk - use it
                print("Resolving custom disk \"{}\"...".format(self.settings["disk"]))
                efi = self.d.get_identifier(self.settings["disk"])
                if not efi:
                    print(" - Unable to locate!")
                    exit(1)
            else:
                print("Finding EFI...")
                if self.settings.get("efi","bootloader").lower() == "bootloader":
                    efi = self.d.get_efi(bdmesg.get_bootloader_uuid())
                elif self.settings.get("efi","bootloader").lower() == "boot":
                    efi = self.d.get_efi("/")
                else:
                    efi = self.d.get_efi(self.settings.get("efi","bootloader"))
                if not efi:
                    # Let the user pick
                    efi = self.get_efi(allow_main=False)
                    if not efi:
                        print(" - Unable to locate!")
                        exit(1)
                    # Print the backlog
                    self.u.resize(80, 24)
                    self.u.head()
                    print("")
                    print("Finding EFI...")
            if folder_path:
                print(" - Located")
            else:
                print(" - Located at {}".format(efi))
                efi_mounted = self.d.is_mounted(efi)
                if efi_mounted:
                    print(" --> Already mounted")
                else:
                    print(" --> Not mounted, mounting...")
                    self.d.mount_partition(efi)
                if not self.d.is_mounted(efi):
                    print(" --> Failed to mount!")
                    exit(1)
        pid = str(os.getpid())
        print("Running caffeinate to prevent idle sleep...")
        print(" - Bound to PID {}".format(pid))
        subprocess.Popen(["caffeinate","-i","-w",pid])
        t = time.time() # Save the start time to use for later
        if skip_building_kexts:
            print("Skipping kext building...")
        else:
            # Let's try to build kexts
            print("Locating Lilu-And-Friends...")
            if not os.path.exists(lnf):
                print(" - Unable to locate!")
                exit(1)
            print(" - Located at {}".format(lnf))
            # Clear out old kexts
            if os.path.exists(os.path.join(lnf, "Kexts")):
                print(" --> Kexts folder found, clearing...")
                for x in os.listdir(os.path.join(lnf, "Kexts")):
                    if x.startswith("."):
                        continue
                    try:
                        test_path = os.path.join(lnf, "Kexts", x)
                        if os.path.isdir(test_path):
                            shutil.rmtree(test_path)
                        else:
                            os.remove(test_path)
                    except:
                        print(" ----> {} Failed to remove!".format(x))
            # Let's build the new kexts
            print(" - Building kexts...")
            args = [os.path.join(lnf, self.settings.get("lnfrun","Run.command"))]
            args.extend(self.resolve_args(self.settings.get("lnf_args",["-r","-p","Default"]),disk=efi,folder_path=folder_path))
            out = self.r.run({"args":args})
            # Let's quick format our output
            primed = False
            success = False
            kextout = {
                "succeeded" : [],
                "failed"    : []
            }
            for line in out[0].split("\n"):
                if "succeeded:" in line.lower():
                    primed = True
                    success = True
                    continue
                if not primed or line == "" or line == " ":
                    continue
                if line.lower().startswith("build took "):
                    break
                if "failed:" in line.lower():
                    success = False
                    continue
                if success:
                    kextout["succeeded"].append(line.replace("    ",""))
                else:
                    kextout["failed"].append(line.replace("    ",""))
            print(" --> Succeeded:")
            # Try to print them without colors - fall back to colors if need be
            try:
                print("\n".join([" ----> {}".format("m".join(x.split("m")[1:])) for x in kextout["succeeded"]]))
            except:
                print("\n".join([" ----> {}".format(x) for x in kextout["succeeded"]]))
            print(" --> Failed:")
            print("\n".join([" ----> {}".format(x) for x in kextout["failed"]]))
        if skip_extracting_kexts:
            print("Skipping kext extraction...")
        else:
            # Let's extract the kexts
            print("Locating KextExtractor...")
            if not os.path.exists(ke):
                print(" - Unable to locate!")
                exit(1)
            print(" - Located at {}".format(ke))
            print(" - Extracting kexts...")
            args = [os.path.join(ke, self.settings.get("kerun","KextExtractor.command"))]
            if folder_path: ke_defaults = [os.path.join(lnf,"Kexts"),"f="+folder_path]
            else: ke_defaults = ["-d",os.path.join(lnf,"Kexts"),efi]
            args.extend(self.resolve_args(self.settings.get("ke_args",ke_defaults),disk=efi,folder_path=folder_path))
            out = self.r.run({"args":args})
            # Print the KextExtractor output
            check_primed = False
            for line in out[0].split("\n"):
                if line.strip().startswith("Checking for "): check_primed = True
                if not check_primed or not line.strip(): continue
                print("    "+line)
        if skip_opencore:
            print("Skipping OpenCore building and updating...")
        else:
            # Let's get our OC
            print("Locating OC-Update...")
            if not os.path.exists(oc):
                print(" - Unable to locate!")
                exit(1)
            print(" - Located at {}".format(oc))
            print(" - Gathering/building and updating OC...")
            args = [os.path.join(oc, self.settings.get("ocrun","OC-Update.command"))]
            args.extend(self.resolve_args(self.settings.get("oc_args",["-n","-p",folder_path] if folder_path else ["-n","-d",efi]),disk=efi,folder_path=folder_path))
            out = self.r.run({"args":args})
            # Gather the output after updating
            if not "Updating .efi files..." in out[0]:
                print(" --> No .efi files updated!")
            else:
                for line in out[0].split("Updating .efi files...")[-1].split("\n"):
                    if not line.strip() or line.strip().lower() == "done.": continue
                    print("    "+line)
        if skip_plist_compare:
            print("Skipping plist compare...")
        else:
            print("Locating OCConfigCompare...")
            if not os.path.exists(occ):
                print(" - Unable to locate!")
                exit(1)
            print(" - Located at {}".format(occ))
            print(" - Checking for config.plist")
            config_path = self.resolve_args(["[[config_path]]"],disk=efi,folder_path=folder_path)[0]
            if not config_path or not os.path.exists(config_path):
                print(" --> Unable to locate!")
                exit(1)
            print(" --> Located at {}".format(config_path))
            print(" - Gathering differences:")
            args = [os.path.join(occ, self.settings.get("occrun","OCConfigCompare.command"))]
            args.extend(self.resolve_args(self.settings.get("occ_args",["-w","-u",config_path]),disk=efi,folder_path=folder_path))
            out = self.r.run({"args":args})
            if not "Checking for values missing from User plist:" in out[0]:
                print(" --> Something went wrong comparing!")
            else:
                print("     Checking for values missing from User plist:")
                for line in out[0].split("Checking for values missing from User plist:")[-1].split("\n"):
                    line = line.strip()
                    if not line: continue
                    if line == "Checking for values missing from Sample:" or (line.startswith("Updating ") and line.endswith(" with changes...")) or (line.startswith("Backing up ") and line.endswith("...")): print("     "+line)
                    elif line.startswith("- Nothing missing from "): print("      - {}None{}".format(self.c["g"],self.c["c"]))
                    else:
                        oc_diff = True # Retain differences
                        print("      - {}{}{}".format(self.c["r"],line,self.c["c"]))
        # Reset our EFI to its original state
        if not efi_mounted:
            if oc_diff and not self.settings.get("occ_unmount",False):
                print("Leaving {} mounted due to config.plist differences...".format("target disk" if self.settings.get("disk") else "EFI"))
            else:
                print("Unmounting {}...".format("target disk" if self.settings.get("disk") else "EFI"))
                self.d.unmount_partition(efi)
        print("")
        print("Done. Tasks took {}.".format(self.get_time(time.time()-t)))
        print("")
        exit()

if __name__ == '__main__':
    # Setup the cli args
    parser = argparse.ArgumentParser(prog="HackUpdate.command", description="HackUpdate - a py script that automates other scripts.")
    parser.add_argument("-e", "--efi", help="the EFI to consider - ask, boot, bootloader, or mount point/identifier")
    parser.add_argument("-d", "--disk", help="the mount point/identifier to target - EFI or not (overrides --efi)")
    parser.add_argument("-f", "--folder-path", help="an explicit path to use for the EFI (overrides --efi and --disk)")
    parser.add_argument("-b", "--skip-building-kexts", help="skip building kexts via Lilu and Friends", action="store_true")
    parser.add_argument("-x", "--skip-extracting-kexts", help="skip updating kexts via KextExtractor", action="store_true")
    parser.add_argument("-o", "--skip-opencore", help="skip building and updating OpenCore via OC-Update", action="store_true")
    parser.add_argument("-p", "--skip-plist-compare", help="skip comparing config.plist to latest sample.plist via OCConfigCompare", action="store_true")
    parser.add_argument("-n", "--no-header", help="prevents clearing the screen and printing the header at script start", action="store_true")
    parser.add_argument("-s", "--settings", help="path to settings.json file to use (default is ./Scripts/settings.json)")

    args = parser.parse_args()

    h = HackUpdate(settings=args.settings if args.settings else "./Scripts/settings.json")

    # Setup any phase/header overrides
    if args.skip_building_kexts:
        h.settings["skip_building_kexts"] = args.skip_building_kexts
    if args.skip_extracting_kexts:
        h.settings["skip_extracting_kexts"] = args.skip_extracting_kexts
    if args.skip_building_kexts:
        h.settings["skip_opencore"] = args.skip_opencore
    if args.skip_plist_compare:
        h.settings["skip_plist_compare"] = args.skip_plist_compare
    if args.no_header:
        h.settings["no_header"] = args.no_header

    # Check for pathing/disk/efi settings
    if args.folder_path:
        h.settings["folder_path"] = args.folder_path
    elif args.disk:
        h.settings["disk"] = args.disk
    elif args.efi:
        h.settings["efi"] = args.efi
    
    h.main()
