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

    def get_clover_version(self, path):
        vers_hex = "Clover revision: ".encode("utf-8")
        vers_add = len(vers_hex)
        with open(path, "rb") as f:
            s = f.read()
        location = s.find(vers_hex)
        if location == -1:
            return None
        location += vers_add
        version = ""
        while True:
            try:
                vnum = s[location:location+1].decode("utf-8")
                numtest = int(vnum)
                version += vnum
            except:
                break
            location += 1
        if not len(version):
            return None
        return version

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

        # Save our current Clover version
        print("Locating existing Clover...")
        efi_path = self.d.get_mount_point(efi)
        clover_path = os.path.join(efi_path, "EFI", "CLOVER", "CLOVERX64.efi")
        if not os.path.exists(clover_path):
            print(" - Unable to locate!")
            exit(1)
        print(" - Located at {}".format(clover_path))
        # Get the version
        print("Resolving Clover version...")
        clover_version = self.get_clover_version(clover_path)
        if not clover_version:
            print(" - Unable to determine, continuing...")
        else:
            print(" - Located Clover v{}".format(clover_version))

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

        # Check for any failures
        fails = [x for x in out[0].split("\n") if "fail" in x.lower()]
        # Check for built clover version
        built = [x for x in out[0].split("\n") if "built clover" in x.lower()]
        # Check for copied efi drivers
        efis  = [x for x in out[0].split("\n") if "found" in x.lower() and "efi driver" in x.lower()]
        # Check for listed replaced efi drivers
        # refis = [x for x in out[0].split("\n") if " replacing " in x.lower()]

        # Print the results if any
        if len(fails):
            for x in fails:
                print(" --> {}".format(x))
        if len(built):
            for x in built:
                print(" --> {}".format(x))
        if len(efis):
            for x in efis:
                print(" --> {}".format(x.split(" - ")[0].replace("Found","Updated")))
        '''if len(refis):
            for x in refis:
                print(" --> {}".format(x.replace(" Replacing","Replaced").replace("...","")))'''

        # Check if the version is different
        print("Checking final Clover version...")
        clover_new = self.get_clover_version(clover_path)
        if not clover_new:
            print(" - Unable to determine, something may have gone wrong updating!")
        else:
            if clover_new == clover_version:
                print(" - Clover version still v{}, something may have gone wrong updating!".format(clover_version))
            else:
                print(" - Clover version went from v{} --> v{}".format(clover_version, clover_new))

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
