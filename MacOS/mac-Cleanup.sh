#!/bin/bash

# Safe Mac Cleanup Script for MSP Deployment
# Version 1.0 - Conservative approach with safety checks

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_FILE="/tmp/mac_cleanup_$(date +%Y%m%d_%H%M%S).log"
readonly DRY_RUN=false  # Set to true to test without actually deleting
readonly MIN_FREE_SPACE_GB=5  # Don't run if less than 5GB free space
readonly MAX_CACHE_AGE_DAYS=30  # Only clean files older than 30 days
readonly MAX_LOG_AGE_DAYS=14   # Only clean logs older than 14 days

# Logging function
log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

# Check if we have enough free space to proceed safely
check_disk_space() {
    local available_gb
    available_gb=$(df -g / | awk 'NR==2 {print $4}')
    
    if [[ $available_gb -lt $MIN_FREE_SPACE_GB ]]; then
        log "ERROR: Only ${available_gb}GB free space. Minimum ${MIN_FREE_SPACE_GB}GB required."
        exit 1
    fi
    
    log "Disk space check passed: ${available_gb}GB available"
}

# Safe delete function with age check and dry run support
safe_delete() {
    local path="$1"
    local max_age_days="$2"
    local description="$3"
    
    if [[ ! -d "$path" ]]; then
        log "Skipping $description - directory not found: $path"
        return
    fi
    
    log "Processing $description: $path"
    
    # Find and count files older than specified days
    local file_count
    file_count=$(find "$path" -type f -mtime +$max_age_days 2>/dev/null | wc -l || echo "0")
    
    if [[ $file_count -eq 0 ]]; then
        log "No files older than $max_age_days days found in $path"
        return
    fi
    
    log "Found $file_count files older than $max_age_days days"
    
    if [[ $DRY_RUN == true ]]; then
        log "DRY RUN: Would delete $file_count files from $path"
        find "$path" -type f -mtime +$max_age_days 2>/dev/null | head -5 | while read -r file; do
            log "DRY RUN: Would delete: $file"
        done
    else
        # Calculate space that will be freed
        local space_to_free
        space_to_free=$(find "$path" -type f -mtime +$max_age_days -exec du -sk {} + 2>/dev/null | awk '{sum+=$1} END {print sum/1024}' || echo "0")
        
        # Actually delete the files
        local deleted_count=0
        find "$path" -type f -mtime +$max_age_days 2>/dev/null | while read -r file; do
            if rm -f "$file" 2>/dev/null; then
                ((deleted_count++))
            fi
        done
        
        log "Cleaned $description: ${space_to_free}MB freed"
    fi
}

# Check if application is running
is_app_running() {
    local app_name="$1"
    pgrep -f "$app_name" >/dev/null 2>&1
}

# Main cleanup function
perform_cleanup() {
    log "Starting Mac cleanup process..."
    
    # Get current user's home directory
    local user_home
    user_home=$(eval echo ~$USER)
    
    # Browser caches (only if browsers aren't running)
    if ! is_app_running "Google Chrome"; then
        safe_delete "$user_home/Library/Caches/com.google.Chrome" $MAX_CACHE_AGE_DAYS "Chrome Cache"
        safe_delete "$user_home/Library/Application Support/Google/Chrome/Default/GPUCache" $MAX_CACHE_AGE_DAYS "Chrome GPU Cache"
    else
        log "Skipping Chrome cache - Chrome is running"
    fi
    
    if ! is_app_running "Safari"; then
        safe_delete "$user_home/Library/Caches/com.apple.Safari" $MAX_CACHE_AGE_DAYS "Safari Cache"
    else
        log "Skipping Safari cache - Safari is running"
    fi
    
    if ! is_app_running "Firefox"; then
        safe_delete "$user_home/Library/Caches/Firefox" $MAX_CACHE_AGE_DAYS "Firefox Cache"
    else
        log "Skipping Firefox cache - Firefox is running"
    fi
    
    # System caches (safe locations only)
    safe_delete "$user_home/Library/Caches" $MAX_CACHE_AGE_DAYS "User Library Caches"
    
    # User logs (not system logs)
    safe_delete "$user_home/Library/Logs" $MAX_LOG_AGE_DAYS "User Application Logs"
    
    # Temporary files in user directory only
    safe_delete "/tmp" 1 "Temporary Files (1+ days old)"
    
    # Font caches (safe to regenerate)
    if [[ -d "$user_home/Library/Caches/com.apple.ATS" ]]; then
        log "Clearing font caches..."
        if [[ $DRY_RUN == false ]]; then
            atsutil databases -remove 2>/dev/null || log "Warning: Could not clear font cache"
        else
            log "DRY RUN: Would clear font caches"
        fi
    fi
    
    # Empty user's Trash (with confirmation in production)
    local trash_items
    trash_items=$(find "$user_home/.Trash" -mindepth 1 2>/dev/null | wc -l || echo "0")
    
    if [[ $trash_items -gt 0 ]]; then
        log "Found $trash_items items in Trash"
        # Only empty trash for items older than 7 days to be extra safe
        safe_delete "$user_home/.Trash" 7 "Trash (7+ days old)"
    else
        log "Trash is already empty"
    fi
}

# Summary report
generate_report() {
    log "=== Cleanup Summary ==="
    log "Script: $SCRIPT_NAME"
    log "Mode: $([ $DRY_RUN == true ] && echo 'DRY RUN' || echo 'LIVE')"
    log "Log file: $LOG_FILE"
    
    # Show disk space after cleanup
    local available_gb_after
    available_gb_after=$(df -g / | awk 'NR==2 {print $4}')
    log "Available disk space: ${available_gb_after}GB"
    
    # Offer to show full log
    if [[ -f "$LOG_FILE" ]]; then
        log "Full cleanup log saved to: $LOG_FILE"
    fi
}

# Error handling
trap 'log "ERROR: Script failed at line $LINENO"' ERR

# Main execution
main() {
    log "=== Starting Safe Mac Cleanup ==="
    log "User: $USER"
    log "Hostname: $(hostname)"
    log "macOS Version: $(sw_vers -productVersion)"
    
    check_disk_space
    perform_cleanup
    generate_report
    
    log "=== Cleanup completed successfully ==="
}

# Run main function
main "$@"