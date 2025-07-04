# SystemC and TLM 2.0 Guide

## Table of Contents
1. [Introduction to SystemC](#introduction-to-systemc)
2. [TLM 2.0 Overview](#tlm-20-overview)
3. [Project SystemC Architecture](#project-systemc-architecture)
4. [Peripheral Model Deep Dive](#peripheral-model-deep-dive)
5. [Testbench Design](#testbench-design)
6. [Transaction-Level Modeling](#transaction-level-modeling)
7. [Building SystemC with Bazel](#building-systemc-with-bazel)
8. [Advanced SystemC Patterns](#advanced-systemc-patterns)
9. [Co-simulation with QEMU](#co-simulation-with-qemu)

## Introduction to SystemC

SystemC is a C++ library for system-level modeling and design. It enables:

- **Hardware/Software Co-design**: Model both HW and SW in same environment
- **Transaction-Level Modeling**: Abstract hardware communication
- **Simulation**: Functional verification before RTL
- **Performance Analysis**: Timing and resource analysis

### Key Concepts

1. **Module**: Basic building block (like Verilog module)
2. **Process**: Concurrent execution (SC_THREAD, SC_METHOD)
3. **Channel**: Communication between modules
4. **Interface**: Standardized communication protocols
5. **Event**: Synchronization primitive

### SystemC vs RTL

| SystemC | RTL (Verilog/VHDL) |
|---------|-------------------|
| Transaction-level | Cycle-accurate |
| Functional model | Bit-accurate |
| Fast simulation | Slow simulation |
| Early development | Implementation |
| C++ based | HDL based |

## TLM 2.0 Overview

Transaction-Level Modeling (TLM) 2.0 is a standard for SystemC communication:

### TLM Hierarchy

```
TLM 2.0
├── Blocking Transport Interface (b_transport)
├── Non-blocking Transport Interface (nb_transport)
├── Direct Memory Interface (DMI)
└── Debug Transport Interface (transport_dbg)
```

### Generic Payload

The `tlm_generic_payload` is the standard transaction:

```cpp
class tlm_generic_payload {
    tlm_command     command;        // READ/WRITE/IGNORE
    sc_dt::uint64   address;        // Target address
    unsigned char*  data_ptr;       // Data pointer
    unsigned int    data_length;    // Data length
    unsigned char*  byte_enable;    // Byte enables
    tlm_response_status response;   // Response status
    // ... other members
};
```

### TLM Sockets

Sockets provide standardized interfaces:

```cpp
// Initiator socket (master)
tlm_utils::simple_initiator_socket<Module> socket;

// Target socket (slave)
tlm_utils::simple_target_socket<Module> socket;
```

## Project SystemC Architecture

Our project structure:

```
systemc/
├── peripheral_model.h     # Peripheral target
├── peripheral_model.cpp   # Implementation
├── testbench.cpp         # Initiator/testbench
└── BUILD.bazel          # Build configuration
```

### System Overview

```
Testbench (Initiator)
        |
        | TLM 2.0 Socket
        |
        ↓
Peripheral Model (Target)
        |
        | Memory-mapped registers
        |
        ↓
[Control] [Status] [Data]
```

## Peripheral Model Deep Dive

Let's analyze the peripheral model line by line:

### Header File (peripheral_model.h)

```cpp
#include <systemc>
#include <tlm>
#include <tlm_utils/simple_target_socket.h>
```

Essential includes:
- `systemc`: Core SystemC library
- `tlm`: Transaction-Level Modeling
- `tlm_utils`: Utility sockets (simplified interface)

### Class Declaration

```cpp
class PeripheralModel : public sc_core::sc_module {
public:
    tlm_utils::simple_target_socket<PeripheralModel> socket;
```

- Inherits from `sc_module`: Makes it a SystemC module
- `simple_target_socket`: Provides TLM interface
- Template parameter: Owner class (for callbacks)

### Constructor

```cpp
SC_CTOR(PeripheralModel) : socket("socket") {
    socket.register_b_transport(this, &PeripheralModel::b_transport);
    socket.register_get_direct_mem_ptr(this, &PeripheralModel::get_direct_mem_ptr);
    socket.register_transport_dbg(this, &PeripheralModel::transport_dbg);
    
    SC_THREAD(interrupt_generator);
}
```

- `SC_CTOR`: SystemC constructor macro
- `register_b_transport`: Registers blocking transport callback
- `register_get_direct_mem_ptr`: Registers DMI callback
- `register_transport_dbg`: Registers debug transport
- `SC_THREAD`: Creates concurrent process

### Register Map

```cpp
static const uint32_t CTRL_REG_OFFSET = 0x00;
static const uint32_t STATUS_REG_OFFSET = 0x04;
static const uint32_t DATA_REG_OFFSET = 0x08;
```

Memory map:
- 0x00: Control register
- 0x04: Status register  
- 0x08: Data register

### Implementation (peripheral_model.cpp)

#### Blocking Transport

```cpp
void PeripheralModel::b_transport(tlm::tlm_generic_payload& trans, sc_core::sc_time& delay) {
    tlm::tlm_command cmd = trans.get_command();
    sc_dt::uint64 addr = trans.get_address();
    unsigned char* ptr = trans.get_data_ptr();
    unsigned int len = trans.get_data_length();
```

Extract transaction information:
- `get_command()`: READ or WRITE
- `get_address()`: Target address
- `get_data_ptr()`: Data buffer pointer
- `get_data_length()`: Transfer size

#### Length Checking

```cpp
if (len != 4) {
    trans.set_response_status(tlm::TLM_GENERIC_ERROR_RESPONSE);
    return;
}
```

Ensure only 32-bit (4-byte) accesses are allowed.

#### Address Decoding

```cpp
uint32_t offset = addr & 0xFF;

if (cmd == tlm::TLM_READ_COMMAND) {
    switch (offset) {
        case CTRL_REG_OFFSET:
            *reinterpret_cast<uint32_t*>(ptr) = control_register;
            break;
        // ...
    }
}
```

- Extract register offset from address
- Use switch statement for register decode
- `reinterpret_cast`: Convert byte pointer to uint32_t

#### Register Behavior

**Control Register (Write)**:
```cpp
case CTRL_REG_OFFSET:
    control_register = *reinterpret_cast<uint32_t*>(ptr);
    if (control_register & 0x01) {
        interrupt_event.notify();
    }
    break;
```

- Write updates control register
- If bit 0 set, trigger interrupt event

**Status Register (Read)**:
```cpp
case STATUS_REG_OFFSET:
    *reinterpret_cast<uint32_t*>(ptr) = status_register;
    break;
```

- Simple read of status register

**Data Register (Read)**:
```cpp
case DATA_REG_OFFSET:
    *reinterpret_cast<uint32_t*>(ptr) = data_register;
    status_register &= ~0x01; // Clear data ready bit
    break;
```

- Read data register
- Clear "data ready" bit in status
- Models consuming data

#### Timing Modeling

```cpp
trans.set_response_status(tlm::TLM_OK_RESPONSE);
delay += sc_core::sc_time(10, sc_core::SC_NS);
```

- Set successful response
- Add 10ns delay to model timing
- Delay is accumulated by initiator

### Interrupt Generator Process

```cpp
void PeripheralModel::interrupt_generator() {
    while (true) {
        wait(interrupt_event);
        wait(100, sc_core::SC_US);
        
        // Simulate data arrival
        data_register = rand() & 0xFFFF;
        status_register |= 0x01; // Set data ready bit
        
        std::cout << "[SystemC] Interrupt generated, data: 0x" << std::hex << data_register << std::endl;
    }
}
```

This process:
1. Waits for interrupt event
2. Waits 100 microseconds
3. Generates random data
4. Sets data ready flag
5. Prints status message

## Testbench Design

### Testbench Class

```cpp
class TestBench : public sc_core::sc_module {
public:
    tlm_utils::simple_initiator_socket<TestBench> socket;
    
    SC_CTOR(TestBench) : socket("socket") {
        SC_THREAD(run_test);
    }
```

- Inherits from `sc_module`
- Has initiator socket (master)
- `SC_THREAD` for test sequence

### Test Sequence

```cpp
void run_test() {
    wait(10, sc_core::SC_NS);
    
    // Write to control register
    write_register(0x00, 0x01);
    
    // Read status register
    uint32_t status = read_register(0x04);
    
    // Wait for interrupt
    wait(200, sc_core::SC_US);
    
    // Read data
    uint32_t data = read_register(0x08);
    
    sc_core::sc_stop();
}
```

Test sequence:
1. Initial delay
2. Write control register
3. Read status
4. Wait for interrupt
5. Read data
6. Stop simulation

### Register Access Methods

```cpp
void write_register(uint32_t addr, uint32_t data) {
    tlm::tlm_generic_payload trans;
    sc_core::sc_time delay = sc_core::SC_ZERO_TIME;
    
    trans.set_command(tlm::TLM_WRITE_COMMAND);
    trans.set_address(addr);
    trans.set_data_ptr(reinterpret_cast<unsigned char*>(&data));
    trans.set_data_length(4);
    
    socket->b_transport(trans, delay);
    
    if (trans.is_response_error()) {
        SC_REPORT_ERROR("TestBench", "Transaction error");
    }
}
```

Write register function:
1. Create generic payload
2. Set command to WRITE
3. Set address and data
4. Call blocking transport
5. Check for errors

### Main Function

```cpp
int sc_main(int argc, char* argv[]) {
    TestBench tb("testbench");
    PeripheralModel peripheral("peripheral");
    
    tb.socket.bind(peripheral.socket);
    
    sc_core::sc_start();
    
    return 0;
}
```

SystemC main function:
1. Create testbench and peripheral
2. Bind sockets together
3. Start simulation
4. Return when simulation ends

## Transaction-Level Modeling

### Abstraction Levels

1. **Functional**: Only functional behavior
2. **Timing**: Approximate timing added
3. **Cycle-Accurate**: Exact timing
4. **RTL**: Register-transfer level

Our model is at the **Timing** level.

### Timing Annotation

```cpp
// Approximate timing
delay += sc_core::sc_time(10, sc_core::SC_NS);

// More detailed timing
if (is_cache_hit) {
    delay += sc_core::sc_time(1, sc_core::SC_NS);
} else {
    delay += sc_core::sc_time(100, sc_core::SC_NS);
}
```

### Quantum Keeper

For faster simulation with multiple masters:

```cpp
tlm_utils::tlm_quantumkeeper qk;
qk.set_global_quantum(sc_core::sc_time(1, sc_core::SC_US));
```

## Building SystemC with Bazel

### BUILD.bazel Analysis

```python
cc_library(
    name = "peripheral_model",
    srcs = ["peripheral_model.cpp"],
    hdrs = ["peripheral_model.h"],
    copts = ["-std=c++14"],
    deps = ["@systemc//:systemc"],
)
```

- `cc_library`: C++ library rule
- `srcs`: Source files
- `hdrs`: Header files
- `copts`: Compiler options
- `deps`: Dependencies (SystemC library)

```python
cc_binary(
    name = "testbench",
    srcs = ["testbench.cpp"],
    copts = ["-std=c++14"],
    deps = [
        ":peripheral_model",
        "@systemc//:systemc",
    ],
    visibility = ["//visibility:public"],
)
```

- `cc_binary`: C++ executable rule
- Depends on local peripheral_model library
- Depends on SystemC library

### SystemC External Dependency

In WORKSPACE.bazel, you would add:

```python
http_archive(
    name = "systemc",
    urls = ["https://github.com/accellera-official/systemc/archive/refs/tags/2.3.4.tar.gz"],
    strip_prefix = "systemc-2.3.4",
    build_file = "//third_party:systemc.BUILD",
)
```

## Advanced SystemC Patterns

### Hierarchical Modules

```cpp
class SoC : public sc_core::sc_module {
    CPU cpu;
    Memory memory;
    Bus bus;
    
    SC_CTOR(SoC) : cpu("cpu"), memory("memory"), bus("bus") {
        // Connect components
        cpu.socket.bind(bus.target_socket);
        bus.initiator_socket.bind(memory.socket);
    }
};
```

### Generic Payload Extensions

```cpp
class MyExtension : public tlm::tlm_extension<MyExtension> {
public:
    bool secure_access;
    uint32_t transaction_id;
    
    tlm_extension_base* clone() const override {
        return new MyExtension(*this);
    }
};

// Usage
MyExtension* ext = new MyExtension();
ext->secure_access = true;
trans.set_extension(ext);
```

### Non-blocking Transport

```cpp
tlm::tlm_sync_enum nb_transport_fw(tlm::tlm_generic_payload& trans,
                                   tlm::tlm_phase& phase,
                                   sc_core::sc_time& delay) {
    if (phase == tlm::BEGIN_REQ) {
        // Process request
        phase = tlm::END_REQ;
        return tlm::TLM_UPDATED;
    }
    return tlm::TLM_ACCEPTED;
}
```

### Direct Memory Interface (DMI)

```cpp
bool get_direct_mem_ptr(tlm::tlm_generic_payload& trans,
                        tlm::tlm_dmi& dmi_data) {
    dmi_data.set_dmi_ptr(memory_array);
    dmi_data.set_start_address(0x0);
    dmi_data.set_end_address(0xFFFF);
    dmi_data.allow_read_write();
    return true;
}
```

## Co-simulation with QEMU

### Socket Connection

```cpp
// SystemC side
class QEMUInterface : public sc_core::sc_module {
    int socket_fd;
    
    SC_CTOR(QEMUInterface) {
        socket_fd = socket(AF_INET, SOCK_STREAM, 0);
        // Bind to port 5555
        bind(socket_fd, ...);
        listen(socket_fd, 1);
        
        SC_THREAD(handle_qemu);
    }
    
    void handle_qemu() {
        while (true) {
            // Accept QEMU connection
            int client = accept(socket_fd, ...);
            
            // Handle register accesses
            char buffer[1024];
            recv(client, buffer, sizeof(buffer), 0);
            
            // Process and respond
            send(client, response, response_len, 0);
        }
    }
};
```

### Protocol Definition

```cpp
struct RegisterAccess {
    uint32_t address;
    uint32_t data;
    uint8_t  is_write;
    uint8_t  size;
};
```

### QEMU Chardev Backend

In QEMU command line:
```bash
qemu-system-arm \
    -chardev socket,id=systemc,host=localhost,port=5555 \
    -device pl011,chardev=systemc
```

## Performance Considerations

### Optimization Tips

1. **Use sc_time efficiently**: Don't create many small time objects
2. **Minimize dynamic allocation**: Use static arrays when possible
3. **Batch transactions**: Group multiple accesses
4. **Use quantum keeper**: For multi-master systems
5. **Profile bottlenecks**: Use SystemC profiling tools

### Memory Management

```cpp
// Good: Use object pools
class TransactionPool {
    std::vector<tlm::tlm_generic_payload> pool;
    size_t next_free;
    
public:
    tlm::tlm_generic_payload* get() {
        if (next_free < pool.size()) {
            return &pool[next_free++];
        }
        return nullptr;
    }
};

// Bad: Frequent allocation
tlm::tlm_generic_payload* trans = new tlm::tlm_generic_payload();
```

## Debugging SystemC

### Waveform Dump

```cpp
sc_core::sc_trace_file* tf = sc_core::sc_create_vcd_trace_file("waves");
sc_core::sc_trace(tf, clock, "clock");
sc_core::sc_trace(tf, reset, "reset");
// Add more signals...

// At end of simulation
sc_core::sc_close_vcd_trace_file(tf);
```

### Debug Messages

```cpp
SC_REPORT_INFO("MODULE", "Transaction started");
SC_REPORT_WARNING("MODULE", "Unexpected condition");
SC_REPORT_ERROR("MODULE", "Fatal error occurred");
```

### GDB Debugging

```bash
# Compile with debug info
bazel build -c dbg //systemc:testbench

# Run with GDB
gdb bazel-bin/systemc/testbench
(gdb) break PeripheralModel::b_transport
(gdb) run
```

## Best Practices

1. **Use TLM utilities**: Simplify socket management
2. **Model timing appropriately**: Not too detailed, not too abstract
3. **Separate concerns**: Keep functional and timing models separate
4. **Document interfaces**: Clear register maps and protocols
5. **Test thoroughly**: Create comprehensive testbenches
6. **Use hierarchical design**: Build complex systems from simple components

## Common Pitfalls

1. **Delta cycle issues**: Understanding SystemC scheduler
2. **Simulation deadlock**: Processes waiting forever
3. **Memory leaks**: Not cleaning up dynamic allocations
4. **Timing annotation errors**: Incorrect delay calculations
5. **Socket binding errors**: Mismatched socket types

## Next Steps

Continue to:
- [Build System Architecture](04-build-architecture.md)
- [Troubleshooting Guide](05-troubleshooting-guide.md)