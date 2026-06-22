#!/bin/bash
#
# GCC Multi-Version Installer
# Installs GCC 10, 11, and 12 to /opt for side-by-side use
#
# Usage:
#   sudo ./install_gcc_toolkit.sh
#
# After installation, use:
#   source /usr/local/bin/use-gcc 12   # Switch to GCC 12
#   source /usr/local/bin/use-gcc 11   # Switch to GCC 11
#   source /usr/local/bin/use-gcc 10   # Switch to GCC 10
#   source /usr/local/bin/use-gcc 15   # Back to system GCC
#
# Or use directly in make:
#   make CC=/opt/gcc-12/bin/gcc -j$(nproc)
#

set -e  # Exit on error

# Configuration
BUILDDIR="$HOME/gcc-build"
JOBS=$(nproc)
INSTALL_PREFIX="/opt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run as root or with sudo"
        exit 1
    fi
}

detect_distro() {
    if [ -f /etc/fedora-release ]; then
        echo "fedora"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

install_dependencies() {
    log_info "Installing build dependencies..."

    DISTRO=$(detect_distro)

    case "$DISTRO" in
        fedora|rhel)
            dnf install -y gcc gcc-c++ make wget bzip2 gmp-devel mpfr-devel \
                libmpc-devel flex bison tar xz
            ;;
        debian)
            apt-get update
            apt-get install -y build-essential wget bzip2 libgmp-dev libmpfr-dev \
                libmpc-dev flex bison
            ;;
        *)
            log_error "Unsupported distribution. Please install dependencies manually."
            log_info "Required: gcc, g++, make, wget, bzip2, gmp-devel, mpfr-devel, libmpc-devel"
            exit 1
            ;;
    esac

    log_success "Dependencies installed"
}

download_gcc() {
    VERSION=$1
    TARBALL="gcc-${VERSION}.tar.gz"
    URL="https://ftp.gnu.org/gnu/gcc/gcc-${VERSION}/${TARBALL}"

    if [ -f "$BUILDDIR/$TARBALL" ]; then
        log_info "GCC $VERSION already downloaded"
        return 0
    fi

    log_info "Downloading GCC $VERSION..."
    cd "$BUILDDIR"
    wget -q --show-progress "$URL" || {
        log_error "Failed to download GCC $VERSION"
        return 1
    }
    log_success "Downloaded GCC $VERSION"
}

build_gcc() {
    VERSION=$1
    MAJOR_VERSION=$(echo $VERSION | cut -d. -f1)
    PREFIX="${INSTALL_PREFIX}/gcc-${MAJOR_VERSION}"
    TARBALL="gcc-${VERSION}.tar.gz"

    log_info "========================================="
    log_info "Building GCC $VERSION"
    log_info "Install location: $PREFIX"
    log_info "========================================="

    cd "$BUILDDIR"

    # Extract
    log_info "Extracting source..."
    tar xf "$TARBALL"
    cd "gcc-${VERSION}"

    # Download prerequisites
    log_info "Downloading GCC prerequisites..."
    ./contrib/download_prerequisites

    # Create build directory
    mkdir build
    cd build

    # Configure
    log_info "Configuring GCC $VERSION..."
    ../configure \
        --prefix="$PREFIX" \
        --enable-languages=c,c++ \
        --disable-multilib \
        --disable-bootstrap \
        --enable-checking=release \
        2>&1 | tee configure.log

    # Build
    log_info "Building GCC $VERSION (this takes 30-60 minutes)..."
    log_info "Using $JOBS parallel jobs"
    make -j$JOBS 2>&1 | tee build.log

    # Install
    log_info "Installing GCC $VERSION to $PREFIX..."
    make install 2>&1 | tee install.log

    # Verify
    log_info "Verifying installation..."
    "$PREFIX/bin/gcc" --version

    # Cleanup source
    cd "$BUILDDIR"
    log_info "Cleaning up build directory..."
    rm -rf "gcc-${VERSION}"

    log_success "GCC $VERSION installed successfully to $PREFIX"
}

create_helper_script() {
    log_info "Creating GCC version switcher script..."

    cat > /usr/local/bin/use-gcc << 'EOFHELPER'
#!/bin/bash
# GCC Version Switcher
# Usage: source use-gcc <version>

if [ "$0" = "$BASH_SOURCE" ]; then
    echo "Error: This script must be sourced, not executed directly"
    echo "Usage: source use-gcc <version>"
    exit 1
fi

if [ "$1" == "" ] || [ "$1" == "help" ] || [ "$1" == "--help" ]; then
    echo "Current GCC: $(gcc --version 2>/dev/null | head -1 || echo 'not found')"
    echo ""
    echo "Available versions:"
    [ -x /opt/gcc-10/bin/gcc ] && echo "  10 - /opt/gcc-10/bin/gcc - $(\/opt/gcc-10/bin/gcc --version | head -1)"
    [ -x /opt/gcc-11/bin/gcc ] && echo "  11 - /opt/gcc-11/bin/gcc - $(\/opt/gcc-11/bin/gcc --version | head -1)"
    [ -x /opt/gcc-12/bin/gcc ] && echo "  12 - /opt/gcc-12/bin/gcc - $(\/opt/gcc-12/bin/gcc --version | head -1)"
    [ -x /usr/bin/gcc ] && echo "  system - /usr/bin/gcc - $(\/usr/bin/gcc --version | head -1)"
    echo ""
    echo "Usage: source use-gcc <version>"
    echo "Example: source use-gcc 12"
    return 0
fi

case "$1" in
    10)
        if [ ! -x /opt/gcc-10/bin/gcc ]; then
            echo "Error: GCC 10 not installed at /opt/gcc-10"
            return 1
        fi
        export PATH=/opt/gcc-10/bin:$(echo $PATH | tr ':' '\n' | grep -v '/opt/gcc-' | tr '\n' ':' | sed 's/:$//')
        export LD_LIBRARY_PATH=/opt/gcc-10/lib64:$(echo ${LD_LIBRARY_PATH:-} | tr ':' '\n' | grep -v '/opt/gcc-' | tr '\n' ':' | sed 's/:$//')
        export CC=/opt/gcc-10/bin/gcc
        export CXX=/opt/gcc-10/bin/g++
        echo "✓ Switched to GCC 10"
        ;;
    11)
        if [ ! -x /opt/gcc-11/bin/gcc ]; then
            echo "Error: GCC 11 not installed at /opt/gcc-11"
            return 1
        fi
        export PATH=/opt/gcc-11/bin:$(echo $PATH | tr ':' '\n' | grep -v '/opt/gcc-' | tr '\n' ':' | sed 's/:$//')
        export LD_LIBRARY_PATH=/opt/gcc-11/lib64:$(echo ${LD_LIBRARY_PATH:-} | tr ':' '\n' | grep -v '/opt/gcc-' | tr '\n' ':' | sed 's/:$//')
        export CC=/opt/gcc-11/bin/gcc
        export CXX=/opt/gcc-11/bin/g++
        echo "✓ Switched to GCC 11"
        ;;
    12)
        if [ ! -x /opt/gcc-12/bin/gcc ]; then
            echo "Error: GCC 12 not installed at /opt/gcc-12"
            return 1
        fi
        export PATH=/opt/gcc-12/bin:$(echo $PATH | tr ':' '\n' | grep -v '/opt/gcc-' | tr '\n' ':' | sed 's/:$//')
        export LD_LIBRARY_PATH=/opt/gcc-12/lib64:$(echo ${LD_LIBRARY_PATH:-} | tr ':' '\n' | grep -v '/opt/gcc-' | tr '\n' ':' | sed 's/:$//')
        export CC=/opt/gcc-12/bin/gcc
        export CXX=/opt/gcc-12/bin/g++
        echo "✓ Switched to GCC 12"
        ;;
    system|default|15)
        # Remove /opt/gcc-* from PATH and LD_LIBRARY_PATH
        export PATH=$(echo $PATH | tr ':' '\n' | grep -v '/opt/gcc-' | tr '\n' ':' | sed 's/:$//')
        export LD_LIBRARY_PATH=$(echo ${LD_LIBRARY_PATH:-} | tr ':' '\n' | grep -v '/opt/gcc-' | tr '\n' ':' | sed 's/:$//')
        unset CC
        unset CXX
        echo "✓ Switched to system GCC"
        ;;
    *)
        echo "Unknown version: $1"
        echo "Available versions: 10, 11, 12, system"
        return 1
        ;;
esac

gcc --version | head -1
EOFHELPER

    chmod +x /usr/local/bin/use-gcc
    log_success "Created /usr/local/bin/use-gcc"
}

create_readme() {
    log_info "Creating README..."

    cat > "$BUILDDIR/README.md" << 'EOFREADME'
# GCC Multi-Version Toolkit

This system has GCC 10, 11, and 12 installed alongside the system GCC.

## Installed Locations

- GCC 10: `/opt/gcc-10/bin/gcc`
- GCC 11: `/opt/gcc-11/bin/gcc`
- GCC 12: `/opt/gcc-12/bin/gcc`
- System GCC: `/usr/bin/gcc`

## Usage

### Method 1: Switch GCC version for current shell

```bash
# Switch to GCC 12
source /usr/local/bin/use-gcc 12

# Verify
gcc --version

# Build something
make -j$(nproc)

# Switch back to system GCC
source /usr/local/bin/use-gcc system
```

### Method 2: Use specific GCC directly

```bash
# Build with GCC 12 without switching
make CC=/opt/gcc-12/bin/gcc CXX=/opt/gcc-12/bin/g++ -j$(nproc)

# Or for kernel
make CC=/opt/gcc-12/bin/gcc -j$(nproc)
```

### Method 3: Use in scripts

```bash
#!/bin/bash
source /usr/local/bin/use-gcc 12
make -j$(nproc)
```

## Examples

### Kernel Compilation

```bash
# Use GCC 12 for kernel build
cd /path/to/kernel/source
source /usr/local/bin/use-gcc 12
make -j$(nproc)

# Or directly
make CC=/opt/gcc-12/bin/gcc -j$(nproc)
```

### RPM Build

```bash
# Build kernel RPMs with GCC 12
cd /path/to/kernel/source
source /usr/local/bin/use-gcc 12
make binrpm-pkg
```

### Testing Multiple GCC Versions

```bash
#!/bin/bash
for version in 10 11 12; do
    echo "Testing with GCC $version..."
    source /usr/local/bin/use-gcc $version
    make clean
    make -j$(nproc) || echo "Failed with GCC $version"
done
```

## Uninstallation

To remove specific GCC version:

```bash
sudo rm -rf /opt/gcc-10
sudo rm -rf /opt/gcc-11
sudo rm -rf /opt/gcc-12
```

To remove the helper script:

```bash
sudo rm /usr/local/bin/use-gcc
```

## Troubleshooting

### Library errors when running compiled programs

Make sure to set `LD_LIBRARY_PATH`:

```bash
export LD_LIBRARY_PATH=/opt/gcc-12/lib64:$LD_LIBRARY_PATH
```

Or use `use-gcc` script which sets it automatically.

### Which GCC am I using?

```bash
which gcc
gcc --version
echo $CC
```

### Reset to system GCC

```bash
source /usr/local/bin/use-gcc system
```
EOFREADME

    log_success "Created $BUILDDIR/README.md"
}

# Main installation flow
main() {
    log_info "========================================="
    log_info "GCC Multi-Version Installer"
    log_info "========================================="
    log_info "This will install GCC 10, 11, and 12 to /opt"
    log_info "Estimated time: 1-2 hours"
    log_info "Disk space needed: ~5GB during build, ~2GB after"
    log_info ""

    # Check if running as root
    check_root

    # Create build directory
    log_info "Creating build directory: $BUILDDIR"
    mkdir -p "$BUILDDIR"
    cd "$BUILDDIR"

    # Install dependencies
    install_dependencies

    # Download GCC sources
    log_info "Downloading GCC sources..."
    download_gcc "12.3.0"
    download_gcc "11.4.0"
    download_gcc "10.5.0"

    # Build and install each version
    log_info ""
    log_info "Starting builds..."
    log_info ""

    build_gcc "12.3.0"
    build_gcc "11.4.0"
    build_gcc "10.5.0"

    # Create helper script
    create_helper_script

    # Create README
    create_readme

    # Summary
    log_info ""
    log_info "========================================="
    log_success "Installation Complete!"
    log_info "========================================="
    log_info ""
    log_info "Installed GCC versions:"
    /opt/gcc-12/bin/gcc --version | head -1
    /opt/gcc-11/bin/gcc --version | head -1
    /opt/gcc-10/bin/gcc --version | head -1
    log_info ""
    log_info "Usage:"
    log_info "  source /usr/local/bin/use-gcc 12"
    log_info "  source /usr/local/bin/use-gcc 11"
    log_info "  source /usr/local/bin/use-gcc 10"
    log_info "  source /usr/local/bin/use-gcc system"
    log_info ""
    log_info "Or use directly:"
    log_info "  make CC=/opt/gcc-12/bin/gcc -j$(nproc)"
    log_info ""
    log_info "Documentation: $BUILDDIR/README.md"
    log_info ""

    # Cleanup downloaded tarballs (optional)
    read -p "Remove downloaded source tarballs to save space? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "$BUILDDIR"/*.tar.gz
        log_success "Source tarballs removed"
    fi

    log_success "All done!"
}

# Run main installation
main "$@"
