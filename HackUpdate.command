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
                "oc_args" : ["-disk"]
            }
        os.chdir(cwd)

    def main(self):
        self.u.head("HackUpdate")
        print("")
        print("Finding EFI...")
        if self.settings.get("disk","bootloader").lower() == "bootloader":
            efi = self.d.get_efi(bdmesg.get_bootloader_uuid())
        elif self.settings.get("disk","bootloader").lower() == "boot":
            efi = self.d.get_efi("/")
        else:
            efi = self.d.get_efi(self.settings.get("disk","bootloader"))
        if not efi:
            print(" - Unable to locate!")
            exit(1)
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
        os.chdir(cwd)
        if os.path.exists(lnf):
            print(" - Located at {}".format(lnf))
        else:
            print(" - Unable to locate!")
            exit(1)
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
        if os.path.exists(ke):
            print(" - Located at {}".format(ke))
        else:
            print(" - Unable to locate!")
            exit(1)
        print(" - Extracting kexts...")
        out = self.r.run({"args":[
            os.path.join(ke, self.settings.get("kerun","KextExtractor.command")),
            os.path.join(lnf, "Kexts"),
            efi
        ]})

        efi_path = self.d.get_mount_point(efi)
        oc_path = os.path.join(efi_path,"EFI","OC","OpenCore.efi")
        if os.path.exists(oc_path):
            print("Located existing OC...")
            # Let's get our OC
            print("Locating OC-Update...")
            if os.path.exists(oc):
                print(" - Located at {}".format(oc))
            else:
                print(" - Unable to locate!")
                exit(1)
            print(" - Gathering/building and updating OC...")
            args = [os.path.join(oc, self.settings.get("ocrun","OC-Update.command"))]
            args.extend(self.settings.get("oc_args",[]))
            args.append(efi)
            out = self.r.run({"args":args})

        # Reset our EFI to its original state
        if not efi_mounted:
            print("Unmounting EFI...")
            self.d.unmount_partition(efi)
        print("")
        print("Done.")
        print("")
        exit()

if __name__ == '__main__':
    h = HackUpdate(settings="./Scripts/settings.json")
    h.main()
