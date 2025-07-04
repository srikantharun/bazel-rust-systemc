# Troubleshooting and FAQ Guide

## Table of Contents
1. [Common Build Issues](#common-build-issues)
2. [Rust Compilation Problems](#rust-compilation-problems)
3. [SystemC Build Issues](#systemc-build-issues)
4. [QEMU Simulation Problems](#qemu-simulation-problems)
5. [Bazel-Specific Issues](#bazel-specific-issues)
6. [Toolchain Problems](#toolchain-problems)
7. [Memory and Performance Issues](#memory-and-performance-issues)
8. [Debugging Techniques](#debugging-techniques)
9. [FAQ](#faq)

## Common Build Issues

### Issue: "No such file or directory"

**Problem:**
```bash
ERROR: BUILD file not found in any of the following directories
```

**Cause:** Missing BUILD.bazel file in directory

**Solution:**
```bash
# Create empty BUILD.bazel file
touch some/directory/BUILD.bazel

# Or add to .bazelignore if not needed
echo "some/directory" >> .bazelignore
```

### Issue: "No such target"

**Problem:**
```bash
ERROR: no such target '//firmware:firmware_debug'
```

**Cause:** Target doesn't exist in BUILD.bazel

**Solution:**
```bash
# List all targets in package
bazel query //firmware:*

# Check BUILD.bazel file for correct target name
cat firmware/BUILD.bazel
```

### Issue: "Cycle in dependency graph"

**Problem:**
```bash
ERROR: Cycle in dependency graph
```

**Cause:** Circular dependencies between targets

**Solution:**
```bash
# Find the cycle
bazel query --output=graph //firmware:firmware | grep cycle

# Break the cycle by refactoring dependencies
# Move common code to separate library
```

### Issue: "Permission denied"

**Problem:**
```bash
ERROR: Permission denied while running action
```

**Cause:** Script not executable or file permissions

**Solution:**
```bash
# Make scripts executable
chmod +x tools/*.sh
chmod +x qemu/run_qemu.sh

# Fix file permissions
find . -name "*.sh" -exec chmod +x {} \;
```

## Rust Compilation Problems

### Issue: "Cannot find crate"

**Problem:**
```bash
error[E0463]: can't find crate for `cortex_m`
```

**Cause:** Missing dependency or crate universe not updated

**Solution:**
```bash
# Update crate universe
bazel sync

# Check Cargo.toml dependencies
cat firmware/Cargo.toml

# Force regeneration
bazel clean
bazel build //firmware:firmware
```

### Issue: "Linker script not found"

**Problem:**
```bash
error: could not find linker script `link.x`
```

**Cause:** Missing linker script or incorrect path

**Solution:**
```bash
# Check if cortex-m-rt provides link.x
bazel query --output=build //firmware:firmware | grep link

# Add custom linker script
rustc_flags = [
    "--target=thumbv7em-none-eabihf",
    "-C", "link-arg=-T$(location //rust/toolchain:memory.x)",
],
data = ["//rust/toolchain:memory.x"],
```

### Issue: "Multiple definition of main"

**Problem:**
```bash
error: symbol `main` is defined multiple times
```

**Cause:** Multiple entry points defined

**Solution:**
```bash
# Check for multiple #[entry] functions
grep -r "#\[entry\]" firmware/src/

# Use feature flags to select entry point
#[cfg(feature = "cortex-m-target")]
#[entry]
fn main() -> ! { }
```

### Issue: "Stack overflow"

**Problem:**
```bash
HardFault exception (stack overflow)
```

**Cause:** Insufficient stack size or deep recursion

**Solution:**
```rust
// In memory.x, increase stack size
_stack_start = ORIGIN(RAM) + LENGTH(RAM);
_stack_size = 4K;  /* Increase from 1K */

// Or check for deep recursion
// Use iterative algorithms instead of recursive
```

### Issue: "Undefined reference"

**Problem:**
```bash
undefined reference to `__aeabi_unwind_cpp_pr0`
```

**Cause:** Missing runtime libraries or wrong target

**Solution:**
```bash
# Add linker flags
rustc_flags = [
    "--target=thumbv7em-none-eabihf",
    "-C", "link-arg=-lgcc",
    "-C", "link-arg=--specs=nosys.specs",
],
```

## SystemC Build Issues

### Issue: "SystemC not found"

**Problem:**
```bash
fatal error: systemc: No such file or directory
```

**Cause:** SystemC not installed or not in search path

**Solution:**
```bash
# Install SystemC
sudo apt-get install libsystemc-dev

# Or add to WORKSPACE.bazel
http_archive(
    name = "systemc",
    urls = ["https://github.com/accellera-official/systemc/archive/refs/tags/2.3.4.tar.gz"],
    build_file = "@//third_party:systemc.BUILD",
)
```

### Issue: "TLM headers not found"

**Problem:**
```bash
fatal error: tlm: No such file or directory
```

**Cause:** TLM headers not included with SystemC

**Solution:**
```bash
# Check SystemC installation
ls /usr/include/systemc/tlm*

# Add include path
cc_library(
    name = "peripheral_model",
    copts = ["-I/usr/include/systemc"],
    deps = ["@systemc//:systemc"],
)
```

### Issue: "C++ standard version"

**Problem:**
```bash
error: 'constexpr' does not name a type
```

**Cause:** Wrong C++ standard (need C++11 or later)

**Solution:**
```bash
# Set C++14 standard
cc_library(
    name = "peripheral_model",
    copts = ["-std=c++14"],
)
```

### Issue: "Simulation hangs"

**Problem:** SystemC simulation doesn't terminate

**Cause:** No sc_stop() called or deadlock

**Solution:**
```cpp
// Add timeout
SC_THREAD(timeout_watchdog);

void timeout_watchdog() {
    wait(1, sc_core::SC_MS);  // 1ms timeout
    sc_core::sc_stop();
    SC_REPORT_ERROR("TIMEOUT", "Simulation timeout");
}

// Or add sc_stop() in test
void run_test() {
    // ... test code ...
    sc_core::sc_stop();
}
```

## QEMU Simulation Problems

### Issue: "QEMU not found"

**Problem:**
```bash
qemu-system-arm: command not found
```

**Cause:** QEMU not installed or not in PATH

**Solution:**
```bash
# Install QEMU
sudo apt-get install qemu-system-arm

# Or on macOS
brew install qemu

# Check installation
which qemu-system-arm
qemu-system-arm --version
```

### Issue: "No bootable device"

**Problem:**
```bash
qemu: fatal: Trying to execute code outside RAM or ROM
```

**Cause:** Incorrect memory layout or bootloader issue

**Solution:**
```bash
# Check memory.x layout
cat rust/toolchain/memory.x

# Verify firmware loads at correct address
qemu-system-arm -machine lm3s6965evb -nographic -kernel firmware.elf -d in_asm
```

### Issue: "GDB connection failed"

**Problem:**
```bash
Remote connection closed
```

**Cause:** GDB server not started or wrong port

**Solution:**
```bash
# Start QEMU with GDB server
qemu-system-arm -machine lm3s6965evb -kernel firmware.elf -S -s

# Connect GDB to correct port
arm-none-eabi-gdb -ex "target remote localhost:1234" firmware.elf
```

### Issue: "Semihosting not working"

**Problem:** Printf output not visible

**Cause:** Semihosting not enabled

**Solution:**
```bash
# Enable semihosting
qemu-system-arm -machine lm3s6965evb \
    -semihosting-config enable=on,target=native \
    -kernel firmware.elf
```

## Bazel-Specific Issues

### Issue: "Repository not found"

**Problem:**
```bash
ERROR: Repository '@rules_rust' not found
```

**Cause:** Network issues or wrong URL in WORKSPACE.bazel

**Solution:**
```bash
# Clean and re-fetch
bazel clean --expunge
bazel sync

# Check network connectivity
curl -I https://github.com/bazelbuild/rules_rust/releases/download/0.31.0/rules_rust-v0.31.0.tar.gz

# Use mirror URLs
http_archive(
    name = "rules_rust",
    urls = [
        "https://github.com/bazelbuild/rules_rust/releases/download/0.31.0/rules_rust-v0.31.0.tar.gz",
        "https://mirror.bazel.build/github.com/bazelbuild/rules_rust/releases/download/0.31.0/rules_rust-v0.31.0.tar.gz",
    ],
)
```

### Issue: "SHA256 mismatch"

**Problem:**
```bash
ERROR: SHA256 mismatch for downloaded file
```

**Cause:** File corrupted or wrong SHA256

**Solution:**
```bash
# Re-download and check SHA256
curl -L https://github.com/bazelbuild/rules_rust/releases/download/0.31.0/rules_rust-v0.31.0.tar.gz | sha256sum

# Update SHA256 in WORKSPACE.bazel
sha256 = "correct_sha256_here",
```

### Issue: "Stale lock file"

**Problem:**
```bash
ERROR: Another command is running
```

**Cause:** Previous build interrupted

**Solution:**
```bash
# Remove lock file
rm -rf ~/.cache/bazel/*/server/server.pid.txt

# Or use different output base
bazel --output_base=/tmp/bazel_custom build //firmware:firmware
```

### Issue: "Out of disk space"

**Problem:**
```bash
ERROR: No space left on device
```

**Cause:** Bazel cache consuming too much space

**Solution:**
```bash
# Clean cache
bazel clean --expunge

# Set cache size limit
bazel --disk_cache_size=1GB build //firmware:firmware

# Move cache to different disk
bazel --disk_cache=/mnt/large_disk/.bazel_cache build //firmware:firmware
```

## Toolchain Problems

### Issue: "Toolchain not found"

**Problem:**
```bash
ERROR: No toolchain found for target platform
```

**Cause:** Toolchain not registered or incompatible

**Solution:**
```bash
# Check registered toolchains
bazel query --output=build @rules_rust//rust:toolchains

# Register additional toolchains
rust_register_toolchains(
    extra_target_triples = ["thumbv7em-none-eabihf"],
)

# Debug toolchain resolution
bazel build --toolchain_resolution_debug //firmware:firmware
```

### Issue: "Cross-compilation failed"

**Problem:**
```bash
error: linker `arm-none-eabi-gcc` not found
```

**Cause:** Cross-compilation toolchain not installed

**Solution:**
```bash
# Install ARM toolchain
sudo apt-get install gcc-arm-none-eabi

# Or on macOS
brew install --cask gcc-arm-embedded

# Verify installation
arm-none-eabi-gcc --version
```

### Issue: "Wrong target architecture"

**Problem:**
```bash
error: cannot produce cdylib for target thumbv7em-none-eabihf
```

**Cause:** Wrong crate type for embedded target

**Solution:**
```python
# Use rust_binary instead of rust_library
rust_binary(
    name = "firmware",
    crate_type = "bin",  # Not "cdylib"
)
```

## Memory and Performance Issues

### Issue: "Build too slow"

**Problem:** Builds take very long time

**Cause:** No caching or too many rebuilds

**Solution:**
```bash
# Enable disk cache
bazel --disk_cache=~/.bazel_cache build //firmware:firmware

# Use remote cache
bazel --remote_cache=grpc://cache-server:9090 build //firmware:firmware

# Parallel builds
bazel build --jobs=8 //firmware:firmware

# Check what's being rebuilt
bazel build --explain=explain.txt //firmware:firmware
```

### Issue: "Out of memory"

**Problem:**
```bash
ERROR: Java heap space
```

**Cause:** Insufficient JVM memory for Bazel

**Solution:**
```bash
# Increase JVM heap size
export BAZEL_JAVA_HEAP_SIZE=4g

# Or set in .bazelrc
startup --host_jvm_args=-Xmx4g

# Use less parallel jobs
bazel build --jobs=2 //firmware:firmware
```

### Issue: "Firmware too large"

**Problem:** Binary doesn't fit in flash memory

**Cause:** Inefficient compilation or too much debug info

**Solution:**
```bash
# Size optimization
rustc_flags = [
    "-C", "opt-level=z",      # Optimize for size
    "-C", "lto=fat",          # Link-time optimization
    "-C", "panic=abort",      # Smaller panic handler
    "-C", "codegen-units=1",  # Better optimization
],

# Strip debug info
rustc_flags = ["-C", "strip=symbols"],

# Check binary size
size bazel-bin/firmware/firmware
```

## Debugging Techniques

### Bazel Query Commands

```bash
# Show all targets
bazel query //...

# Show dependencies
bazel query "deps(//firmware:firmware)"

# Show reverse dependencies
bazel query "rdeps(//..., //firmware:firmware)"

# Show build graph
bazel query --output=graph //firmware:firmware | dot -Tpng > graph.png
```

### Verbose Build Output

```bash
# Show all commands
bazel build --subcommands //firmware:firmware

# Show compilation commands
bazel build --verbose_failures //firmware:firmware

# Show sandbox contents
bazel build --sandbox_debug //firmware:firmware
```

### Binary Analysis

```bash
# Check binary format
file bazel-bin/firmware/firmware

# Show symbols
nm bazel-bin/firmware/firmware

# Show sections
objdump -h bazel-bin/firmware/firmware

# Disassemble
objdump -d bazel-bin/firmware/firmware
```

### SystemC Debugging

```cpp
// Enable debug messages
SC_REPORT_INFO("DEBUG", "Message");

// Trace signals
sc_trace_file* tf = sc_create_vcd_trace_file("debug");
sc_trace(tf, signal, "signal_name");

// Add breakpoints
SC_THREAD(debug_process);
void debug_process() {
    wait(100, SC_NS);
    sc_assert(condition);  // Breakpoint condition
}
```

## FAQ

### Q: How do I add a new Rust dependency?

**A:** Add to `firmware/Cargo.toml`, then run `bazel sync`:

```toml
[dependencies]
new_crate = "1.0"
```

```bash
bazel sync
bazel build //firmware:firmware
```

### Q: How do I change the target MCU?

**A:** 
1. Update target triple in WORKSPACE.bazel
2. Modify memory.x layout
3. Update BUILD.bazel rustc_flags
4. Add new platform definition

### Q: How do I add SystemC debug output?

**A:** Use SC_REPORT macros:

```cpp
SC_REPORT_INFO("MODULE", "Debug message");
SC_REPORT_WARNING("MODULE", "Warning message");
```

### Q: How do I profile build performance?

**A:** Use Bazel profiling:

```bash
bazel build --profile=profile.json //firmware:firmware
bazel analyze-profile profile.json
```

### Q: How do I run tests in the embedded environment?

**A:** Use QEMU for integration tests:

```python
rust_test(
    name = "integration_test",
    crate = ":firmware",
    env = {"CARGO_TARGET_THUMBV7EM_NONE_EABIHF_RUNNER": "qemu-system-arm"},
)
```

### Q: How do I debug memory layout issues?

**A:** Check the map file:

```bash
# Generate map file
rustc_flags = ["-C", "link-arg=-Wl,-Map=firmware.map"],

# Analyze memory usage
grep -E "^\.text|^\.data|^\.bss" firmware.map
```

### Q: How do I add custom linker scripts?

**A:** Reference in BUILD.bazel:

```python
rust_binary(
    name = "firmware",
    data = ["//rust/toolchain:memory.x"],
    rustc_flags = [
        "-C", "link-arg=-T$(location //rust/toolchain:memory.x)",
    ],
)
```

### Q: How do I configure different optimization levels?

**A:** Use config_setting:

```python
config_setting(
    name = "debug_build",
    values = {"compilation_mode": "dbg"},
)

rust_binary(
    name = "firmware",
    rustc_flags = select({
        ":debug_build": ["-C", "opt-level=0"],
        "//conditions:default": ["-C", "opt-level=z"],
    }),
)
```

### Q: How do I handle platform-specific code?

**A:** Use cfg attributes:

```rust
#[cfg(feature = "cortex-m-target")]
use cortex_m_rt::entry;

#[cfg(feature = "riscv-target")]
use riscv_rt::entry;
```

### Q: How do I set up remote caching?

**A:** Configure in .bazelrc:

```bash
# Remote cache server
build --remote_cache=grpc://cache-server:9090
build --remote_upload_local_results=true

# Authentication (if needed)
build --google_credentials=/path/to/credentials.json
```

### Q: How do I troubleshoot intermittent build failures?

**A:** Use build event stream:

```bash
# Log all build events
bazel build --build_event_text_file=build_events.txt //firmware:firmware

# Check for race conditions
bazel build --jobs=1 //firmware:firmware
```

## Getting Help

### Resources

1. **Bazel Documentation**: https://bazel.build/
2. **Rules Rust**: https://github.com/bazelbuild/rules_rust
3. **Embedded Rust Book**: https://rust-embedded.github.io/book/
4. **SystemC Documentation**: https://systemc.org/

### Community Support

1. **Bazel Slack**: https://slack.bazel.build/
2. **Rust Embedded Matrix**: https://matrix.to/#/#rust-embedded:matrix.org
3. **SystemC Forum**: https://forums.accellera.org/forum/9-systemc/

### Filing Issues

When filing issues, include:
1. Complete error message
2. Minimal reproduction case
3. Environment details (OS, Bazel version, etc.)
4. Output of `bazel info`

Example:
```bash
# Collect environment info
bazel info
bazel version
rustc --version
uname -a
```

## Next Steps

Continue to:
- [Quick Reference Guide](06-quick-reference.md)
- Return to [README](../README.md)