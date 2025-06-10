#!/bin/bash

# Enhanced Cisco Secure Installer with robust download functionality
# Blends NinjaOne download methods with Cisco Secure installation

ninjaCLI="/Applications/NinjaRMMAgent/programdata/ninjarmm-cli"
docTemplate="Automation"
warnFlag=0

# Check NinjaOne CLI and retrieve custom fields
if [ ! -x "$ninjaCLI" ]; then
    echo "ERROR: ninjarmm-cli not found or not executable at $ninjaCLI"
    echo "WARNING: Ninja agent may be encountering an error. Try opening a terminal in Ninja, and if that fails reboot the system."
    warnFlag=1
else
    orgid=$("$ninjaCLI" get "$docTemplate" "ciscoSecureOrgid" 2>/dev/null)
    fprint=$("$ninjaCLI" get "$docTemplate" "ciscoSecureFingerprint" 2>/dev/null)
    userid=$("$ninjaCLI" get "$docTemplate" "ciscoSecureUserid" 2>/dev/null)
    if [ -z "$orgid" ] || [ -z "$fprint" ] || [ -z "$userid" ] || \
       echo "$orgid $fprint $userid" | grep -qi "unable to establish ipc"; then
        echo "WARNING: One or more Cisco custom fields are missing or ninja agent communication failed."
        echo "WARNING: Ninja agent may be encountering an error. Try opening a terminal in Ninja, and if that fails reboot the system."
        warnFlag=1
    fi
    echo "Cisco Secure OrgID: ${orgid:-<not set>}"
    echo "Cisco Secure Fingerprint: ${fprint:-<not set>}"
    echo "Cisco Secure UserID: ${userid:-<not set>}"
fi

# Enhanced download function (from NinjaOne script)
function robust_download() {
    local url=$1
    local save_path=$2

    echo "Attempting to download from: $url"
    echo "Saving to: $save_path"

    # Validate and create path if needed
    local path_check_regex='^(/[^/ ]*)+/?$'
    if [[ "${save_path}" =~ ${path_check_regex} ]]; then
        echo "Path validation passed."
        local folder=$(dirname "${save_path}")
        if [[ -d "${folder}" ]]; then
            echo "Directory ${folder} exists"
        else
            echo "Creating directory: ${folder}"
            mkdir -p -v "${folder}"
            if [ ! -d "${folder}" ]; then
                echo "ERROR: Failed to create directory ${folder}"
                return 1
            fi
        fi
    else
        echo "ERROR: Invalid path format: $save_path"
        return 1
    fi

    # Try wget first, then curl
    if command -v wget >/dev/null 2>&1; then
        echo "Downloading using wget..."
        wget --timeout=30 --tries=3 -O "$save_path" "$url"
        local download_result=$?
    elif command -v curl >/dev/null 2>&1; then
        echo "Downloading using curl..."
        curl --connect-timeout 30 --max-time 300 --retry 3 --retry-delay 5 -L -o "$save_path" "$url"
        local download_result=$?
    else
        echo "ERROR: Neither wget nor curl found. Cannot download file."
        return 1
    fi

    if [ $download_result -ne 0 ]; then
        echo "ERROR: Download failed with exit code $download_result"
        return 1
    fi

    if [ ! -f "$save_path" ]; then
        echo "ERROR: Download appeared successful but file not found at $save_path"
        return 1
    fi

    local file_size=$(stat -f%z "$save_path" 2>/dev/null || echo "0")
    if [ "$file_size" -eq 0 ]; then
        echo "ERROR: Downloaded file is empty"
        rm -f "$save_path"
        return 1
    fi

    echo "Download successful. File size: $file_size bytes"
    return 0
}

# --- Cisco Secure DMG Installation ---
dmgURL="https://athensmicro-my.sharepoint.com/:u:/p/automations/EQ1knsl3asdEsImnHDkXHvUBXB0j0Sv10AE67zgV4X_kdQ?download=1"
downloadPath="/tmp/CiscoSecureInstaller.dmg"
mountPoint="/Volumes/CiscoSecureInstaller"

echo "Starting Cisco Secure DMG download and installation..."

# Use the robust download function
if ! robust_download "$dmgURL" "$downloadPath"; then
    echo "ERROR: Failed to download Cisco Secure DMG."
    exit 10
fi

echo "Successfully downloaded DMG. Proceeding with installation..."

# Mount the DMG
echo "Mounting DMG..."
if ! hdiutil attach "$downloadPath" -mountpoint "$mountPoint" -nobrowse -quiet; then
    echo "ERROR: Failed to mount DMG."
    rm -f "$downloadPath"
    exit 11
fi

# Find the package inside the DMG
echo "Looking for package inside DMG..."
pkgPath=$(find "$mountPoint" -name "*.pkg" -maxdepth 1)
if [ -z "$pkgPath" ]; then
    echo "ERROR: No .pkg found inside DMG."
    hdiutil detach "$mountPoint" -quiet
    rm -f "$downloadPath"
    exit 12
fi

echo "Found package: $pkgPath"

# Install the package
echo "Installing package..."
if ! sudo installer -pkg "$pkgPath" -target /; then
    echo "ERROR: Package installation failed."
    hdiutil detach "$mountPoint" -quiet
    rm -f "$downloadPath"
    exit 13
fi

# Cleanup
echo "Installation successful. Cleaning up..."
hdiutil detach "$mountPoint" -quiet
rm -f "$downloadPath"

# Final status report
if [ $warnFlag -eq 1 ]; then
    echo "NOTE: Installation completed but there were issues retrieving NinjaOne custom fields."
    echo "Please check NinjaOne agent status and consider rebooting the machine if issues persist."
fi

echo "Cisco Secure installed successfully."
exit 0