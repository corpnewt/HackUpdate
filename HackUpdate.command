#!/usr/bin/env python
# 0.0.0
from Scripts import *
import os, sys, json

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
                "disk" : "clover", # clover, boot, or the mount point/disk identifier
                "lnf"  : "../Lilu-and-Friends",
                "lnfrun" : "Run.command",
                "lnf_args" : ["-p", "Default"],
                "ke" : "../KextExtractor",
                "kerun" : "KextExtractor.command",
                "ce" : "../CloverExtractor",
                "cerun" : "CloverExtractor.command",
                "ce_args" : ["build"]
            }
        os.chdir(cwd)

    def main(self):
        self.u.head("HackUpdate")
        print("")
        print("Finding EFI...")
        if self.settings.get("disk","clover").lower() == "clover":
            efi = self.d.get_efi(bdmesg.get_clover_uuid())
        elif self.settings.get("disk","clover").lower() == "boot":
            efi = self.d.get_efi("/")
        else:
            efi = self.d.get_efi(self.settings.get("disk","clover"))
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
        ce  = os.path.realpath(self.settings.get("ce","../CloverExtractor"))
        ke  = os.path.realpath(self.settings.get("ke","../KextExtractor"))
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
                    os.remove(os.path.join(lnf, "Kexts", x))
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
        print("\n".join([" ----> {}".format(x) for x in kextout["succeeded"]]))
        print(" --> Failed:")
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
        
        # Let's get our clover
        print("Locating CloverExtractor...")
        if os.path.exists(ce):
            print(" - Located at {}".format(ce))
        else:
            print(" - Unable to locate!")
            exit(1)
        print(" - Gathering/building and extracting Clover...")
        args = [os.path.join(ce, self.settings.get("cerun","CloverExtractor.command"))]
        args.extend(self.settings.get("ce_args",[]))
        args.append(efi)
        out = self.r.run({"args":args})

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