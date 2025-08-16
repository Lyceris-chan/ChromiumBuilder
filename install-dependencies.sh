#!/bin/bash

# Install all dependencies for Ultimate Chromium Builder
# Supports Ubuntu/Debian and similar distributions

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    else
        log_error "Cannot detect distribution"
        exit 1
    fi
    
    log_info "Detected: $PRETTY_NAME"
}

# Update package lists
update_packages() {
    log_info "Updating package lists..."
    
    case $DISTRO in
        ubuntu|debian)
            sudo apt update
            ;;
        fedora)
            sudo dnf check-update || true
            ;;
        centos|rhel)
            sudo yum check-update || true
            ;;
        arch)
            sudo pacman -Sy
            ;;
        *)
            log_warning "Unknown distribution, trying apt..."
            sudo apt update || true
            ;;
    esac
    
    log_success "Package lists updated"
}

# Install build essentials
install_build_essentials() {
    log_info "Installing build essentials..."
    
    case $DISTRO in
        ubuntu|debian)
            sudo apt install -y \
                build-essential \
                cmake \
                ninja-build \
                git \
                curl \
                wget \
                python3 \
                python3-pip \
                python3-setuptools \
                pkg-config \
                libtool \
                autoconf \
                automake \
                make \
                patch \
                unzip \
                zip \
                tar \
                gzip \
                bzip2 \
                xz-utils
            ;;
        fedora)
            sudo dnf install -y \
                gcc \
                gcc-c++ \
                cmake \
                ninja-build \
                git \
                curl \
                wget \
                python3 \
                python3-pip \
                python3-setuptools \
                pkgconfig \
                libtool \
                autoconf \
                automake \
                make \
                patch \
                unzip \
                zip \
                tar \
                gzip \
                bzip2 \
                xz
            ;;
        centos|rhel)
            sudo yum groupinstall -y "Development Tools"
            sudo yum install -y \
                cmake3 \
                git \
                curl \
                wget \
                python3 \
                python3-pip \
                python3-setuptools \
                pkgconfig \
                libtool \
                autoconf \
                automake \
                make \
                patch \
                unzip \
                zip \
                tar \
                gzip \
                bzip2 \
                xz
                
            # Install ninja-build from EPEL
            sudo yum install -y epel-release
            sudo yum install -y ninja-build
            ;;
        arch)
            sudo pacman -S --needed \
                base-devel \
                cmake \
                ninja \
                git \
                curl \
                wget \
                python \
                python-pip \
                python-setuptools \
                pkgconf \
                libtool \
                autoconf \
                automake \
                make \
                patch \
                unzip \
                zip \
                tar \
                gzip \
                bzip2 \
                xz
            ;;
        *)
            log_error "Unsupported distribution for automatic dependency installation"
            log_info "Please install these packages manually:"
            log_info "- build-essential/gcc/g++"
            log_info "- cmake"
            log_info "- ninja-build"
            log_info "- git, curl, wget"
            log_info "- python3, python3-pip"
            log_info "- Development tools (make, patch, autotools)"
            exit 1
            ;;
    esac
    
    log_success "Build essentials installed"
}

# Install Chromium-specific dependencies
install_chromium_deps() {
    log_info "Installing Chromium build dependencies..."
    
    case $DISTRO in
        ubuntu|debian)
            sudo apt install -y \
                libnss3-dev \
                libatk-bridge2.0-dev \
                libdrm2 \
                libxcomposite-dev \
                libxdamage-dev \
                libxrandr-dev \
                libgbm-dev \
                libxss-dev \
                libasound2-dev \
                libatspi2.0-dev \
                libgtk-3-dev \
                libglib2.0-dev \
                libdbus-1-dev \
                libudev-dev \
                libx11-xcb-dev \
                libxcb-dri3-dev \
                bison \
                flex \
                gperf \
                xvfb \
                nodejs \
                npm
            ;;
        fedora)
            sudo dnf install -y \
                nss-devel \
                at-spi2-atk-devel \
                libdrm-devel \
                libXcomposite-devel \
                libXdamage-devel \
                libXrandr-devel \
                mesa-libgbm-devel \
                libXScrnSaver-devel \
                alsa-lib-devel \
                at-spi2-core-devel \
                gtk3-devel \
                glib2-devel \
                dbus-devel \
                systemd-devel \
                libX11-devel \
                libxcb-devel \
                bison \
                flex \
                gperf \
                xorg-x11-server-Xvfb \
                nodejs \
                npm
            ;;
        centos|rhel)
            sudo yum install -y \
                nss-devel \
                at-spi2-atk-devel \
                libdrm-devel \
                libXcomposite-devel \
                libXdamage-devel \
                libXrandr-devel \
                mesa-libgbm-devel \
                libXScrnSaver-devel \
                alsa-lib-devel \
                at-spi2-core-devel \
                gtk3-devel \
                glib2-devel \
                dbus-devel \
                systemd-devel \
                libX11-devel \
                libxcb-devel \
                bison \
                flex \
                gperf \
                xorg-x11-server-Xvfb
                
            # Install Node.js from NodeSource
            curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
            sudo yum install -y nodejs
            ;;
        arch)
            sudo pacman -S --needed \
                nss \
                at-spi2-atk \
                libdrm \
                libxcomposite \
                libxdamage \
                libxrandr \
                mesa \
                libxss \
                alsa-lib \
                at-spi2-core \
                gtk3 \
                glib2 \
                dbus \
                systemd \
                libx11 \
                libxcb \
                bison \
                flex \
                gperf \
                xorg-server-xvfb \
                nodejs \
                npm
            ;;
    esac
    
    log_success "Chromium dependencies installed"
}

# Install additional tools
install_additional_tools() {
    log_info "Installing additional development tools..."
    
    # Install Rust (needed for some Chromium components)
    if ! command -v rustc &> /dev/null; then
        log_info "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source $HOME/.cargo/env
        log_success "Rust installed"
    else
        log_info "Rust already installed"
    fi
    
    # Install gn (Generate Ninja) if not present
    if ! command -v gn &> /dev/null; then
        log_info "Installing gn (Generate Ninja)..."
        case $DISTRO in
            ubuntu|debian)
                # gn is usually installed with depot_tools, but we can install it separately
                log_info "gn will be installed with depot_tools"
                ;;
            *)
                log_info "gn will be installed with depot_tools"
                ;;
        esac
    fi
    
    log_success "Additional tools ready"
}

# Verify installations
verify_installation() {
    log_info "Verifying installations..."
    
    local missing_deps=()
    local required_commands=("git" "python3" "cmake" "ninja" "curl" "patch" "make")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        else
            log_success "✓ $cmd found"
        fi
    done
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        log_success "All dependencies verified successfully!"
        return 0
    else
        log_error "Missing dependencies: ${missing_deps[*]}"
        return 1
    fi
}

# Set up environment
setup_environment() {
    log_info "Setting up build environment..."
    
    # Handle externally managed Python environments
    if python3 -m pip install --user --upgrade pip 2>&1 | grep -q "externally-managed-environment"; then
        log_warning "Python environment is externally managed"
        log_info "Using system packages instead of pip..."
        
        # Install Python packages via system package manager
        case $DISTRO in
            ubuntu|debian)
                sudo apt install -y python3-setuptools python3-wheel python3-venv
                ;;
            fedora)
                sudo dnf install -y python3-setuptools python3-wheel python3-virtualenv
                ;;
            centos|rhel)
                sudo yum install -y python3-setuptools python3-wheel python3-virtualenv
                ;;
            arch)
                sudo pacman -S --needed python-setuptools python-wheel python-virtualenv
                ;;
        esac
    else
        # Traditional pip install for older systems
        python3 -m pip install --user --upgrade pip setuptools wheel
    fi
    
    # Create .bashrc additions for build environment
    if ! grep -q "Ultimate Chromium Builder environment" ~/.bashrc 2>/dev/null; then
        cat >> ~/.bashrc << 'EOF'

# Ultimate Chromium Builder environment
export PATH="$HOME/.local/bin:$PATH"
export DEPOT_TOOLS_UPDATE=1
export DEPOT_TOOLS_WIN_TOOLCHAIN=0
export GYP_MSVS_VERSION=2022

# Add depot_tools to PATH when it's available
if [ -d "$HOME/depot_tools" ]; then
    export PATH="$HOME/depot_tools:$PATH"
fi

EOF
        log_info "Added environment variables to ~/.bashrc"
    else
        log_info "Environment variables already configured"
    fi
    
    log_success "Environment configured"
}

# Show post-install instructions
show_instructions() {
    log_success "Dependencies installation completed!"
    echo
    log_info "Next steps:"
    echo "1. Restart your terminal or run: source ~/.bashrc"
    echo "2. Run the Ultimate Chromium Builder:"
    echo "   ./build-ultimate-chromium.sh"
    echo
    log_info "Build requirements:"
    echo "- At least 50GB free disk space"
    echo "- 8GB+ RAM (16GB+ recommended)"
    echo "- 4+ CPU cores for reasonable build times"
    echo "- Stable internet connection for downloading source code"
    echo
    log_warning "Note: The complete build process takes 2-6 hours depending on your hardware."
}

# Main installation process
main() {
    log_info "Ultimate Chromium Builder - Dependency Installer"
    log_info "This script will install all required dependencies for building Chromium"
    echo
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        log_error "Please do not run this script as root"
        log_info "The script will use sudo when needed"
        exit 1
    fi
    
    # Check for sudo access
    if ! sudo -n true 2>/dev/null; then
        log_info "This script requires sudo access to install packages"
        echo "Please enter your password when prompted..."
        sudo -v
    fi
    
    detect_distro
    update_packages
    install_build_essentials
    install_chromium_deps
    install_additional_tools
    setup_environment
    
    if verify_installation; then
        show_instructions
        exit 0
    else
        log_error "Some dependencies failed to install"
        log_info "Please check the error messages above and install missing packages manually"
        exit 1
    fi
}

# Execute main function
main "$@"