#!/bin/bash

echo "Disk Info Summary:"

# Get all disks (including partitions and images)
disks=$(diskutil list | grep '^/dev/disk' | awk '{print $1}')

for disk in $disks; do
  # Get the device type (Whole disk or Partition)
  deviceType=$(diskutil info "$disk" | grep "Device Type" | cut -d':' -f2 | xargs)
  
  # Get the media name or description
  mediaName=$(diskutil info "$disk" | grep -E "Device / Media Name|Volume Name" | head -1 | cut -d':' -f2 | xargs)
  
  # Get protocol (USB, SATA, etc.)
  protocol=$(diskutil info "$disk" | grep "Protocol" | cut -d':' -f2 | xargs)
  
  # Determine if USB
  if [[ "$protocol" == *USB* ]]; then
    usbStatus="Yes"
  else
    usbStatus="No"
  fi
  
  # Get disk size (for whole disks) or volume size (for partitions)
  size=$(diskutil info "$disk" | grep -E "Disk Size|Volume Total Size" | head -1 | cut -d':' -f2 | xargs)
  
  # Get mount point if available
  mountPoint=$(diskutil info "$disk" | grep "Mount Point" | cut -d':' -f2 | xargs)
  if [ -z "$mountPoint" ]; then
    mountPoint="Not Mounted"
  fi
  
  # Simplify Disk Type: Physical Disk, Partition, or Disk Image
  if [[ "$mediaName" == "Disk Image" ]]; then
    diskType="Disk Image"
  elif [[ "$deviceType" == "Partition" ]]; then
    diskType="Partition"
  else
    diskType="Physical Disk"
  fi
  
  echo "Disk: $disk"
  echo "  Type: $diskType"
  echo "  Name: $mediaName"
  echo "  Size: $size"
  echo "  Mount Point: $mountPoint"
  echo "  USB Drive: $usbStatus"
  echo ""
done
