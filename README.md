<div align="center">
  <h1 align="center">Liberated OS</h1>
  <p align="center">Liberated Linux kernels with no surveillance. Ever.</p>
  <p align="center">Based on <a href="https://github.com/CachyOS/linux-cachyos">CachyOS</a> kernels + <a href="https://github.com/Jeffrey-Sardina/systemd">Liberated systemd</a></p>
</div>

## What is LiberatedOS?

LiberatedOS combines the high-performance CachyOS Linux kernels with Jeffrey-Sardina's Liberated systemd -- a fork of systemd with all surveillance and telemetry removed. No age verification. No hardware survey. No phone-home. Ever.

### Why Liberated systemd?

The upstream `systemd/systemd` project contains surveillance features:
- **Age verification** via `repart.d` (UKI age verification key support)
- **Hardware survey** (`systemd-hwdb` telemetry upload to Red Hat/Fedora servers)
- **Microsoft integration** via `systemd-oomd` and other components

Liberated systemd strips all of this out. See [Jeffrey-Sardina/systemd](https://github.com/Jeffrey-Sardina/systemd) for details.

## Kernel Variants & Schedulers

Each scheduler is optimized for different use cases. We recommend testing each one to find the best fit for your specific requirements.

### Available Schedulers

| Scheduler | Full Name | Package(s) | Best for... | Developer |
| :-- | :-- | :-- | :-- | :-- |
| **BORE** | Burst-Oriented Response Enhancer | `linux-cachyos-bore` | Interactive workloads & gaming | [firelzrd](https://github.com/firelzrd) |
| **EEVDF** | Earliest Eligible Virtual Deadline First | `linux-cachyos`, `linux-cachyos-eevdf` | General-purpose computing | Peter Zijlstra |
| **BMQ** | Bit Map Queue CPU Scheduler | `linux-cachyos-bmq` | N/A | [Alfred Chen](https://gitlab.com/alfredchen) |

### Specialized Variants

- **`linux-cachyos-hardened`** - Security-focused kernel with hardening patches
- **`linux-cachyos-lts`** - Long Term Support version for stability
- **`linux-cachyos-rt-bore`** - Real-time kernel with BORE scheduler
- **`linux-cachyos-server`** - Server-optimized configuration
- **`linux-cachyos-deckify`** - Steam Deck optimized variant

## Features

### Performance Optimizations

- **Advanced Compilation**: Highly customizable PKGBUILD with support for both GCC and Clang compilers
- **Link Time Optimization (LTO)**: Thin LTO enabled by default for better performance
- **Profile-Guided Optimization**: AutoFDO + Propeller profiling for optimal code generation
- **Timer Frequency Options**: Configurable between 300Hz, 500Hz, 600Hz, 750Hz, and 1000Hz (default: 1000Hz)
- **Architecture Optimizations**: Support for x86-64-v3, x86-64-v4, and AMD Zen4 specific builds

### CPU Enhancements

- **Multiple Schedulers**: BORE, EEVDF, and BMQ schedulers for different workload optimization
- **AMD P-State Enhancements**: Preferred Core support and latest amd-pstate improvements
- **Real-Time Support**: RT kernel builds available with BORE scheduler integration
- **CachyOS Sauce**: Custom `CONFIG_CACHY` configuration with scheduler and system tweaks
- **Low-Latency Optimizations**: Patches for improved responsiveness and reduced jitter

### Filesystem & Memory

- **ZFS Support**: Built-in ZFS filesystem support with pre-compiled modules
- **NVIDIA Integration**: Proprietary and open-source NVIDIA driver support
- **I/O Scheduler Improvements**: Enhanced BFQ and mq-deadline performance
- **Memory Management**: le9uo patch for preventing page thrashing, Zen-kernel memory management tweaks

### Hardware Support

- **Gaming Hardware**: Steam Deck patches and ROG Ally support
- **Apple Hardware**: T2 MacBook support included by default
- **ASUS Hardware**: Extended ASUS hardware compatibility patches
- **Graphics**: HDR support enabled, AMDGPU min_powercap override

## Repository Structure

```
LiberatedOS/
├── systemd/                    # Liberated systemd (Jeffrey-Sardina/systemd)
├── linux-cachyos/              # EEVDF scheduler (default)
├── linux-cachyos-bore/         # BORE scheduler
├── linux-cachyos-bmq/          # BMQ scheduler
├── linux-cachyos-deckify/      # Steam Deck optimized
├── linux-cachyos-eevdf/        # EEVDF scheduler
├── linux-cachyos-hardened/     # Security-hardened
├── linux-cachyos-lts/          # Long Term Support
├── linux-cachyos-rc/           # Release Candidate
├── linux-cachyos-rt-bore/      # Real-time + BORE
├── linux-cachyos-server/       # Server-optimized
└── ...
```

## Credits

- **[CachyOS](https://cachyos.org)** - Base kernel packages and optimizations
- **[Jeffrey-Sardina](https://github.com/Jeffrey-Sardina/systemd)** - Liberated systemd fork
- **[firelzrd](https://github.com/firelzrd/bore-scheduler)** - BORE Scheduler developer
- **[Arch Linux](https://archlinux.org/)** - Foundation distribution
- **[Linux Kernel Community](https://github.com/torvalds/linux)** - Upstream kernel development

## License

GPL-3.0 - See [LICENSE.md](LICENSE.md) for details.
