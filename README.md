# GCC Multi-Version Toolkit

A single script to install GCC 10, 11, and 12 on any machine for kernel development.

## Quick Start

```bash
# Make executable
chmod +x install_gcc_toolkit.sh

# Run as root
sudo ./install_gcc_toolkit.sh
```

That's it! The script will:
- Install all dependencies
- Download GCC 10, 11, and 12 sources
- Build and install them to `/opt/gcc-{10,11,12}`
- Create helper script at `/usr/local/bin/use-gcc`
- Takes 1-2 hours

## Usage After Installation

### Switch GCC Version

```bash
# Switch to GCC 12
source /usr/local/bin/use-gcc 12

# Build kernel
make -j$(nproc)

# Switch to GCC 11
source /usr/local/bin/use-gcc 11

# Build again
make -j$(nproc)

# Back to system GCC
source /usr/local/bin/use-gcc system
```

### Use Without Switching

```bash
# Build directly with GCC 12
make CC=/opt/gcc-12/bin/gcc -j$(nproc)

# Kernel compilation
cd ~/workspace/centos/centos-stream-10
make CC=/opt/gcc-12/bin/gcc -j14

# RPM build
make CC=/opt/gcc-12/bin/gcc binrpm-pkg
```

### Check Available Versions

```bash
source /usr/local/bin/use-gcc
# Shows all installed versions
```

## Examples

### Build Kernel with Different GCC Versions

```bash
#!/bin/bash
# test_gcc_versions.sh

for version in 10 11 12; do
    echo "=== Testing with GCC $version ==="
    source /usr/local/bin/use-gcc $version
    
    make mrproper
    cp configs/my_kernel.config .config
    
    if make -j$(nproc); then
        echo "✓ GCC $version: SUCCESS"
    else
        echo "✗ GCC $version: FAILED"
    fi
done
```

### CentOS Stream Kernel Build

```bash
# Build with GCC 12
cd ~/workspace/centos/centos-stream-10
source /usr/local/bin/use-gcc 12
make -C redhat dist-rpms

# Or
make -C redhat CC=/opt/gcc-12/bin/gcc dist-rpms
```

### Add to Project

```bash
# Add to your kernel repo
cp install_gcc_toolkit.sh ~/workspace/centos/centos-stream-10/
cd ~/workspace/centos/centos-stream-10
git add install_gcc_toolkit.sh
git commit -m "Add GCC multi-version installer script"
```

## Requirements

- **OS**: Fedora, RHEL, CentOS Stream, or Debian/Ubuntu
- **Disk Space**: ~5GB during build, ~2GB after cleanup
- **Time**: 1-2 hours
- **RAM**: 4GB minimum, 8GB recommended
- **Root Access**: Required for installation

## What Gets Installed

```
/opt/
├── gcc-10/
│   ├── bin/
│   │   ├── gcc
│   │   └── g++
│   └── lib64/
├── gcc-11/
│   ├── bin/
│   │   ├── gcc
│   │   └── g++
│   └── lib64/
└── gcc-12/
    ├── bin/
    │   ├── gcc
    │   └── g++
    └── lib64/

/usr/local/bin/
└── use-gcc (helper script)
```

## Supported Distributions

- ✅ Fedora 38+
- ✅ RHEL 9+
- ✅ CentOS Stream 9/10
- ✅ Ubuntu 20.04+
- ✅ Debian 11+

## Uninstallation

```bash
# Remove specific version
sudo rm -rf /opt/gcc-12

# Remove all versions
sudo rm -rf /opt/gcc-{10,11,12}

# Remove helper script
sudo rm /usr/local/bin/use-gcc
```

## Troubleshooting

### Build fails with "no space left on device"

```bash
# Check disk space
df -h /opt /tmp

# Clean up if needed
sudo dnf clean all
rm -rf ~/gcc-build/gcc-*  # Remove partially extracted sources
```

### "libstdc++.so.6: version not found" when running programs

```bash
# Use the helper script (automatically sets LD_LIBRARY_PATH)
source /usr/local/bin/use-gcc 12

# Or set manually
export LD_LIBRARY_PATH=/opt/gcc-12/lib64:$LD_LIBRARY_PATH
```

### Script hangs during build

This is normal! Building GCC takes 30-60 minutes per version. Monitor with:

```bash
# In another terminal
tail -f ~/gcc-build/build.log
```

### Want to use on another machine?

```bash
# Copy the script to new machine
scp install_gcc_toolkit.sh user@newmachine:~

# Run on new machine
ssh user@newmachine
sudo ./install_gcc_toolkit.sh
```

## Advanced Usage

### Build Only Specific Versions

Edit `install_gcc_toolkit.sh` and comment out versions you don't need:

```bash
# Build and install each version
build_gcc "12.3.0"    # Keep GCC 12
# build_gcc "11.4.0"  # Skip GCC 11
# build_gcc "10.5.0"  # Skip GCC 10
```

### Change Install Location

Edit the script:

```bash
INSTALL_PREFIX="/usr/local"  # Instead of /opt
```

### Add to .bashrc for Permanent Setup

```bash
# Add to ~/.bashrc
echo 'alias gcc12="source /usr/local/bin/use-gcc 12"' >> ~/.bashrc
echo 'alias gcc11="source /usr/local/bin/use-gcc 11"' >> ~/.bashrc

# Use it
source ~/.bashrc
gcc12
make -j$(nproc)
```

## Integration with IDEs

### VS Code

Add to `.vscode/settings.json`:

```json
{
  "C_Cpp.default.compilerPath": "/opt/gcc-12/bin/gcc",
  "C_Cpp.default.includePath": [
    "${workspaceFolder}/**",
    "/opt/gcc-12/include"
  ]
}
```

### CLion

Settings → Build, Execution, Deployment → Toolchains
- C Compiler: `/opt/gcc-12/bin/gcc`
- C++ Compiler: `/opt/gcc-12/bin/g++`

## Performance Tips

### Speed Up Build

```bash
# Use all CPU cores
JOBS=$(nproc)

# Or limit to avoid system lockup
JOBS=$(($(nproc) - 2))

# Edit script before running
sed -i 's/JOBS=$(nproc)/JOBS=12/' install_gcc_toolkit.sh
```

### Reduce Build Time

```bash
# Edit script to add --disable-bootstrap (builds faster but less tested)
# Already included in the script!
```

## License

This script installs GCC which is licensed under GPLv3.
The script itself is public domain / CC0.

## Credits

- GCC Project: https://gcc.gnu.org/
- Created for CentOS Stream kernel development
- Author: Claude Code Assistant with user customization

## Support

If you encounter issues:
1. Check `~/gcc-build/build.log` for errors
2. Ensure you have enough disk space
3. Verify internet connection (downloads ~400MB)
4. Try running with `bash -x` for debugging
