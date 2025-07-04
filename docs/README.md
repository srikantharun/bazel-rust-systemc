# Documentation Index

This directory contains comprehensive documentation for the Rust Firmware Bazel project. As a build engineer new to Bazel, Rust, and SystemC, these guides will help you understand every aspect of the repository.

## Documentation Overview

### 📚 Core Guides

1. **[Bazel Comprehensive Guide](01-bazel-comprehensive-guide.md)**
   - Complete introduction to Bazel for this project
   - WORKSPACE.bazel and BUILD.bazel explained line-by-line
   - Dependencies, toolchains, and cross-compilation
   - **Start here if you're new to Bazel**

2. **[Rust Embedded Programming Guide](02-rust-embedded-guide.md)**
   - Embedded Rust fundamentals and no_std environment
   - Cargo.toml dependencies explained in detail
   - Memory management with heapless collections
   - Cross-compilation targets and toolchains
   - **Essential for understanding the firmware**

3. **[SystemC and TLM Guide](03-systemc-guide.md)**
   - SystemC and Transaction-Level Modeling concepts
   - Peripheral model implementation walkthrough
   - TLM 2.0 sockets and generic payloads
   - Co-simulation with QEMU
   - **Required for SystemC development**

### 🏗️ Architecture & Operations

4. **[Build System Architecture](04-build-architecture.md)**
   - Project structure and dependencies graph
   - Cross-compilation pipeline details
   - Integration points between Rust, SystemC, and QEMU
   - CI/CD and performance optimization
   - **For understanding the complete build system**

5. **[Troubleshooting and FAQ](05-troubleshooting-guide.md)**
   - Common build issues and solutions
   - Debugging techniques for each component
   - Environment setup problems
   - Performance and memory issues
   - **Your go-to guide when things go wrong**

6. **[Quick Reference](06-quick-reference.md)**
   - Common commands and build targets
   - Configuration flags and file locations
   - Cheat sheets for Rust embedded and SystemC
   - **Handy reference for daily use**

## Learning Path

### For Build Engineers New to All Technologies

**Week 1: Foundations**
1. Read [Bazel Comprehensive Guide](01-bazel-comprehensive-guide.md) (focus on concepts)
2. Try basic commands from [Quick Reference](06-quick-reference.md)
3. Build the project: `./tools/build.sh`

**Week 2: Deep Dive**
1. Study [Rust Embedded Programming Guide](02-rust-embedded-guide.md)
2. Examine the firmware source code in `firmware/src/`
3. Read [Build System Architecture](04-build-architecture.md)

**Week 3: SystemC and Integration**
1. Work through [SystemC and TLM Guide](03-systemc-guide.md)
2. Run simulations: `./tools/simulate.sh systemc`
3. Keep [Troubleshooting Guide](05-troubleshooting-guide.md) handy

### For Experienced Build Engineers

**Quick Start Path:**
1. Skim [Quick Reference](06-quick-reference.md) for commands
2. Read [Build System Architecture](04-build-architecture.md) for overview
3. Use specific guides as needed for deep dives

### By Technology Focus

**Bazel Focus:**
- [Bazel Comprehensive Guide](01-bazel-comprehensive-guide.md)
- [Build System Architecture](04-build-architecture.md)
- [Troubleshooting Guide](05-troubleshooting-guide.md) (Bazel sections)

**Rust Focus:**
- [Rust Embedded Programming Guide](02-rust-embedded-guide.md)
- [Quick Reference](06-quick-reference.md) (Rust sections)
- [Troubleshooting Guide](05-troubleshooting-guide.md) (Rust sections)

**SystemC Focus:**
- [SystemC and TLM Guide](03-systemc-guide.md)
- [Build System Architecture](04-build-architecture.md) (SystemC integration)
- [Troubleshooting Guide](05-troubleshooting-guide.md) (SystemC sections)

## Key Concepts by Document

### Bazel Concepts
- **Workspace**: Root directory with WORKSPACE.bazel
- **Package**: Directory with BUILD.bazel
- **Target**: Buildable unit (//package:target)
- **Rule**: Function defining how to build targets
- **Toolchain**: Compiler and tools for specific platform

### Rust Embedded Concepts
- **no_std**: Embedded environment without standard library
- **Heapless**: Static memory collections (Vec, String, etc.)
- **Cross-compilation**: Building for different target architectures
- **HAL**: Hardware Abstraction Layer
- **defmt**: Efficient logging for embedded systems

### SystemC Concepts
- **Module**: Basic building block (sc_module)
- **Process**: Concurrent execution (SC_THREAD)
- **TLM**: Transaction-Level Modeling
- **Socket**: Communication interface
- **Generic Payload**: Standard transaction format

## File Organization

Each guide follows a consistent structure:
- **Table of Contents**: Quick navigation
- **Concept Explanations**: Theory and background
- **Code Examples**: Real code from the project
- **Step-by-step Walkthroughs**: Detailed explanations
- **Best Practices**: Recommended approaches
- **Common Issues**: Problems and solutions

## Getting Help

### Within This Documentation
1. Use the troubleshooting guide for specific error messages
2. Check the quick reference for common commands
3. Cross-reference between guides using the links

### External Resources
Each guide includes links to:
- Official documentation
- Community forums
- Additional learning resources

### Support Channels
- **GitHub Issues**: For project-specific problems
- **Community Forums**: For technology-specific questions
- **Documentation Feedback**: Suggest improvements

## Contributing to Documentation

To improve these guides:
1. Identify gaps or unclear sections
2. Add examples from real-world usage
3. Update troubleshooting with new issues found
4. Keep quick reference current with command changes

## Document Status

| Document | Completeness | Last Updated | Next Review |
|----------|--------------|--------------|-------------|
| Bazel Guide | ✅ Complete | Current | Quarterly |
| Rust Guide | ✅ Complete | Current | When Rust updates |
| SystemC Guide | ✅ Complete | Current | Bi-annually |
| Architecture | ✅ Complete | Current | When system changes |
| Troubleshooting | 🔄 Living Document | Current | Continuously |
| Quick Reference | 🔄 Living Document | Current | Monthly |

---

**💡 Tip**: Keep the Quick Reference open in a browser tab for easy access to common commands while working through the other guides.

**🎯 Goal**: By the end of these guides, you should be able to modify any part of the build system, add new targets, debug issues, and understand the complete firmware development flow.