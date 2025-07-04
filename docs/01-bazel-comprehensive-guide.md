# Comprehensive Bazel Guide for Rust Firmware Project

## Table of Contents
1. [Introduction to Bazel](#introduction-to-bazel)
2. [WORKSPACE.bazel Explained](#workspacebazel-explained)
3. [BUILD.bazel Files](#buildbazel-files)
4. [.bazelrc Configuration](#bazelrc-configuration)
5. [Bazel Commands and Usage](#bazel-commands-and-usage)
6. [Understanding Rules and Targets](#understanding-rules-and-targets)
7. [Dependency Management](#dependency-management)
8. [Platform-Specific Builds](#platform-specific-builds)

## Introduction to Bazel

Bazel is Google's build system that provides:
- **Hermetic builds**: Reproducible builds regardless of environment
- **Incremental builds**: Only rebuilds what changed
- **Multi-language support**: Single build system for C++, Rust, Python, etc.
- **Scalability**: Works for small projects to massive monorepos

### Key Concepts

1. **Workspace**: The root directory containing your source code
2. **Package**: A directory containing a BUILD.bazel file
3. **Target**: A buildable unit defined in BUILD files
4. **Rule**: A function that defines how to build targets
5. **Label**: A unique identifier for a target (e.g., `//firmware:firmware`)

## WORKSPACE.bazel Explained

Let's break down our WORKSPACE.bazel file line by line:

```python
workspace(name = "rust_firmware_bazel")
```
This declares the workspace name, used to reference targets from external workspaces.

### Loading HTTP Archive Rule

```python
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
```
- `load()`: Imports functions from other Bazel files
- `@bazel_tools`: Built-in Bazel repository
- `http_archive`: Function to download and extract archives

### Rules Rust Setup

```python
http_archive(
    name = "rules_rust",
    sha256 = "36ab8f9facae745c9c9c1b33d225623d976e78f2cc3f729b7973d8c20934ab95",
    urls = ["https://github.com/bazelbuild/rules_rust/releases/download/0.31.0/rules_rust-v0.31.0.tar.gz"],
)
```

This downloads the Rust rules for Bazel:
- `name`: Local name for this external dependency
- `sha256`: Ensures integrity of downloaded file
- `urls`: Where to download from (can list multiple for redundancy)

### Rust Toolchain Registration

```python
load("@rules_rust//rust:repositories.bzl", "rules_rust_dependencies", "rust_register_toolchains")

rules_rust_dependencies()

rust_register_toolchains(
    edition = "2021",
    versions = ["1.75.0"],
    extra_target_triples = [
        "thumbv7em-none-eabihf",
        "riscv32imac-unknown-none-elf",
    ],
)
```

This sets up Rust toolchains:
- `edition`: Rust edition to use
- `versions`: Rust compiler version
- `extra_target_triples`: Cross-compilation targets
  - `thumbv7em-none-eabihf`: ARM Cortex-M4F target
  - `riscv32imac-unknown-none-elf`: RISC-V 32-bit target

### Crate Universe Setup

```python
load("@rules_rust//crate_universe:repositories.bzl", "crate_universe_dependencies")
crate_universe_dependencies()

load("@rules_rust//crate_universe:defs.bzl", "crates_repository")

crates_repository(
    name = "firmware_deps",
    cargo_lockfile = "//firmware:Cargo.lock",
    manifests = ["//firmware:Cargo.toml"],
)
```

Crate Universe manages Rust dependencies:
- Reads Cargo.toml and Cargo.lock
- Generates Bazel targets for each crate
- Handles transitive dependencies

### Loading Generated Dependencies

```python
load("@firmware_deps//:defs.bzl", firmware_deps = "crate_repositories")
firmware_deps()
```

This loads the generated dependency definitions.

## BUILD.bazel Files

### Root BUILD.bazel

```python
load("@bazel_skylib//rules:common_settings.bzl", "bool_flag")

bool_flag(
    name = "enable_logs",
    build_setting_default = False,
)
```

This creates build configuration flags:
- `bool_flag`: A boolean build setting
- Can be set via command line: `--//:enable_logs=true`

### Platform Constraints

```python
constraint_setting(name = "mcu")

constraint_value(
    name = "cortex_m4",
    constraint_setting = ":mcu",
)
```

This defines platform constraints:
- `constraint_setting`: A category of constraints (like CPU type)
- `constraint_value`: Specific values for that category

### Firmware BUILD.bazel

```python
load("@rules_rust//rust:defs.bzl", "rust_binary")
load("@firmware_deps//:defs.bzl", "all_crate_deps")

rust_binary(
    name = "firmware",
    srcs = glob(["src/**/*.rs"]),
    edition = "2021",
    deps = all_crate_deps(),
    rustc_flags = [
        "--target=thumbv7em-none-eabihf",
        "-C", "link-arg=-Tlink.x",
    ],
    crate_features = ["cortex-m-target"],
    visibility = ["//visibility:public"],
)
```

Let's break down each attribute:
- `name`: Target name (referenced as `//firmware:firmware`)
- `srcs`: Source files (glob finds all .rs files)
- `edition`: Rust edition
- `deps`: Dependencies from Cargo.toml
- `rustc_flags`: Compiler flags
  - `--target`: Cross-compilation target
  - `-C link-arg=-Tlink.x`: Linker script
- `crate_features`: Cargo features to enable
- `visibility`: Who can depend on this target

## .bazelrc Configuration

The .bazelrc file contains build configuration:

```bash
# Rust configuration
build --@rules_rust//:strict_deps=off
build --@rules_rust//:extra_rustc_flags=-Copt-level=z,-Clto=fat,-Cpanic=abort
```

- `strict_deps`: Whether to enforce explicit dependencies
- `extra_rustc_flags`: Additional compiler flags
  - `-Copt-level=z`: Optimize for size
  - `-Clto=fat`: Link-time optimization
  - `-Cpanic=abort`: Panic behavior

```bash
# Embedded targets
build:thumb --platforms=//platforms:thumbv7em
build:riscv --platforms=//platforms:riscv32
```

Named configurations:
- Use with `bazel build --config=thumb`
- Sets the target platform

## Bazel Commands and Usage

### Basic Commands

```bash
# Build a target
bazel build //firmware:firmware

# Build with configuration
bazel build --config=thumb //firmware:firmware

# Build all targets in a package
bazel build //firmware:all

# Run a binary
bazel run //qemu:run_qemu

# Test targets
bazel test //firmware:all_tests

# Clean build artifacts
bazel clean
```

### Query Commands

```bash
# Show all targets in a package
bazel query //firmware:*

# Show dependencies of a target
bazel query "deps(//firmware:firmware)"

# Show reverse dependencies
bazel query "rdeps(..., //firmware:firmware)"
```

### Useful Flags

```bash
# Verbose output
bazel build -s //firmware:firmware

# Show command lines
bazel build --subcommands //firmware:firmware

# Keep going on failure
bazel build -k //firmware:all

# Build in parallel
bazel build --jobs=8 //firmware:firmware
```

## Understanding Rules and Targets

### Target Naming

Targets are referenced by labels:
- `//firmware:firmware` - Absolute label
- `:firmware` - Relative label (within same package)
- `//firmware` - Package default target

### Common Rules

1. **rust_binary**: Produces executable
2. **rust_library**: Produces library
3. **rust_test**: Produces test executable
4. **cc_binary**: C++ executable
5. **cc_library**: C++ library

### Target Visibility

```python
visibility = ["//visibility:public"]    # Anyone can use
visibility = ["//visibility:private"]   # Only same package
visibility = ["//other:__pkg__"]       # Specific packages
```

## Dependency Management

### Internal Dependencies

```python
rust_library(
    name = "peripheral",
    srcs = ["peripheral.rs"],
)

rust_binary(
    name = "firmware",
    srcs = ["main.rs"],
    deps = [":peripheral"],  # Internal dependency
)
```

### External Dependencies

1. **Via Cargo/Crate Universe** (Recommended for Rust):
   - Define in Cargo.toml
   - Bazel generates targets automatically

2. **Direct http_archive**:
   ```python
   http_archive(
       name = "some_lib",
       urls = ["https://..."],
       sha256 = "...",
   )
   ```

## Platform-Specific Builds

### Platform Definition

```python
platform(
    name = "thumbv7em",
    constraint_values = [
        "@platforms//cpu:armv7e-m",
        "//:cortex_m4",
    ],
    exec_properties = {
        "target_triple": "thumbv7em-none-eabihf",
    },
)
```

### Using Platforms

```bash
# Build for specific platform
bazel build --platforms=//platforms:thumbv7em //firmware:firmware

# Query platform info
bazel query --output=build //platforms:thumbv7em
```

### Conditional Compilation

```python
select({
    "//platforms:thumbv7em": [":arm_specific_dep"],
    "//platforms:riscv32": [":riscv_specific_dep"],
    "//conditions:default": [],
})
```

## Best Practices

1. **Keep BUILD files focused**: One package per logical component
2. **Use visibility**: Explicitly control dependencies
3. **Pin versions**: Always use sha256 for external deps
4. **Use .bazelignore**: Exclude unnecessary directories
5. **Cache wisely**: Use remote cache for CI/CD

## Common Issues and Solutions

### Issue: "No such target"
- Check spelling and package path
- Ensure BUILD.bazel exists in that directory

### Issue: "Cycle in dependency graph"
- Use `bazel query` to find the cycle
- Refactor to break circular dependencies

### Issue: Slow builds
- Use `--jobs` to increase parallelism
- Enable remote caching
- Check for unnecessary dependencies

## Next Steps

Now that you understand Bazel, proceed to:
- [Rust Embedded Programming Guide](02-rust-embedded-guide.md)
- [SystemC/TLM Documentation](03-systemc-guide.md)