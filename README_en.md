<div align="center">
  <img src="https://avatars.githubusercontent.com/u/245985800?s=200&v=4" alt="FasterEdge logo" width="100" />
  <h2>FasterEdgeOS</h2>
  <h3>A Lightweight Edge Computing Operating System Based on the Linux Kernel and the FasterEdge Ecosystem</h3>
</div>

### 1. Introduction

FasterEdgeOS is a lightweight Linux distribution for edge nodes and cluster devices. It is built from the Linux kernel, GNU C Library and BusyBox, and uses an overlay mechanism to integrate software and system services.

The current repository retains the ability to build system images from source. The following FasterEdge integrations are planned and will be added incrementally:

- **FasterEdge node runtime**: the runtime environment for FasterEdge nodes.
- **FasterEdge2Api**: cluster-topology and system-management APIs.
- **Process and service management**: FasterEdgeOS process supervision and service management.
- **System observability**: health checks, logs and resource status.
- **Remote updates**: signed verification and rollback support.

> The current version is in the base-system adaptation stage. Linux Live ISO and BIOS/UEFI build foundations are present. The checked-in boot and QEMU scripts currently target x86/x86_64; the FasterEdge service bundle described below is a deployment plan and is not yet present under `src/minimal_overlay/bundles/`.

### 2. System Architecture

```text
Linux Kernel
    ↓
GNU C Library
    ↓
BusyBox user space
    ↓
FasterEdgeOS base rootfs
    ↓
overlay bundles
    ↓
FasterEdgeOS ISO / rootfs image
```

After boot, the system provides a minimal shell, basic networking and configured overlay software. FasterEdgeOS-specific components are intended to use these locations:

| Path | Purpose |
|---|---|
| `/usr/bin/` | Executable programs |
| `/etc/fasteredgeos/` | System configuration |
| `/etc/init.d/` | Service startup scripts |
| `/var/lib/fasteredgeos/` | Runtime data, versions and update state |
| `/var/log/fasteredgeos/` | System service logs |
| `/opt/fasteredgeos/releases/` | A/B release directories |

### 3. Quick Build

A Debian or Ubuntu Linux build host is recommended. On macOS or Windows, use a Linux virtual machine or CI.

- **GitHub Actions**: `.github/workflows/manual.yml` can be triggered manually from the GitHub Actions page, or automatically by pushing a `v*` tag such as `v0.1.0`.
- **CI artifacts**: successful builds upload `fasteredgeos.iso`, `fasteredgeos_image.tgz` and build logs as artifacts retained for 14 days. The `.tgz` file can be used with `docker import`.
- **Toolchain requirement**: the current glibc 2.44 requires GCC 12.1+, binutils 2.39+ and GNU make 4.0+.
- **Recommended host**: Ubuntu 24.04+ provides a suitable toolchain. Ubuntu 22.04 requires newer GCC and binutils packages; otherwise, the glibc build fails.

#### 3.1 Install Dependencies

```bash
sudo apt update
sudo apt install -y \
  wget make gawk gcc bc bison flex xorriso rsync \
  libelf-dev libssl-dev file cpio gzip xz-utils
```

Additional packages mentioned for AArch64/QEMU-related work are:

```bash
sudo apt install -y qemu-system-aarch64 bzip2 dosfstools
```

> The current repository's standard ISO boot scripts use x86/x86_64 QEMU commands. Treat AArch64 support as work in progress rather than a completed build path.

#### 3.2 Configure Build Parameters

Edit the main configuration file:

```bash
vi src/.config
```

Common parameters:

```text
FIRMWARE_TYPE=bios       # bios / uefi / both
OVERLAY_TYPE=folder      # folder / sparse
OVERLAY_LOCATION=iso     # iso / rootfs
BUILD_KERNEL_MODULES=false
JOB_FACTOR=1
```

The checked-in defaults also set:

```text
OVERLAY_BUNDLES=dhcp,mll_hello,mll_logo,mll_source
```

#### 3.3 Build FasterEdgeOS

```bash
cd src
make all
```

The build produces:

```text
src/fasteredgeos.iso
src/fasteredgeos_image.tgz
```

To rebuild from a clean state:

```bash
cd src
make clean
make all
```

### 4. Boot and Test

#### 4.1 BIOS Mode

```bash
cd src
./qemu-bios.sh
```

The equivalent Make target is `make qemu-bios`.

#### 4.2 UEFI Mode

```bash
cd src
./qemu-uefi.sh
```

The equivalent Make target is `make qemu-uefi`. Before running it, set `OVMF_LOCATION` in `src/qemu-uefi.sh` to a valid OVMF firmware image.

#### 4.3 Docker rootfs Test

```bash
cd src
docker import fasteredgeos_image.tgz fasteredgeos:latest
docker run --rm -it fasteredgeos:latest /bin/sh
```

#### 4.4 Write to USB Media

> Writing the image overwrites the target disk. Verify the device path before running this command.

```bash
cd src
sudo ./write_to_media.sh /dev/sdX
```

### 5. Planned FasterEdge Service Deployment

FasterEdgeOS uses overlay bundles to add software to the final rootfs. The Chinese project plan reserves the following bundle path for FasterEdge components:

```text
src/minimal_overlay/bundles/fasteredgeos/
```

The planned bundle is intended to:

- **FasterEdge2Api**: build or install `fasteredge2api`.
- **Runtime**: install the FasterEdge runtime and configuration.
- **Supervisor**: install `fasteredge-supervisor`.
- **Startup**: create `/etc/init.d/` service scripts.
- **Directories**: initialize `/etc/fasteredgeos/`, `/var/lib/fasteredgeos/` and log directories.
- **Automatic start**: start base services during system boot.

Once that bundle is implemented and enabled, the planned configuration is:

```text
OVERLAY_BUNDLES=dhcp,fasteredgeos
```

The intended service model is compatible with BusyBox init and does not depend on systemd:

```text
BusyBox init
    ↓
/etc/inittab
    ↓
/etc/init.d/fasteredge-supervisor
    ↓
fasteredge2api + FasterEdge node services
```

> This section describes planned integration. The current source tree does not contain `src/minimal_overlay/bundles/fasteredgeos/`, and the default `OVERLAY_BUNDLES` value does not enable it.

### 6. Planned System Management and Remote Updates

FasterEdge2Api is planned as the system-management entry point, incrementally providing:

- **Node information**: node and network-interface details.
- **Runtime status**: processes, services and operating state.
- **System health**: CPU, memory, disk and overall health status.
- **Cluster management**: FasterEdge topology and peer management.
- **Roles**: Cloud/Edge node status.
- **Updates**: check, download, installation and rollback operations.

The planned remote-update design switches between version directories:

```text
/opt/fasteredgeos/releases/0.1.0/
/opt/fasteredgeos/releases/0.2.0/
/opt/fasteredgeos/current -> releases/0.2.0
```

Every update must follow this sequence:

```text
Download → SHA256/signature verification → space check → installation → health check → switch or rollback
```

All remote-management operations should use HTTPS and accept only authorized administrator tokens.

### 7. Security

#### 7.1 Component Versions and Known-CVE Remediation

| Component | Old Version with Known Issues | Current Version | Notes |
|---|---|---|---|
| Linux kernel | 5.18.3, EOL since 2022-11 | 6.6.155 LTS | The configured source URL uses Linux 6.6.155; the README baseline notes LTS maintenance through 2026-12. |
| GNU C Library | 2.35, including known issues such as CVE-2023-4911, CVE-2024-2961 and CVE-2025-4802 | 2.44 | The configured source URL uses glibc 2.44. |
| BusyBox | 1.34.1, including known issues such as CVE-2022-48174 and CVE-2022-28391 | 1.37.0 | The project does not use the then-unstable 1.38.0 line. |
| Syslinux | 6.03 | 6.03 | No newer upstream version is configured; it is used only during BIOS boot. |
| systemd-boot | 2018 snapshot from the upstream fork | 2018 snapshot | Used only during UEFI boot. |

#### 7.2 Implemented Hardening

- **Compiler hardening**: build CFLAGS remove `-fno-stack-protector` and `-U_FORTIFY_SOURCE`, and enable `-fstack-protector-strong`. The BusyBox build separately enables `-D_FORTIFY_SOURCE=2`.
- **Kernel hardening**: `src/02_build_kernel.sh` explicitly enables `STACKPROTECTOR_STRONG`, `FORTIFY_SOURCE` and `SECURITY_DMESG_RESTRICT`.
- **CI dependencies**: the build environment includes `rsync`, which Linux 6.6+ requires for `headers_install`.

#### 7.3 Known Live-System Tradeoffs

- **Passwordless root**: the system enters a root shell without a password by default, following a traditional Live-system design. Use this only in isolated or development environments. For production, at minimum run:

  ```sh
  passwd root
  ```

  Persist `/etc/passwd` and `/etc/shadow` on writable media.

- **Multiple root consoles**: init starts root shells on `tty1` through `tty4` by default. To reduce exposure, remove unnecessary `tty2` through `tty4` respawn entries from `/etc/inittab`.
- **Dropbear disabled by default**: the default `OVERLAY_BUNDLES` does not include `dropbear`, so remote SSH login is not exposed by default. If enabled, set a root password and use key-based authentication.

#### 7.4 Persistence and Updates

- **Live-mode persistence**: with `OVERLAY_TYPE=folder` and `OVERLAY_LOCATION=iso`, changes are lost after reboot unless a writable `fasteredgeos/rootfs` plus `fasteredgeos/work` layout or a `fasteredgeos.img` image is provided. Production deployments should use writable persistent media or rebuild the image as part of the upgrade process.
- **Safe updates**: remote updates must follow the verification, installation, health-check and rollback sequence described above. Never overwrite the currently running version directly.

### 8. Repository Layout

```text
FasterEdgeOS/
├── src/                          # System source and build entry point
│   ├── .config                   # Main build configuration
│   ├── Makefile                  # make all/clean/qemu/test targets
│   ├── 00_* ~ 16_*              # Staged build scripts
│   ├── minimal_boot/             # BIOS/UEFI boot files
│   ├── minimal_config/           # Kernel and BusyBox configuration
│   ├── minimal_overlay/          # Overlay bundles
│   ├── minimal_rootfs/           # Base rootfs
│   └── common.sh                 # Shared build functions
├── LICENSE                       # Open-source license
├── README.md                     # Chinese project documentation
└── README_en.md                  # English project documentation
```

### 9. Development Conventions

- **Bundles first**: implement new system components as independent bundles under `src/minimal_overlay/bundles/` whenever possible.
- **Init compatibility**: services must support BusyBox init and must not require systemd by default.
- **Shell scripts**: use POSIX Shell and exit immediately on failures.
- **Verified updates**: validate all downloaded update content and never overwrite the active release directly.
- **Management network**: management APIs should listen only on trusted networks by default; production deployments must enable TLS.
- **Validation**: after changing the build process, run at least shell syntax checks and basic QEMU/Docker validation.

### 10. Related Projects

- **[FasterEdge](https://github.com/FasterEdge/FasterEdge)**: the edge computing framework.
- **[FasterEdge2Api](https://github.com/FasterEdge/FasterEdge2Api)**: an HTTP API for FasterEdge cluster topology and system management.

### 11. License

This project is licensed under the [GNU General Public License version 3](LICENSE). Linux, GNU C Library, BusyBox and other third-party components remain subject to their respective original licenses.
