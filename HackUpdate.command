#!/usr/bin/env python
# 0.0.0
from Scripts import *
import os, sys, json, shutil

class HackUpdate:
    def __init__(self, **kwargs):
        self.r  = run.Run()
        self.d  = disk.Disk()
        self.dl = downloader.Downloader()
        self.u  = utils.Utils("HackUpdate")
        # Get the tools we need
        self.script_folder = "Scripts"
        self.settings_file = kwargs.get("settings", None)
        cwd = os.getcwd()
        os.chdir(os.path.dirname(os.path.realpath(__file__)))
        if self.settings_file and os.path.exists(self.settings_file):
            self.settings = json.load(open(self.settings_file))
        else:
            self.settings = {
                # Default settings here
                "disk" : "bootloader", # bootloader, boot, or the mount point/disk identifier
                "lnf"  : "../Lilu-and-Friends",
                "lnfrun" : "Run.command",
                "lnf_args" : ["-p", "Default"],
                "ke" : "../KextExtractor",
                "kerun" : "KextExtractor.command",
                "oc" : "../OC-Update",
                "ocrun" : "OC-Update.command",
                "oc_args" : ["-disk"],
                "occ" : "../OCConfigCompare",
                "occrun" : "OCConfigCompare.command",
                "occ_unmount": False # Whether we unmount if differences are found or not
            }
        self.c = {
            "r":u"\u001b[31;1m",
            "g":u"\u001b[32;1m",
            "b":u"\u001b[36;1m",
            "c":u"\u001b[0m"
        }
        os.chdir(cwd)

    def get_efi(self):
        self.d.update()
        boot_manager = bdmesg.get_bootloader_uuid()
        i = 0
        disk_string = ""
        if not self.settings.get("full", False):
            boot_manager_disk = self.d.get_parent(boot_manager)
            mounts = self.d.get_mounted_volume_dicts()
            for d in mounts:
                i += 1
                disk_string += "{}. {} ({})".format(i, d["name"], d["identifier"])
                if self.d.get_parent(d["identifier"]) == boot_manager_disk:
                    disk_string += " *"
                disk_string += "\n"
        else:
            mounts = self.d.get_disks_and_partitions_dict()
            disks = list(mounts)
            for d in disks:
                i += 1
                disk_string+= "{}. {}:\n".format(i, d)
                parts = mounts[d]["partitions"]
                part_list = []
                for p in parts:
                    p_text = "        - {} ({})".format(p["name"], p["identifier"])
                    if p["disk_uuid"] == boot_manager:
                        # Got boot manager
                        p_text += " *"
                    part_list.append(p_text)
                if len(part_list):
                    disk_string += "\n".join(part_list) + "\n"
        height = len(disk_string.split("\n"))+14
        if height < 24:
            height = 24
        self.u.resize(80, height)
        self.u.head()
        print("")
        print(" - Please select the target EFI -")
        print("")
        print(disk_string)
        if not self.settings.get("full", False):
            print("S. Switch to Full Output")
        else:
            print("S. Switch to Slim Output")
        print("B. Select the Boot Drive's EFI")
        if boot_manager:
            print("C. Select the Booted Clover/OC's EFI")
        print("")
        print("Q. Quit")
        print(" ")
        print("(* denotes the booted Clover/OC)")

        menu = self.u.grab("Pick the drive containing your EFI:  ")
        if not len(menu):
            return self.get_efi()
        if menu.lower() == "q":
            self.u.custom_quit()
        elif menu.lower() == "s":
            full = self.settings.get("full", False)
            self.settings["full"] = not full
            return self.get_efi()
        elif menu.lower() == "b":
            return self.d.get_efi("/")
        elif menu.lower() == "c" and boot_manager:
            return self.d.get_efi(boot_manager)
        try: disk = mounts[int(menu)-1]["identifier"] if isinstance(mounts, list) else list(mounts)[int(menu)-1]
        except: disk = menu
        iden = self.d.get_identifier(disk)
        name = self.d.get_volume_name(disk)
        if not iden:
            self.u.grab("Invalid disk!", timeout=3)
            return self.get_efi()
        # Valid disk!
        return self.d.get_efi(iden)

    def main(self):
        self.u.head()
        print("")
        print("Finding EFI...")
        if self.settings.get("disk","bootloader").lower() == "bootloader":
            efi = self.d.get_efi(bdmesg.get_bootloader_uuid())
        elif self.settings.get("disk","bootloader").lower() == "boot":
            efi = self.d.get_efi("/")
        else:
            efi = self.d.get_efi(self.settings.get("disk","bootloader"))
        if not efi:
            # Let the user pick
            efi = self.get_efi()
            if not efi:
                print(" - Unable to locate!")
                exit(1)
            # Print the backlog
            self.u.resize(80, 24)
            self.u.head()
            print("")
            print("Finding EFI...")
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
        # Let's try to build kexts
        print("Locating Lilu-And-Friends...")
        cwd = os.getcwd()
        os.chdir(os.path.dirname(os.path.realpath(__file__)))
        lnf = os.path.realpath(self.settings.get("lnf","../Lilu-and-Friends"))
        ke  = os.path.realpath(self.settings.get("ke","../KextExtractor"))
        oc  = os.path.realpath(self.settings.get("oc","../OC-Update"))
        occ = os.path.realpath(self.settings.get("occ","../OCConfigCompare"))
        os.chdir(cwd)
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
                print(" ----> {}".format(x))
                try:
                    test_path = os.path.join(lnf, "Kexts", x)
                    if os.path.isdir(test_path):
                        shutil.rmtree(test_path)
                    else:
                        os.remove(test_path)
                except:
                    print(" ------> Failed to remove!")
        # Let's build the new kexts
        print(" - Building kexts...")
        args = [os.path.join(lnf, self.settings.get("lnfrun","Run.command"))]
        args.extend(self.settings.get("lnf_args",[]))
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
        try:
            print("\n".join([" ----> {}".format("m".join(x.split("m")[1:])) for x in kextout["failed"]]))
        except:
            print("\n".join([" ----> {}".format(x) for x in kextout["failed"]]))
        # Let's extract the kexts
        print("Locating KextExtractor...")
        if not os.path.exists(ke):
            print(" - Unable to locate!")
            exit(1)
        print(" - Located at {}".format(ke))
        print(" - Extracting kexts...")
        out = self.r.run({"args":[
            os.path.join(ke, self.settings.get("kerun","KextExtractor.command")),
            os.path.join(lnf, "Kexts"),
            efi
        ]})

        efi_path = self.d.get_mount_point(efi)
        oc_path = os.path.join(efi_path,"EFI","OC","OpenCore.efi")
        oc_diff = False
        if os.path.exists(oc_path):
            print("Located existing OC...")
            # Let's get our OC
            print("Locating OC-Update...")
            if not os.path.exists(oc):
                print(" - Unable to locate!")
                exit(1)
            print(" - Located at {}".format(oc))
            print(" - Gathering/building and updating OC...")
            args = [os.path.join(oc, self.settings.get("ocrun","OC-Update.command"))]
            args.extend(self.settings.get("oc_args",[]))
            args.append(efi)
            out = self.r.run({"args":args})
            # Gather the output after updating
            if not "Updating .efi files..." in out[0]:
                print(" --> No .efi files updated!")
            else:
                for line in out[0].split("Updating .efi files...")[-1].split("\n"):
                    if not line.strip() or line.strip().lower() == "done.": continue
                    print("    "+line)
        
            print("Locating OCConfigCompare...")
            if not os.path.exists(occ):
                print(" - Unable to locate!")
                exit(1)
            print(" - Located at {}".format(occ))
            config_path = os.path.join(efi_path,"EFI","OC","config.plist")
            print(" - Checking for config.plist")
            if not os.path.exists(config_path):
                print(" --> Unable to locate!")
                exit(1)
            print(" --> Located at {}".format(config_path))
            print(" - Gathering differences:")
            args = [os.path.join(occ, self.settings.get("occrun","OCConfigCompare.command"))]
            args.extend(["-u",config_path])
            out = self.r.run({"args":args})
            if not "Checking for values missing from User plist:" in out[0]:
                print(" --> Something went wrong comparing!")
            else:
                print("     Checking for values missing from User plist:")
                for line in out[0].split("Checking for values missing from User plist:")[-1].split("\n"):
                    line = line.strip()
                    if not line: continue
                    if line == "Checking for values missing from Sample:": print("     "+line)
                    elif line.startswith("- Nothing missing from "): print("      - {}None{}".format(self.c["g"],self.c["c"]))
                    else:
                        oc_diff = True # Retain differences
                        print("      - {}{}{}".format(self.c["r"],line,self.c["c"]))
        # Reset our EFI to its original state
        if not efi_mounted:
            if oc_diff and not self.settings.get("occ_unmount",False):
                print("Leaving EFI mounted due to config.plist differences...")
            else:
                print("Unmounting EFI...")
                self.d.unmount_partition(efi)
        print("")
        print("Done.")
        print("")
        exit()

if __name__ == '__main__':
    h = HackUpdate(settings="./Scripts/settings.json")
    h.main()
