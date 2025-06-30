#!/bin/bash

# Exit on any error
set -e

export HOME="/var/root"

if test ! $(which brew 2>/dev/null); then
  echo "Homebrew not found. Installing Homebrew..."
  
  # Create a non-root user temporarily for Homebrew installation
  NON_ROOT_USER="amcmdm"

  # Check if user already exists
  if ! id $NON_ROOT_USER &>/dev/null; then
    echo "Creating temporary user: $NON_ROOT_USER"
    # Create a temporary user for installation using dscl (macOS)
    dscl . -create /Users/$NON_ROOT_USER
    dscl . -create /Users/$NON_ROOT_USER UserShell /bin/bash
    dscl . -create /Users/$NON_ROOT_USER RealName "Athens Micro"
    dscl . -create /Users/$NON_ROOT_USER UniqueID "1010"
    dscl . -create /Users/$NON_ROOT_USER PrimaryGroupID 20
    dscl . -create /Users/$NON_ROOT_USER NFSHomeDirectory /Users/$NON_ROOT_USER
    
    # Create a home directory for the user
    mkdir -p /Users/$NON_ROOT_USER
    chown -R $NON_ROOT_USER:staff /Users/$NON_ROOT_USER
  else
    echo "User $NON_ROOT_USER already exists"
  fi

  # Grant the temporary user sudo access (check if already exists)
  if ! grep -q "$NON_ROOT_USER ALL=(ALL) NOPASSWD: ALL" /etc/sudoers; then
    echo "$NON_ROOT_USER ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
  fi

  # Ensure proper permissions for Homebrew directories
  echo "Ensuring proper permissions for Homebrew directories..."
  sudo mkdir -p /usr/local/var/homebrew/locks
  sudo chown -R amcmdm:admin /usr/local/var/homebrew
  sudo chmod -R u+rwx /usr/local/var/homebrew
  
  # Create and set permissions for root's Library directories
  mkdir -p /var/root/Library/Caches/Homebrew
  mkdir -p /var/root/.config/git
  
  # Set ownership to the temporary user for installation
  chown -R $NON_ROOT_USER:staff /var/root/Library
  chown -R $NON_ROOT_USER:staff /var/root/.config
  
  # Create profile files with proper ownership
  touch /var/root/.bash_profile /var/root/.zshrc
  chown $NON_ROOT_USER:staff /var/root/.bash_profile /var/root/.zshrc
  chmod 644 /var/root/.bash_profile /var/root/.zshrc
  
  # Also create the user's profile files
  sudo -u $NON_ROOT_USER touch /Users/$NON_ROOT_USER/.bash_profile /Users/$NON_ROOT_USER/.zshrc
  
  # Set HOMEBREW environment variables for the installation
  export HOMEBREW_CACHE="/var/root/Library/Caches/Homebrew"
  


  # Install Homebrew as the non-root user with proper environment
  echo "Installing Homebrew..."
  sudo -u $NON_ROOT_USER -H bash -c "
    export HOME=/Users/$NON_ROOT_USER
    export HOMEBREW_CACHE=/var/root/Library/Caches/Homebrew
    /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\" && \
    brew update && \
    brew doctor
  "

  # After installation, set proper ownership for ALL Homebrew directories
  echo "Setting up ownership and permissions post-installation..."
  
  # CRITICAL: Set ownership for ALL Homebrew directories to root for consistent access
  # Main Homebrew installation
  chown -R root:admin /usr/local/Homebrew
  chmod -R g+rwx /usr/local/Homebrew
  
  # Core directories that Homebrew uses for packages
  for dir in /usr/local/bin /usr/local/lib /usr/local/include /usr/local/share /usr/local/opt /usr/local/Cellar /usr/local/etc /usr/local/var; do
    if [ -d "$dir" ]; then
      echo "Setting ownership for $dir"
      chown -R root:admin "$dir"
      chmod -R g+rwx "$dir"
    else
      echo "Creating and setting ownership for $dir"
      mkdir -p "$dir"
      chown -R root:admin "$dir"
      chmod -R 755 "$dir"
    fi
  done
  
  # Ensure specific critical files are properly owned
  if [ -f /usr/local/bin/brew ]; then
    chown root:admin /usr/local/bin/brew
    chmod 755 /usr/local/bin/brew
  fi
  
  # Set ownership for cache directories back to root
  chown -R root:admin /var/root/Library
  chmod -R 755 /var/root/Library
  
  # Configure PATH system-wide
  if ! grep -q "/usr/local/bin" /etc/paths; then
    echo "/usr/local/bin" | sudo tee -a /etc/paths
  fi

  # Test the installation
  export PATH="/usr/local/bin:$PATH"
  if /usr/local/bin/brew --version >/dev/null 2>&1; then
    BREW_VERSION=$(/usr/local/bin/brew --version | head -1)
    echo "Homebrew successfully installed: $BREW_VERSION"
  else
    echo "Error: Homebrew installation verification failed"
    exit 1
  fi
  
else
  echo "Homebrew is already installed"
  
  # Even if Homebrew exists, ensure proper ownership for package management
  echo "Ensuring proper ownership for existing Homebrew installation..."
  for dir in /usr/local/bin /usr/local/lib /usr/local/include /usr/local/share /usr/local/opt /usr/local/Cellar /usr/local/etc /usr/local/var /usr/local/Homebrew; do
    if [ -d "$dir" ]; then
      echo "Setting ownership for existing $dir"
      chown -R root:admin "$dir"
      chmod -R g+rwx "$dir"
    fi
  done
fi

# Configure Homebrew for root user (runs for both new installs and existing)
echo "=== Configuring Homebrew for root user ==="

# Ensure directories exist with proper permissions
mkdir -p /var/root/Library/Caches/Homebrew
mkdir -p /var/root/.config/git
chown -R root:admin /var/root/Library
chown -R root:admin /var/root/.config
chmod -R 755 /var/root/Library
chmod -R 755 /var/root/.config

# Create a brew wrapper script for root with comprehensive environment
echo "Creating brew wrapper script for root..."
cat > /usr/local/bin/brew-root << 'EOF'
#!/bin/bash
export HOME="/var/root"
export PATH="/usr/local/bin:$PATH"
export HOMEBREW_PREFIX="/usr/local"
export HOMEBREW_CELLAR="/usr/local/Cellar"
export HOMEBREW_REPOSITORY="/usr/local/Homebrew"
export HOMEBREW_CACHE="/var/root/Library/Caches/Homebrew"
export USER="root"
export LOGNAME="root"

# Ensure critical directories exist and have proper permissions before each brew command
for dir in "/usr/local/Cellar" "/usr/local/opt" "/usr/local/bin" "/usr/local/lib" "/usr/local/include" "/usr/local/share" "/usr/local/etc" "/usr/local/var"; do
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir"
    chown root:admin "$dir"
    chmod 755 "$dir"
  fi
done

exec /usr/local/bin/brew "$@"
EOF

chmod +x /usr/local/bin/brew-root
chown root:admin /usr/local/bin/brew-root
echo "Created /usr/local/bin/brew-root wrapper"

# Function to safely add line to file if it doesn't exist
add_to_profile() {
  local file="$1"
  local line="$2"
  local description="$3"
  
  # Create file if it doesn't exist
  touch "$file"
  chown root:admin "$file"
  chmod 644 "$file"
  
  if ! grep -Fq "$line" "$file" 2>/dev/null; then
    echo "$line" >> "$file"
    echo "Added $description to $(basename $file)"
  else
    echo "$description already exists in $(basename $file)"
  fi
}

# Add Homebrew configuration to root's bash profile
echo "Setting up bash profile..."
add_to_profile "/var/root/.bash_profile" 'export HOME="/var/root"' "HOME export"
add_to_profile "/var/root/.bash_profile" 'export PATH="/usr/local/bin:$PATH"' "PATH export"
add_to_profile "/var/root/.bash_profile" 'export HOMEBREW_CACHE="/var/root/Library/Caches/Homebrew"' "HOMEBREW_CACHE export"
add_to_profile "/var/root/.bash_profile" 'export USER="root"' "USER export"
add_to_profile "/var/root/.bash_profile" 'export LOGNAME="root"' "LOGNAME export"
add_to_profile "/var/root/.bash_profile" 'eval "$(/usr/local/bin/brew shellenv)"' "brew shellenv"

# Add Homebrew configuration to root's zsh profile
echo "Setting up zsh profile..."
add_to_profile "/var/root/.zshrc" 'export HOME="/var/root"' "HOME export"
add_to_profile "/var/root/.zshrc" 'export PATH="/usr/local/bin:$PATH"' "PATH export"
add_to_profile "/var/root/.zshrc" 'export HOMEBREW_CACHE="/var/root/Library/Caches/Homebrew"' "HOMEBREW_CACHE export"
add_to_profile "/var/root/.zshrc" 'export USER="root"' "USER export"
add_to_profile "/var/root/.zshrc" 'export LOGNAME="root"' "LOGNAME export"
add_to_profile "/var/root/.zshrc" 'eval "$(/usr/local/bin/brew shellenv)"' "brew shellenv"

# Create a global environment file for system-wide brew access
echo "Creating global environment configuration..."
cat > /etc/brew-env << 'EOF'
export HOME="/var/root"
export PATH="/usr/local/bin:$PATH"
export HOMEBREW_PREFIX="/usr/local"
export HOMEBREW_CELLAR="/usr/local/Cellar"
export HOMEBREW_REPOSITORY="/usr/local/Homebrew"
export HOMEBREW_CACHE="/var/root/Library/Caches/Homebrew"
export MANPATH="/usr/local/share/man${MANPATH+:$MANPATH}:" 
export INFOPATH="/usr/local/share/info:${INFOPATH:-}"
export USER="root"
export LOGNAME="root"
EOF

chmod 644 /etc/brew-env
echo "Created /etc/brew-env for global configuration"

# Set up environment for current session
echo "Setting up current session environment..."
export HOME="/var/root"
export PATH="/usr/local/bin:$PATH"
export HOMEBREW_PREFIX="/usr/local"
export HOMEBREW_CELLAR="/usr/local/Cellar"
export HOMEBREW_REPOSITORY="/usr/local/Homebrew"
export HOMEBREW_CACHE="/var/root/Library/Caches/Homebrew"
export USER="root"
export LOGNAME="root"


echo "=== Final verification and testing ==="

# Test brew command with explicit environment
if HOME="/var/root" PATH="/usr/local/bin:$PATH" HOMEBREW_CACHE="/var/root/Library/Caches/Homebrew" /usr/local/bin/brew --version >/dev/null 2>&1; then
  BREW_VERSION=$(HOME="/var/root" PATH="/usr/local/bin:$PATH" HOMEBREW_CACHE="/var/root/Library/Caches/Homebrew" /usr/local/bin/brew --version | head -1)
  echo "Homebrew installation and configuration completed successfully!"
  echo "   Homebrew version: $BREW_VERSION"
  
  # Test the wrapper script
  if /usr/local/bin/brew-root --version >/dev/null 2>&1; then
    echo "   Wrapper script working correctly"
  else
    echo "   WARNING: Wrapper script test failed"
  fi
  
  # Test package installation capability
  echo "Testing package installation capability..."
  if /usr/local/bin/brew-root install --dry-run wget >/dev/null 2>&1; then
    echo "   Package installation test passed (dry-run)"
  else
    echo "   WARNING: Package installation test failed"
  fi
  
  # Test brew doctor (non-fatal)
  echo "Running brew doctor..."
  if /usr/local/bin/brew-root doctor >/dev/null 2>&1; then
    echo "   Brew doctor passed"
  else
    echo "   Brew doctor found some issues (this is often normal for root installations)"
  fi
else
  echo "Error: Homebrew installed but verification failed."
  echo "Try running: HOME=\"/var/root\" PATH=\"/usr/local/bin:\$PATH\" HOMEBREW_CACHE=\"/var/root/Library/Caches/Homebrew\" /usr/local/bin/brew --version"
  exit 1
fi

# Test actual package functionality by installing a simple package
echo "=== Testing actual package installation ==="
echo "Installing 'jq' as a test package..."
if /usr/local/bin/brew-root install jq >/dev/null 2>&1; then
  echo "   Successfully installed jq"
  if /usr/local/bin/jq --version >/dev/null 2>&1; then
    echo "   jq is working and accessible in PATH"
  else
    echo "   WARNING: jq installed but not accessible in PATH"
  fi
else
  echo "   WARNING: Failed to install test package 'jq'"
  echo "   This may indicate permission issues that need to be resolved"
fi

echo "=== Cleaning up temporary user ==="
if id $NON_ROOT_USER &>/dev/null; then
  echo "Removing temporary user: $NON_ROOT_USER"
  
  # Remove from sudoers file
  if grep -q "$NON_ROOT_USER ALL=(ALL) NOPASSWD: ALL" /etc/sudoers; then
    echo "Removing sudo privileges..."
    # Create a temporary sudoers file without the user
    grep -v "$NON_ROOT_USER ALL=(ALL) NOPASSWD: ALL" /etc/sudoers > /tmp/sudoers_temp
    # Validate the sudoers file before replacing
    if visudo -c -f /tmp/sudoers_temp; then
      cp /tmp/sudoers_temp /etc/sudoers
      echo "   Removed sudo privileges for $NON_ROOT_USER"
    else
      echo "   WARNING: Failed to safely remove sudo privileges"
    fi
    rm -f /tmp/sudoers_temp
  fi
  
  # Remove user's home directory
  if [ -d "/Users/$NON_ROOT_USER" ]; then
    echo "Removing user home directory..."
    rm -rf "/Users/$NON_ROOT_USER"
    echo "   Removed /Users/$NON_ROOT_USER"
  fi
  
  # Remove user account using dscl
  echo "Removing user account..."
  if dscl . -delete "/Users/$NON_ROOT_USER" 2>/dev/null; then
    echo "   Successfully removed user account: $NON_ROOT_USER"
  else
    echo "   WARNING: Failed to remove user account (may not exist)"
  fi
  
  # Verify user is gone
  if ! id $NON_ROOT_USER &>/dev/null; then
    echo "   Cleanup verified: $NON_ROOT_USER successfully removed"
  else
    echo "   WARNING: User cleanup may not be complete"
  fi
else
  echo "Temporary user $NON_ROOT_USER not found, no cleanup needed"
fi

echo ""
echo "=== Usage Instructions for NinjaOne/Automation ==="
echo "To use brew in automation scripts, use one of these methods:"
echo "1. Direct command: HOME=\"/var/root\" PATH=\"/usr/local/bin:\$PATH\" HOMEBREW_CACHE=\"/var/root/Library/Caches/Homebrew\" /usr/local/bin/brew [command]"
echo "2. Wrapper script (RECOMMENDED): /usr/local/bin/brew-root [command]"
echo "3. Source environment: source /etc/brew-env && /usr/local/bin/brew [command]"
echo ""
echo "Example usage:"
echo "  /usr/local/bin/brew-root install wget"
echo "  /usr/local/bin/brew-root list"
echo "  /usr/local/bin/brew-root update"
echo "  /usr/local/bin/brew-root search python"
echo ""
echo "IMPORTANT: Always use the wrapper script or full environment setup"
echo "for consistent results in automation environments."