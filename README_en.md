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

> The current version is in the base-system adaptation stage. Linux Live ISO and BIOS/UEFI build foundations are present. The checked-in boot and QEMU scripts currently target x86/x86_64; the system initial tool (DontCrack-Manager multi-process root manager) is now integrated via the `fasteredgeos` overlay bundle (see section 5).
> **Actual multi-architecture status**: with `KERNEL_ARCH=arm64/arm` the build only produces the kernel `Image`/`zImage` and an initramfs. The ISO boot chain (Syslinux / systemd-boot) is still x86-specific and has not been verified on real hardware. See the degraded claims in section 7 ("Reproducible Builds, Multi-Architecture and Supply Chain").

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
  libelf-dev libssl-dev file cpio gzip xz-utils \
  dosfstools e2fsprogs
```

`dosfstools` and `e2fsprogs` are what make the FAT boot image and the ext2 overlay image byte-reproducible (`mkfs.vfat --invariant`, `mke2fs` with a pinned UUID); without them the scripts fall back to BusyBox `mkfs` and warn that the artefact is not reproducible.

Additional packages for AArch64 cross-builds and QEMU boot tests:

```bash
sudo apt install -y gcc-aarch64-linux-gnu qemu-system-aarch64
```

> The ISO boot chain (Syslinux for BIOS, systemd-boot for UEFI) is x86-only. `KERNEL_ARCH=arm64` produces a kernel `Image` and an initramfs, not a bootable ISO.

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
KERNEL_ARCH=x86          # x86 / arm64 / arm (= the kernel Makefile ARCH value)
CROSS_COMPILE=           # cross-toolchain prefix, empty for a native build; e.g. aarch64-linux-gnu-
SOURCE_DATE_EPOCH=       # empty uses the default 1767225600; "timestamp" breaks reproducibility
```

`KERNEL_ARCH` and `CROSS_COMPILE` are driven by the architecture table in `src/02_build_kernel.sh`: `x86` produces `arch/x86/boot/bzImage`, `arm64` produces `arch/arm64/boot/Image`, and `arm` produces `arch/arm/boot/zImage`. All three come from the same `case` table, so no hard-coded x86 path remains.

The checked-in defaults also set:

```text
OVERLAY_BUNDLES=dhcp,fasteredgeos,fasteredge,any2pcd,any2utf8,fasteredge2api,mll_hello,mll_logo,mll_source
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

To verify that two builds are byte-for-byte identical:

```bash
cd src
make clean && make all
sha256sum fasteredgeos.iso fasteredgeos_image.tgz | tee /tmp/run1.txt
make clean && make all
sha256sum fasteredgeos.iso fasteredgeos_image.tgz | tee /tmp/run2.txt
diff /tmp/run1.txt /tmp/run2.txt && echo "byte-for-byte reproducible"
```

A static self-check that needs no compilation (syntax / timestamp values / tar·gzip byte equality / supply-chain coverage / architecture parameterisation):

```bash
cd src
./test_reproducible.sh
```

Full coverage and degraded claims are listed in section 7.

### 4. Boot and Test

#### 4.1 BIOS Mode

```bash
cd src
./qemu-bios.sh
```

The equivalent Make target is `make qemu-bios`.

The QEMU wrapper scripts (`src/qemu-bios.sh`, `src/qemu-uefi.sh`, `src/qemu-bios-console.sh`) select their QEMU binary from `KERNEL_ARCH` in `.config` (`x86` → `qemu-system-x86_64`/`qemu-system-i386`, `arm64` → `qemu-system-aarch64`, `arm` → `qemu-system-arm`) and fail on unknown values.

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

### 5. System Initial Tools & FasterEdge Service Deployment

FasterEdgeOS uses overlay bundles to add software to the final rootfs. FasterEdge components live under:

```text
src/minimal_overlay/bundles/fasteredgeos/
```

This bundle (the system initial tool) is now implemented:

- **Root process manager**: builds and installs `DontCrack-Manager`. A single DontCrack
  instance supervises exactly one child process; DontCrack-Manager supervises **multiple**
  DontCrack instances at once — a system-level multi-process root manager for this
  process-manager-free Live environment.
- **Config**: installs `/etc/fasteredgeos/manager.yaml` (per-service DontCrack flags,
  dependency ordering, probes, backoff restarts, graceful shutdown).
- **Startup**: installs `/etc/autorun/20_dontcrack-manager.sh`, which launches the root
  manager first during boot (setsid + background, log at `/var/log/fasteredgeos/manager.log`).
- **Demo child**: installs `/usr/bin/fasteredgeos-demo` (supervised by the demo service).
- **Directories**: initializes `/var/lib/fasteredgeos/` and `/var/log/fasteredgeos/`.

Enable it with:

```text
OVERLAY_BUNDLES=dhcp,fasteredgeos
```

The service model is compatible with BusyBox init and does not depend on systemd:

```text
BusyBox init
    ↓
/etc/inittab → /etc/04_bootscript.sh
    ↓
/etc/autorun/20_dontcrack-manager.sh
    ↓
DontCrack-Manager (root manager, /etc/fasteredgeos/manager.yaml)
    ↓
DontCrack instance × N (each supervising one child process)
```

Aggregated status (default listen `127.0.0.1:11884`):

```text
curl http://127.0.0.1:11884/healthz
curl http://127.0.0.1:11884/status
curl -X POST http://127.0.0.1:11884/shutdown
```

FasterEdge2Api (cluster topology / system-management API), the FasterEdge node runtime,
and signed, rollback-capable remote updates are planned on top of this manager; remote
updates must still follow "download → verify → install → health check → switch or rollback".

> CI builds (`manual.yml`) enable `OVERLAY_BUNDLES=dhcp,fasteredgeos` and provide a Go
> toolchain via `actions/setup-go`; local builds need Go 1.27.4+ installed.

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

### 7. Reproducible Builds, Multi-Architecture and Supply Chain

This section records what can be **verified with scripts in this repository**, and which claims are **explicitly degraded**. Every row maps to something you can actually run.

#### 7.1 One-shot self-check

```bash
cd src
./test_reproducible.sh
```

Exit code 0 means everything passed. It runs seven groups of checks:

| Group | Check | Really executed? |
|---|---|---|
| [1] | `bash -n` on every `*.sh` in the repository | yes |
| [2] | Values and `export` of `SOURCE_DATE_EPOCH` / `KBUILD_BUILD_TIMESTAMP` / `TZ=UTC` / `TAR_REPRODUCIBLE` / fixed UUIDs | yes (read back in a child process) |
| [3] | Two `tar $TAR_REPRODUCIBLE` runs over one tree produce identical bytes; all members are owned by 0/0 | yes (real packing and `cmp`) |
| [4] | Two `gzip -n` runs produce identical bytes with header MTIME 0; two `xz --threads=1` runs produce identical bytes | yes (real compression and `cmp`) |
| [5] | Every `download_source` target has a matching `.sha256` sidecar (supply-chain coverage) | yes (static parse; 38 targets, all covered) |
| [6] | Each sidecar's embedded filename matches its own name and the hash is 64 hex digits | yes |
| [7] | `KERNEL_IMAGE_TARGET` / `KERNEL_IMAGE_PATH` for all three architectures follow the kernel convention, with no hard-coded x86 path | yes |

CI gate: the `reproducible` job in `.github/workflows/check.yml` runs the same script on every push / pull request.

#### 7.2 How reproducibility is achieved

| Source of difference | Fix | File |
|---|---|---|
| Archive member order, mtime, ownership | `tar --sort=name --mtime=@$SOURCE_DATE_EPOCH --owner=0 --group=0 --numeric-owner` | `TAR_REPRODUCIBLE` in `src/common.sh` |
| Kernel build timestamp | `KBUILD_BUILD_TIMESTAMP=@$SOURCE_DATE_EPOCH`, `KBUILD_BUILD_USER/HOST` | `src/common.sh` |
| Host time zone leaking into formatted dates | `TZ=UTC` | `src/common.sh` |
| rootfs archive order | `find -print0 \| LC_ALL=C sort -z \| cpio -0` | `src/10_pack_rootfs.sh` |
| xz output variance | `xz -9 --check=crc32 --threads=1` (thread count pinned) | `src/10_pack_rootfs.sh`, `mll_source/bundle.sh` |
| gzip header name/timestamp | `gzip -n -9` | `src/15_generate_image.sh` |
| ext2 overlay UUID and creation time | `mke2fs -U $FEOS_OVERLAY_FS_UUID -E root_owner=0:0` with `E2FSPROGS_FAKE_TIME=$SOURCE_DATE_EPOCH` | `src/11_generate_overlay.sh` |
| FAT (UEFI boot image) internal timestamps | `mkfs.vfat --invariant` (recent dosfstools) | `src/13_prepare_iso.sh` |
| ISO volume dates / GPT disk GUID / file dates | xorriso's mkisofs emulation honours `SOURCE_DATE_EPOCH` natively (see ENVIRONMENT VARIABLES in `xorrisofs(1)`) | `src/14_generate_iso.sh` |
| Source archive name embedding a date | `date -u -d "@$SOURCE_DATE_EPOCH" +"%d-%b-%Y"` | `mll_source/bundle.sh` |

To check byte-for-byte equality across two builds:

```bash
cd src
make clean && make all
sha256sum fasteredgeos.iso fasteredgeos_image.tgz | tee /tmp/run1.txt
make clean && make all
sha256sum fasteredgeos.iso fasteredgeos_image.tgz | tee /tmp/run2.txt
diff /tmp/run1.txt /tmp/run2.txt && echo "byte-for-byte reproducible"
```

`14_generate_iso.sh` prints the ISO sha256 itself at the end, so the value also lands in CI logs.

#### 7.3 Supply-chain pinning (fail-closed)

Every source archive must have a same-named `.sha256` sidecar. A missing sidecar now **aborts the build** instead of silently skipping the check:

```text
src/source/<main-chain archive>.sha256          kernel / glibc / busybox / syslinux / systemd-boot
src/source/overlay/<overlay archive>.sha256     per-bundle overlay sources
```

A sidecar is plain `sha256sum` output (`<hex>  <filename>`) and is verified with `( cd <dir> && sha256sum -c <name>.sha256 )`. The sidecar **filename must match the destination name in `01_get.sh` character for character** (for example the `cf_cli` bundle writes `cf-cli.tgz`, not the upstream `cf8-cli_8.19.0_linux_x86-64.tgz`). Checks `[5]` and `[6]` exist to keep that invariant honest.

`make clean` deletes archives under `source/` but keeps `*.sha256`, so a routine clean does not turn the next build into a missing-sidecar failure.

**Known exception**: when `USE_LOCAL_SOURCE=true` and the file already exists, `download_source` takes the local branch and does **not** verify the sha256 (the pre-existing semantics, unchanged). This is deliberate: for offline distribution the integrity guarantee comes from the distribution medium. Set `USE_LOCAL_SOURCE=false` if you need the check enforced.

#### 7.4 Multi-architecture (x86 / AArch64)

With `KERNEL_ARCH` and `CROSS_COMPILE` parameterised:

```bash
# Native x86_64 / AArch64 build (default)
KERNEL_ARCH=x86    CROSS_COMPILE=                make all

# Cross-build an AArch64 kernel + initramfs on an x86_64 host
sudo apt install -y gcc-aarch64-linux-gnu
KERNEL_ARCH=arm64  CROSS_COMPILE=aarch64-linux-gnu-  make all
```

`02_build_kernel.sh` and `mll_logo/bundle.sh` share the same architecture table. With `KERNEL_ARCH=arm64` and an empty `CROSS_COMPILE`, the script exits with an error instead of quietly producing a wrong-architecture kernel.

#### 7.5 Coverage and degraded claims (stated honestly)

**Verified in this repository**

- `bash -n`: `scripts/lint.sh` covers 208 shell scripts (including extension-less ones picked up by shebang, such as `src/minimal_rootfs/init`) and exits 0; group `[1]` of `test_reproducible.sh` additionally checks all 205 `*.sh` files.
- shellcheck (v0.10.0, `-S error -S warning`): all 208 scripts are free of error / warning findings and `scripts/lint.sh` exits 0. What remains is `info`/`style`: `SC1091` (cannot follow `. ./common.sh`), `SC2006` (legacy backticks) and `SC2031` inside `test_reproducible.sh` — that last one is a cascade from `-x` following `common.sh`, whose `export SRC_DIR="$PWD"` happens in a subshell and does not affect this script.
- Byte-level equality at the `tar` / `gzip` layer: groups `[3]` / `[4]` of `test_reproducible.sh`, really executed.
- Supply-chain coverage: all 38 `download_source` targets have sidecars (`[5]`), and every sidecar is self-consistent (`[6]`).
- `KERNEL_ARCH` parameterisation plus the syntax/lint gates (`[7]`, `[1]`).

**Implemented but NOT verified in this environment (degraded claims)**

- **End-to-end byte-identical ISO**: not verified. It needs a real build (about one hour) plus `xorriso`, `e2fsprogs`, `dosfstools`, loop devices and root; the verification environment here has none of these. The implementation follows the `SOURCE_DATE_EPOCH` semantics documented in `xorrisofs(1)`, but **there is no recorded two-build hash comparison**. Verify with the commands in 7.2 on a Linux host before claiming it.
- **AArch64 / ARM ISO boot chain**: not verified. `FIRMWARE_TYPE=bios/uefi/both` and the Syslinux / systemd-boot boot files are still x86-only; arm64/arm currently only guarantee a kernel `Image`/`zImage` plus initramfs and **will not boot**. Real-hardware and `qemu-system-aarch64` boot were not tested.
- **`OVERLAY_TYPE=sparse` branch**: not verified. It needs root plus loop devices, which the Windows/WSL environment does not provide.
- **`mkfs.vfat --invariant` and `mke2fs -E root_owner`**: not verified. Neither `dosfstools` nor `e2fsprogs` is installed here, so only option probing was exercised; the scripts warn loudly and fall back when the tools are missing.
- **`USE_LOCAL_SOURCE=true` sidecar verification**: intentionally skipped (see the exception in 7.3).

**Degraded paths that break byte-level reproducibility, and warn explicitly**

- Falling back to BusyBox `mkfs.ext2` when the host lacks `mke2fs`: UUID and timestamps are unpinned, and stderr states plainly that the artefact is not byte-reproducible.
- When the host `mkfs.vfat` lacks `--invariant`: FAT internal timestamps still follow the build clock, with the same explicit warning.

Both are **noisy degradations**, never silent passes.

**Evaluation scope**

In this repository "reproducible" means: given the same source tree, `.config` and `SOURCE_DATE_EPOCH`, a Linux build host with the required dependencies produces a `fasteredgeos.iso` and `fasteredgeos_image.tgz` with identical sha256. What is automated here covers every link in that chain except the ISO / EXT2 / FAT packaging. The claim strength is therefore: **supply-chain pinning and byte-level reproducibility at the tar/gzip/cpio/xz layer are measured; byte-level reproducibility of the ISO and filesystem images is "implemented to spec, pending real-host verification"**.

### 8. Security

#### 8.1 Component Versions and Known-CVE Remediation

| Component | Old Version with Known Issues | Current Version | Notes |
|---|---|---|---|
| Linux kernel | 5.18.3, EOL since 2022-11 | 6.6.155 LTS | The configured source URL uses Linux 6.6.155; the README baseline notes LTS maintenance through 2026-12. |
| GNU C Library | 2.35, including known issues such as CVE-2023-4911, CVE-2024-2961 and CVE-2025-4802 | 2.44 | The configured source URL uses glibc 2.44. |
| BusyBox | 1.34.1, including known issues such as CVE-2022-48174 and CVE-2022-28391 | 1.37.0 | The project does not use the then-unstable 1.38.0 line. |
| Syslinux | 6.03 | 6.03 | No newer upstream version is configured; it is used only during BIOS boot. |
| systemd-boot | 2018 snapshot from the upstream fork | 2018 snapshot | Used only during UEFI boot. |

#### 8.2 Implemented Hardening

- **Compiler hardening**: build CFLAGS remove `-fno-stack-protector` and `-U_FORTIFY_SOURCE`, and enable `-fstack-protector-strong`. The BusyBox build separately enables `-D_FORTIFY_SOURCE=2`.
- **Kernel hardening**: `src/02_build_kernel.sh` explicitly enables `STACKPROTECTOR_STRONG`, `FORTIFY_SOURCE` and `SECURITY_DMESG_RESTRICT`.
- **CI dependencies**: the build environment includes `rsync`, which Linux 6.6+ requires for `headers_install`.

#### 8.3 Known Live-System Tradeoffs

- **Passwordless root**: the system enters a root shell without a password by default, following a traditional Live-system design. Use this only in isolated or development environments. For production, at minimum run:

  ```sh
  passwd root
  ```

  Persist `/etc/passwd` and `/etc/shadow` on writable media.

- **Multiple root consoles**: init starts root shells on `tty1` through `tty4` by default. To reduce exposure, remove unnecessary `tty2` through `tty4` respawn entries from `/etc/inittab`.
- **Dropbear disabled by default**: the default `OVERLAY_BUNDLES` does not include `dropbear`, so remote SSH login is not exposed by default. If enabled, set a root password and use key-based authentication.

#### 8.4 Persistence and Updates

- **Live-mode persistence**: with `OVERLAY_TYPE=folder` and `OVERLAY_LOCATION=iso`, changes are lost after reboot unless a writable `fasteredgeos/rootfs` plus `fasteredgeos/work` layout or a `fasteredgeos.img` image is provided. Production deployments should use writable persistent media or rebuild the image as part of the upgrade process.
- **Safe updates**: remote updates must follow the verification, installation, health-check and rollback sequence described above. Never overwrite the currently running version directly.

### 9. Repository Layout

```text
FasterEdgeOS/
├── src/                          # System source and build entry point
│   ├── .config                   # Main build configuration
│   ├── Makefile                  # make all/clean/qemu/test targets
│   ├── 00_* ~ 16_*              # Staged build scripts
│   ├── test_reproducible.sh      # Reproducibility + supply-chain self-check
│   ├── source/                   # Main-chain source archives + *.sha256 sidecars
│   ├── source/overlay/           # Overlay source archives + *.sha256 sidecars
│   ├── minimal_boot/             # BIOS/UEFI boot files
│   ├── minimal_config/           # Kernel and BusyBox configuration
│   ├── minimal_overlay/          # Overlay bundles
│   ├── minimal_rootfs/           # Base rootfs
│   └── common.sh                 # Shared build functions
├── scripts/                      # One-shot lint.sh static checks
├── LICENSE                       # Open-source license
├── README.md                     # Chinese project documentation
└── README_en.md                  # English project documentation
```

### 10. Development Conventions

- **Bundles first**: implement new system components as independent bundles under `src/minimal_overlay/bundles/` whenever possible.
- **Init compatibility**: services must support BusyBox init and must not require systemd by default.
- **Shell scripts**: use POSIX Shell and exit immediately on failures.
- **Verified updates**: validate all downloaded update content and never overwrite the active release directly.
- **Management network**: management APIs should listen only on trusted networks by default; production deployments must enable TLS.
- **Validation**: after changing the build process, run at least shell syntax checks, `src/test_reproducible.sh`, and basic QEMU/Docker validation.
- **One-shot lint**: `scripts/lint.sh` runs `bash -n`, `sh -n`, shellcheck (`-S error -S warning`, degrading to the two syntax checks when shellcheck is absent) plus `node --check` on `tools/*.mjs` and YAML/JSON parse validation. It works both in a local Git Bash and in CI; set `LINT_STRICT=1` to raise shellcheck to style level. Keep its exit code 0 before committing.
- **New downloads**: every source archive you add (main chain or overlay bundle) must ship with its `.sha256` sidecar in the same commit, otherwise `download_source` aborts the build (fail-closed).

### 11. Related Projects

- **[FasterEdge](https://github.com/FasterEdge/FasterEdge)**: the edge computing framework.
- **[FasterEdge2Api](https://github.com/FasterEdge/FasterEdge2Api)**: an HTTP API for FasterEdge cluster topology and system management.

### 12. License

This project is licensed under the [GNU General Public License version 3](LICENSE). Linux, GNU C Library, BusyBox and other third-party components remain subject to their respective original licenses.
