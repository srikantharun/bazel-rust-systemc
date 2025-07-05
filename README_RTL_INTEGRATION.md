# RTL Integration with Bazel-Rust-SystemC

This guide explains how to compile RTL (Verilog/SystemVerilog) alongside Rust-SystemC in a Bazel monorepo.

## Setup

### 1. Install RTL Tools

Install the required RTL tools in `/usr/local/rtl_tools/`:
- Icarus Verilog (for simulation)
- Yosys (for synthesis)
- Python with Jinja2 (for template generation)

```bash
# Example installation
brew install icarus-verilog yosys
pip install jinja2
```

### 2. Configure WORKSPACE

The WORKSPACE.bazel file has been configured with:
- RTL toolchain registration
- RTL tools repository
- Python dependencies for template generation

### 3. Build Structure

```
bazel-rust-systemc/
├── WORKSPACE.bazel          # RTL tools configuration
├── BUILD.bazel              # Root build with integration examples
├── .bazelrc                 # Build configurations
├── tools/
│   └── rtl/
│       ├── BUILD.bazel      # RTL toolchain definition
│       ├── rtl_rules.bzl    # RTL build rules
│       ├── requirements.txt # Python dependencies
│       └── templates/       # Jinja2 templates
└── rtl/
    └── memory/
        ├── BUILD.bazel      # Memory array builds
        ├── cells/           # Basic cell designs
        ├── controllers/     # Control logic
        └── systemc/         # SystemC wrappers
```

## Usage Examples

### Building a Memory Array

```bash
# Build a 256x256 edge AI array
bazel build //rtl/memory:edge_ai_array

# Build and synthesize a datacenter array
bazel build //rtl/memory:datacenter_array --config=rtl

# Run full system simulation
bazel run //:full_system_sim
```

### Using Memory Array Macro

```python
# In your BUILD.bazel file
load("//tools/rtl:rtl_rules.bzl", "memory_array")

memory_array(
    name = "custom_array",
    size = "512x512",
    cell_type = "sram",
    precision = "int8",
    power_mode = "balanced",
    synthesize = True,
    target_library = "tsmc_7nm",
)
```

### Integrating with Rust-SystemC

```rust
// In your Rust code
use systemc::*;

extern "C" {
    fn memory_array_init(size: u32) -> *mut c_void;
    fn memory_array_compute(handle: *mut c_void, data: *const u8) -> u32;
}

pub struct MemoryArray {
    handle: *mut c_void,
}

impl MemoryArray {
    pub fn new(size: u32) -> Self {
        unsafe {
            Self {
                handle: memory_array_init(size),
            }
        }
    }
}
```

## Build Configurations

### Local Build
```bash
bazel build //rtl/memory:edge_ai_array
```

### Memory-Optimized Build
```bash
bazel build //rtl/memory:datacenter_array --config=mem
```

### Distributed Build
```bash
bazel build //rtl/memory:datacenter_array --config=distributed
```

### CI/CD Build
```bash
bazel test //:memory_tests --config=ci
```

## Performance Optimization

1. **Hierarchical Builds**: Large arrays are built hierarchically (cell → tile → bank → array)
2. **Template Generation**: Repetitive structures use Jinja2 templates
3. **Distributed Builds**: Arrays >1M cells can be built across multiple machines
4. **Caching**: Bazel caches intermediate results for faster rebuilds

## Troubleshooting

1. **Tool Not Found**: Update paths in WORKSPACE.bazel `rtl_tools` repository
2. **Memory Issues**: Use `--config=mem` for large builds
3. **Synthesis Failures**: Check tool versions and target library compatibility

## Next Steps

1. Add more cell types (PCM, MRAM) in `rtl/cells/`
2. Implement advanced controllers in `rtl/controllers/`
3. Create SystemC testbenches for verification
4. Set up CI/CD pipeline with GitHub Actions