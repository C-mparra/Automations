#!/bin/bash

# Installs brew, for Ninja One automation
if test ! $(which brew); then
  echo "Homebrew not found. Installing Homebrew..."

  # Create a non-root user temporarily for Homebrew installation
  NON_ROOT_USER="installeruser"

  # Check if user already exists
  id $NON_ROOT_USER &>/dev/null || {
    echo "Creating temporary user: $NON_ROOT_USER"
    # Create a temporary user for installation 
    dscl . -create /Users/$NON_ROOT_USER
    dscl . -create /Users/$NON_ROOT_USER UserShell /bin/bash
    dscl . -create /Users/$NON_ROOT_USER RealName "Installer User"
    dscl . -create /Users/$NON_ROOT_USER UniqueID "1010"
    dscl . -create /Users/$NON_ROOT_USER PrimaryGroupID 20
    dscl . -create /Users/$NON_ROOT_USER NFSHomeDirectory /Users/$NON_ROOT_USER
    
    # Create a home directory for the user
    mkdir -p /Users/$NON_ROOT_USER
    chown -R $NON_ROOT_USER:staff /Users/$NON_ROOT_USER
  }

  echo "$NON_ROOT_USER ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers

  sudo -u $NON_ROOT_USER /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  sudo -u $NON_ROOT_USER /bin/bash -c 'touch ~/.bash_profile ~/.zshrc && chmod 644 ~/.bash_profile ~/.zshrc'
  sudo -u $NON_ROOT_USER /bin/bash -c 'echo '\''eval "$(/usr/local/bin/brew shellenv)"'\'' >> ~/.bash_profile'
  sudo -u $NON_ROOT_USER /bin/bash -c 'echo '\''eval "$(/usr/local/bin/brew shellenv)"'\'' >> ~/.zshrc'

  BREW_CHECK=$(sudo -u $NON_ROOT_USER /bin/bash -l -c 'eval "$(/usr/local/bin/brew shellenv)" && which brew')

  if [[ -n "$BREW_CHECK" ]]; then
    echo "Homebrew successfully installed at: $BREW_CHECK"
    
    # Make Homebrew accessible system-wide by adding to global PATH
    if ! grep -q "/usr/local/bin" /etc/paths; then
      echo "/usr/local/bin" | sudo tee -a /etc/paths
    fi
    
    # Set proper ownership for Homebrew directories to allow root access
    sudo chown -R root:admin /usr/local/Homebrew
    sudo chmod -R g+rwx /usr/local/Homebrew
    
    echo "Cleaning up temporary user..."
    sudo rm -rf /Users/$NON_ROOT_USER
    sudo dscl . -delete /Users/$NON_ROOT_USER 2>/dev/null || true
    sudo sed -i '' "/$NON_ROOT_USER/d" /etc/sudoers
    
  else
    echo "Homebrew installation failed!"
    sudo rm -rf /Users/$NON_ROOT_USER 2>/dev/null || true
    sudo dscl . -delete /Users/$NON_ROOT_USER 2>/dev/null || true
    sudo sed -i '' "/$NON_ROOT_USER/d" /etc/sudoers 2>/dev/null || true
    exit 1
  fi
fi

mkdir -p /var/root
echo "Created /var/root directory"
echo "Creating brew wrapper script for root..."
cat > /usr/local/bin/brew-root << 'EOF'
#!/bin/bash
export HOME="/var/root"
export PATH="/usr/local/bin:$PATH"
exec /usr/local/bin/brew "$@"
EOF

chmod +x /usr/local/bin/brew-root
echo "Created /usr/local/bin/brew-root wrapper"

echo "Setting up bash profile..."
mkdir -p /var/root
if ! grep -q 'export HOME="/var/root"' /var/root/.bash_profile 2>/dev/null; then
  echo 'export HOME="/var/root"' >> /var/root/.bash_profile
  echo "Added HOME export to .bash_profile"
else
  echo "HOME export already exists in .bash_profile"
fi

if ! grep -q 'export PATH="/usr/local/bin:$PATH"' /var/root/.bash_profile 2>/dev/null; then
  echo 'export PATH="/usr/local/bin:$PATH"' >> /var/root/.bash_profile
  echo "Added PATH export to .bash_profile"
else
  echo "PATH export already exists in .bash_profile"
fi

if ! grep -q 'eval "$(/usr/local/bin/brew shellenv)"' /var/root/.bash_profile 2>/dev/null; then
  echo 'eval "$(/usr/local/bin/brew shellenv)"' >> /var/root/.bash_profile
  echo "Added brew shellenv to .bash_profile"
else
  echo "brew shellenv already exists in .bash_profile"
fi

echo "Setting up zsh profile..."
if ! grep -q 'export HOME="/var/root"' /var/root/.zshrc 2>/dev/null; then
  echo 'export HOME="/var/root"' >> /var/root/.zshrc
  echo "Added HOME export to .zshrc"
else
  echo "HOME export already exists in .zshrc"
fi

if ! grep -q 'export PATH="/usr/local/bin:$PATH"' /var/root/.zshrc 2>/dev/null; then
  echo 'export PATH="/usr/local/bin:$PATH"' >> /var/root/.zshrc
  echo "Added PATH export to .zshrc"
else
  echo "PATH export already exists in .zshrc"
fi

if ! grep -q 'eval "$(/usr/local/bin/brew shellenv)"' /var/root/.zshrc 2>/dev/null; then
  echo 'eval "$(/usr/local/bin/brew shellenv)"' >> /var/root/.zshrc
  echo "Added brew shellenv to .zshrc"
else
  echo "brew shellenv already exists in .zshrc"
fi

echo "Creating global environment configuration..."
cat > /etc/brew-env << 'EOF'
export HOME="/var/root"
export PATH="/usr/local/bin:$PATH"
export HOMEBREW_PREFIX="/usr/local"
export HOMEBREW_CELLAR="/usr/local/Cellar"
export HOMEBREW_REPOSITORY="/usr/local/Homebrew"
export MANPATH="/usr/local/share/man${MANPATH+:$MANPATH}:"
export INFOPATH="/usr/local/share/info:${INFOPATH:-}"
EOF

echo "Created /etc/brew-env for global configuration"

export HOME="/var/root"
export PATH="/usr/local/bin:$PATH"
export HOMEBREW_PREFIX="/usr/local"
export HOMEBREW_CELLAR="/usr/local/Cellar"
export HOMEBREW_REPOSITORY="/usr/local/Homebrew"

if HOME="/var/root" PATH="/usr/local/bin:$PATH" /usr/local/bin/brew --version >/dev/null 2>&1; then
  BREW_VERSION=$(HOME="/var/root" PATH="/usr/local/bin:$PATH" /usr/local/bin/brew --version | head -1)
  echo "Homebrew installation and configuration completed successfully!"
  echo "Homebrew version: $BREW_VERSION"
  echo "Direct access: HOME=\"/var/root\" PATH=\"/usr/local/bin:\$PATH\" /usr/local/bin/brew [command]"
  echo "Wrapper script: /usr/local/bin/brew-root [command]"
  echo "Configuration saved to /var/root/.bash_profile and /var/root/.zshrc"
  echo "Global environment file: /etc/brew-env"
  
  if /usr/local/bin/brew-root --version >/dev/null 2>&1; then
    echo "Wrapper script working correctly"
  else
    echo "Wrapper script test failed"
  fi
  
else
  echo "Warning: Homebrew installed but verification failed."
  echo "Try running: HOME=\"/var/root\" PATH=\"/usr/local/bin:\$PATH\" /usr/local/bin/brew --version"
fi

echo ""
echo "=== Usage Instructions for NinjaOne/Automation ==="
echo "To use brew in automation scripts, use one of these methods:"
echo "1. Direct command: HOME=\"/var/root\" PATH=\"/usr/local/bin:\$PATH\" /usr/local/bin/brew [command]"
echo "2. Wrapper script: /usr/local/bin/brew-root [command]"
echo "3. Source environment: source /etc/brew-env && /usr/local/bin/brew [command]"