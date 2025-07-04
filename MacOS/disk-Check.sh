#!/bin/bash

# Function to convert size strings to GB
convert_to_gb() {
    local size_str="$1"
    local size_num=$(echo "$size_str" | sed 's/[^0-9.]//g')
    local size_unit=$(echo "$size_str" | sed 's/[0-9.]//g' | tr '[:lower:]' '[:upper:]')
    
    if [[ -z "$size_num" ]]; then
        echo "0"
        return
    fi
    
    case "$size_unit" in
        "K"|"KB")
            echo "scale=2; $size_num / 1024 / 1024" | bc
            ;;
        "M"|"MB")
            echo "scale=2; $size_num / 1024" | bc
            ;;
        "G"|"GB"|"GI"|"GIB")
            echo "$size_num"
            ;;
        "T"|"TB"|"TI"|"TIB")
            echo "scale=2; $size_num * 1024" | bc
            ;;
        *)
            # Assume bytes if no unit
            echo "scale=2; $size_num / 1024 / 1024 / 1024" | bc
            ;;
    esac
}

# Function to safely get volume usage
get_volume_usage() {
    local volume_path="$1"
    local usage=$(df -h "$volume_path" 2>/dev/null | tail -n 1 | awk '{print $3}')
    
    if [[ -z "$usage" ]]; then
        echo "0"
    else
        convert_to_gb "$usage"
    fi
}

# Function to validate if a value is a valid number
is_valid_number() {
    [[ $1 =~ ^[0-9]+(\.[0-9]+)?$ ]]
}

echo "macOS Disk Usage Analysis"
echo "========================="

# Get the total disk size from root volume
total_disk_info=$(df -h / | tail -n 1)
total_disk_size=$(echo "$total_disk_info" | awk '{print $2}')
total_disk_size_gb=$(convert_to_gb "$total_disk_size")

echo "Total Disk Size: $total_disk_size ($total_disk_size_gb GB)"
echo ""

# Get usage from different volumes
echo "Analyzing volumes..."

# Data volume
used_data_raw=$(get_volume_usage "/System/Volumes/Data")
echo "Data volume usage: $used_data_raw GB"

# VM volume (may not exist on all systems)
if df "/System/Volumes/VM" &>/dev/null; then
    used_vm_raw=$(get_volume_usage "/System/Volumes/VM")
    echo "VM volume usage: $used_vm_raw GB"
else
    used_vm_raw="0"
    echo "VM volume: Not found or not accessible (using 0 GB)"
fi

# Preboot volume
if df "/System/Volumes/Preboot" &>/dev/null; then
    used_preboot_raw=$(get_volume_usage "/System/Volumes/Preboot")
    echo "Preboot volume usage: $used_preboot_raw GB"
else
    used_preboot_raw="0"
    echo "Preboot volume: Not found or not accessible (using 0 GB)"
fi

# Validate all values are numbers
for vol_name in "Data" "VM" "Preboot"; do
    case $vol_name in
        "Data") val="$used_data_raw" ;;
        "VM") val="$used_vm_raw" ;;
        "Preboot") val="$used_preboot_raw" ;;
    esac
    
    if ! is_valid_number "$val"; then
        echo "Error: Invalid used space value for $vol_name volume: '$val'"
        exit 1
    fi
done

echo ""
echo "Calculating cache usage..."

# Function to safely get directory size
get_dir_size() {
    local dir_path="$1"
    if [[ -d "$dir_path" ]]; then
        local size=$(sudo du -sh "$dir_path" 2>/dev/null | awk '{print $1}')
        if [[ -n "$size" ]]; then
            convert_to_gb "$size"
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

# Calculate cache usage
cache_usage_system=$(get_dir_size "/System/Library/Caches")
cache_usage_var_folders=$(get_dir_size "/var/folders")
cache_usage_user=$(get_dir_size "$HOME/Library/Caches")

echo "System caches: $cache_usage_system GB"
echo "Var folders: $cache_usage_var_folders GB"
echo "User caches: $cache_usage_user GB"

# Calculate totals
total_used_space=$(echo "$used_data_raw + $used_vm_raw + $used_preboot_raw" | bc)
total_cache_usage=$(echo "$cache_usage_system + $cache_usage_var_folders + $cache_usage_user" | bc)
adjusted_used_space=$(echo "$total_used_space - $total_cache_usage" | bc)

# Ensure adjusted space isn't negative
if (( $(echo "$adjusted_used_space < 0" | bc -l) )); then
    adjusted_used_space="$total_used_space"
    echo "Note: Cache calculation resulted in negative space, using total without cache adjustment"
fi

# Calculate percentages
used_percentage=$(echo "scale=2; ($total_used_space / $total_disk_size_gb) * 100" | bc)
adjusted_percentage=$(echo "scale=2; ($adjusted_used_space / $total_disk_size_gb) * 100" | bc)

echo ""
echo "Final Results:"
echo "============="
echo "Total Disk Size: $total_disk_size ($total_disk_size_gb GB)"
echo "Total Used Space: $total_used_space GB ($used_percentage%)"
echo "Total Cache Usage: $total_cache_usage GB"
echo "Adjusted Used Space (excluding caches): $adjusted_used_space GB ($adjusted_percentage%)"
echo ""
echo "Space breakdown:"
echo "- Data volume: $used_data_raw GB"
echo "- VM volume: $used_vm_raw GB"
echo "- Preboot volume: $used_preboot_raw GB"
echo "- Total caches: $total_cache_usage GB"