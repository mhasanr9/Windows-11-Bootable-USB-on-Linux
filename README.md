# Bootable Windows USB Creator for Linux

A straightforward and robust Bash script to automate the creation of a UEFI-compatible bootable Windows USB drive natively on Linux.

Modern Windows ISOs contain an `install.wim` file that exceeds the 4GB file size limit of the FAT32 filesystem. This script bypasses that limitation by automatically partitioning your USB drive into two segments: a small FAT32 partition for the bootloader, and a larger NTFS partition for the actual installation files.

## ✨ Features

* **Auto-Detects ISOs:** Scans the directory it's run from for a Windows `.iso` file. If multiple are found, it presents a menu to choose the correct one.
* **Safe Device Selection:** Uses `lsblk` to exclusively list attached USB drives, preventing you from accidentally wiping your main system drives.
* **Pre-Format Safety Check:** Automatically detects if the selected USB drive is currently mounted and safely unmounts it before wiping.
* **Handles Large Files:** Automatically splits the drive into a 1GiB FAT32 `BOOT` partition and an NTFS `INSTALL` partition for the rest of the space.
* **Automatic Cleanup:** Removes temporary mount directories (`/mnt/iso`, `/mnt/vfat`, `/mnt/ntfs`) and powers down the USB port upon successful completion.

## 🛠️ Prerequisites

This script requires a few standard Linux utilities to handle partitioning and formatting. Make sure they are installed on your system before running:

* `parted` (for GPT partitioning)
* `rsync` (for copying files with progress)
* `dosfstools` (provides `mkfs.vfat`)
* `ntfs-3g` (provides `mkfs.ntfs`)
* `udisks2` (provides `udisksctl` for safe power-off)

*On Debian/Ubuntu-based systems, you can install missing tools with:*
`sudo apt install parted rsync dosfstools ntfs-3g udisks2`

## 🚀 Usage

1. **Download the script** and place it in a folder on your computer.
2. **Move your Windows `.iso` file** into the exact same folder as the script.
3. Open your terminal in that folder and **make the script executable**:
```bash
chmod +x make-win-usb.sh

```


4. **Run the script with root privileges**:
```bash
sudo ./win-boot-usb-maker.sh

```


5. Follow the on-screen prompts to select your USB drive and confirm the wipe.

## 📝 License

This project is open-source and available under the MIT License.
