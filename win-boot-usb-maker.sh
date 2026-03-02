#!/bin/bash
#Keep the Windows ISO file in the same directory as this script
#This script comes with NO GUARANTEE, USE AT YOUR OWN RISK

set -e

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root (e.g., using sudo)."
  exit 1
fi

# Get the directory where the script is currently located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

echo "Scanning for Windows ISO in: $SCRIPT_DIR"

# Find all .iso files in the script's directory
mapfile -t ISO_FILES < <(find "$SCRIPT_DIR" -maxdepth 1 -type f -name "*.iso")

if [ ${#ISO_FILES[@]} -eq 0 ]; then
  echo "Error: No .iso files found in $SCRIPT_DIR."
  echo "Please place your Windows ISO in the same folder as this script and try again."
  exit 1
elif [ ${#ISO_FILES[@]} -eq 1 ]; then
  ISO_PATH="${ISO_FILES[0]}"
  echo "=> Auto-selected ISO: $(basename "$ISO_PATH")"
else
  echo "Multiple ISO files found. Please select which one to use:"
  select ISO_SEL in "${ISO_FILES[@]}"; do
    if [ -n "$ISO_SEL" ]; then
      ISO_PATH="$ISO_SEL"
      echo "=> Selected ISO: $(basename "$ISO_PATH")"
      break
    else
      echo "Invalid selection. Please pick a number from the list."
    fi
  done
fi

echo ""
echo "Scanning for attached USB drives..."

# Detect USB drives using lsblk
mapfile -t USB_DRIVES < <(lsblk -d -n -p -o NAME,TRAN | awk '$2=="usb"{print $1}')

if [ ${#USB_DRIVES[@]} -eq 0 ]; then
    echo "Error: No USB drives detected."
    exit 1
fi

echo "Available USB drives:"
# Create a selection menu for the user
select TARGET in "${USB_DRIVES[@]}"; do
    if [ -n "$TARGET" ]; then
        break
    else
        echo "Invalid selection. Please pick a number from the list."
    fi
done

# Calculate partition names
PART1="${TARGET}1"
PART2="${TARGET}2"

echo ""
echo "################################################################"
echo " WARNING: ALL DATA ON $TARGET WILL BE PERMANENTLY ERASED!"
echo "################################################################"
read -p "Are you absolutely sure you want to format $TARGET? (y/N): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Operation aborted by user."
    exit 0
fi

echo ""
echo "=> Checking if $TARGET or its partitions are mounted..."
# Find any mounted partitions belonging to the selected target drive
MOUNTED_PARTS=$(lsblk -l -n -o NAME,MOUNTPOINT "$TARGET" | awk '$2 != "" {print "/dev/"$1}')

if [ -n "$MOUNTED_PARTS" ]; then
    echo "=> Unmounting active partitions on $TARGET..."
    for part in $MOUNTED_PARTS; do
        echo "   Unmounting $part"
        umount "$part"
    done
else
    echo "=> No active mounts found on $TARGET."
fi

echo "=> Wiping the USB drive..."
wipefs -a "$TARGET"

echo "=> Partitioning $TARGET (GPT, BOOT: 1GiB FAT32, INSTALL: Remaining space NTFS)..."
parted -s "$TARGET" mklabel gpt
parted -s "$TARGET" mkpart BOOT fat32 0% 1GiB
parted -s "$TARGET" mkpart INSTALL ntfs 1GiB 100%
parted "$TARGET" unit B print

echo "=> Setting up mount directories..."
mkdir -p /mnt/iso
mkdir -p /mnt/vfat
mkdir -p /mnt/ntfs

echo "=> Mounting Windows ISO..."
mount -o loop "$ISO_PATH" /mnt/iso/

echo "=> Formatting and mounting 1st partition (BOOT) as FAT32..."
mkfs.vfat -n BOOT "$PART1"
mount "$PART1" /mnt/vfat/

echo "=> Copying files to BOOT partition (excluding 'sources')..."
rsync -r --progress --exclude sources --delete-before /mnt/iso/ /mnt/vfat/

echo "=> Copying boot.wim to BOOT partition..."
mkdir -p /mnt/vfat/sources
cp /mnt/iso/sources/boot.wim /mnt/vfat/sources/

echo "=> Formatting and mounting 2nd partition (INSTALL) as NTFS..."
mkfs.ntfs --quick -L INSTALL "$PART2"
mount "$PART2" /mnt/ntfs/

echo "=> Copying everything to INSTALL partition..."
rsync -r --progress --delete-before /mnt/iso/ /mnt/ntfs/

echo "=> Unmounting drives and syncing..."
umount /mnt/ntfs
umount /mnt/vfat
umount /mnt/iso
sync

echo "=> Cleaning up mount directories..."
rmdir /mnt/ntfs /mnt/vfat /mnt/iso

echo "=> Powering off the USB flash drive..."
udisksctl power-off -b "$TARGET"

echo ""
echo "✅ Success! Your Windows bootable USB is ready and the system is cleaned up."
