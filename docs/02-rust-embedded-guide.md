# Rust Embedded Programming Guide

## Table of Contents
1. [Introduction to Embedded Rust](#introduction-to-embedded-rust)
2. [Understanding no_std Environment](#understanding-no_std-environment)
3. [Cargo.toml Deep Dive](#cargotoml-deep-dive)
4. [Main.rs Architecture](#mainrs-architecture)
5. [Peripheral Abstraction](#peripheral-abstraction)
6. [Memory Management with Heapless](#memory-management-with-heapless)
7. [Cross-Compilation Targets](#cross-compilation-targets)
8. [Debugging and Logging](#debugging-and-logging)
9. [Rust Embedded Patterns](#rust-embedded-patterns)

## Introduction to Embedded Rust

Embedded Rust provides memory safety without garbage collection, making it ideal for firmware development. Key benefits:

- **Zero-cost abstractions**: High-level code compiles to efficient machine code
- **Memory safety**: Prevents buffer overflows, use-after-free
- **Fearless concurrency**: Safe concurrent programming
- **No runtime overhead**: No garbage collector or runtime

### Embedded vs Standard Rust

| Standard Rust | Embedded Rust |
|--------------|---------------|
| std library available | no_std environment |
| Heap allocation (Box, Vec) | Static allocation |
| Operating system available | Bare metal |
| main() returns | main() never returns |
| panic! unwinds stack | panic! halts/resets |

## Understanding no_std Environment

### The #![no_std] Attribute

```rust
#![no_std]
#![no_main]
```

- `#![no_std]`: Disables the standard library
- `#![no_main]`: Disables the standard main function

### What's Not Available in no_std

1. **Heap allocation**: No Vec, Box, String
2. **Collections**: No HashMap, BTreeMap (unless static)
3. **Thread spawning**: No std::thread
4. **File I/O**: No filesystem access
5. **Network**: No std::net

### What IS Available

1. **Core library**: Basic types and traits
2. **Static allocation**: Arrays, static variables
3. **Embedded-specific crates**: cortex-m, embedded-hal
4. **Static collections**: heapless crate

## Cargo.toml Deep Dive

Let's analyze each section:

### Package Metadata

```toml
[package]
name = "rust-firmware"
version = "0.1.0"
edition = "2021"
```

- `edition`: Rust language edition (2015, 2018, 2021)
- Affects language features and idioms

### Dependencies Explained

```toml
[dependencies]
cortex-m = "0.7"
cortex-m-rt = "0.7"
```

**cortex-m**: Low-level access to Cortex-M processors
- Provides register access
- Assembly instructions (nop, wfi, etc.)
- Critical sections

**cortex-m-rt**: Runtime for Cortex-M processors
- Boot sequence
- Memory initialization
- Vector table setup

```toml
panic-halt = "0.2"
```

**panic-halt**: Panic handler that halts on panic
- Required in no_std
- Alternatives: panic-abort, panic-persist, panic-semihosting

```toml
nb = "1.0"
```

**nb**: Non-blocking I/O traits
- Defines `Error::WouldBlock`
- Used for async-like operations without async runtime

```toml
heapless = "0.8"
```

**heapless**: Static memory collections
- Vec → heapless::Vec
- String → heapless::String
- HashMap → heapless::FnvIndexMap

```toml
embedded-hal = "0.2"
```

**embedded-hal**: Hardware Abstraction Layer traits
- Standard interfaces for peripherals
- Enables driver portability

```toml
defmt = "0.3"
defmt-rtt = "0.4"
```

**defmt**: Efficient logging framework
- Deferred formatting (on host, not target)
- Much smaller than println!
- RTT (Real-Time Transfer) backend

```toml
fugit = "0.3"
```

**fugit**: Time library for embedded systems
- Compile-time unit checking
- No floating point
- Zero-cost abstractions

### Optional Dependencies

```toml
[dependencies.stm32f4xx-hal]
version = "0.20"
features = ["stm32f401"]
optional = true
```

- HAL (Hardware Abstraction Layer) for STM32F4
- Only included when feature enabled

### Features Section

```toml
[features]
default = ["cortex-m-target"]
cortex-m-target = ["stm32f4xx-hal"]
riscv-target = []
```

- Features allow conditional compilation
- `default`: Features enabled by default
- Use: `cargo build --features riscv-target`

### Profile Configuration

```toml
[profile.release]
opt-level = "z"     # Optimize for size
lto = true          # Link-time optimization
codegen-units = 1   # Better optimization
panic = "abort"     # Don't unwind on panic

[profile.dev]
opt-level = "s"     # Some optimization in dev
debug = true        # Debug symbols
panic = "abort"     # Consistent panic behavior
```

## Main.rs Architecture

Let's break down the main.rs file:

### Attributes and Imports

```rust
#![no_std]
#![no_main]

use panic_halt as _;
```

- `use panic_halt as _`: Imports panic handler but doesn't use it directly
- The `_` means we just need it linked

### Conditional Compilation

```rust
#[cfg(feature = "cortex-m-target")]
use cortex_m_rt::entry;

#[cfg(feature = "riscv-target")]
use riscv_rt::entry;
```

- `#[cfg()]`: Compile-time conditional
- Only one entry point is compiled based on features

### Entry Point

```rust
#[entry]
fn main() -> ! {
    // ... 
}
```

- `#[entry]`: Marks the entry point
- `-> !`: Never returns (infinite loop)
- Called after RAM initialization

### Static Memory Allocation

```rust
const QUEUE_SIZE: usize = 16;
static mut COMMAND_QUEUE: Queue<Command, QUEUE_SIZE> = Queue::new();
```

- `static mut`: Mutable static variable (unsafe to access)
- Size must be known at compile time
- Lives for entire program execution

### System Structure

```rust
pub struct System {
    uart: Uart,
    gpio: Gpio,
    timer: Timer,
    command_consumer: Consumer<'static, Command, QUEUE_SIZE>,
    message_buffer: Vec<Message, 32>,
}
```

- All members have fixed size
- `Vec<Message, 32>`: Static vector with max 32 elements
- `'static` lifetime: Lives forever

### Initialization Pattern

```rust
impl System {
    pub fn new() -> Self {
        let (producer, consumer) = unsafe { COMMAND_QUEUE.split() };
        
        Self {
            uart: Uart::new(),
            gpio: Gpio::new(),
            timer: Timer::new(),
            command_consumer: consumer,
            message_buffer: Vec::new(),
        }
    }
}
```

- Two-phase initialization: new() then init()
- Splits queue into producer/consumer
- `unsafe` block for static mutable access

### Main Loop Pattern

```rust
pub fn run(&mut self) -> ! {
    let mut last_tick = Instant::<u32, 1, 1000>::from_ticks(0);
    
    loop {
        // Handle commands
        if let Some(command) = self.command_consumer.dequeue() {
            self.process_command(command);
        }
        
        // Time-based tasks
        let current_tick = self.timer.get_tick();
        if current_tick.duration_since(&last_tick) > Duration::<u32, 1, 1000>::from_ticks(1000) {
            self.heartbeat();
            last_tick = current_tick;
        }
        
        // Handle UART
        if let Some(data) = self.uart.read() {
            self.process_uart_data(data);
        }
    }
}
```

This shows the super-loop pattern:
1. Process commands
2. Handle periodic tasks
3. Process I/O
4. Repeat forever

## Peripheral Abstraction

### Hardware Register Access

```rust
pub fn write(&mut self, data: &[u8]) {
    for &byte in data {
        unsafe {
            core::ptr::write_volatile(0x4000_4400 as *mut u8, byte);
        }
    }
}
```

- `write_volatile`: Prevents compiler optimization
- Direct memory-mapped I/O
- `unsafe`: Required for raw pointer access

### Register Patterns

```rust
pub fn read(&mut self) -> Option<u8> {
    let status = unsafe { core::ptr::read_volatile(0x4000_4404 as *const u32) };
    if status & 0x01 != 0 {  // Check bit 0
        Some(unsafe { core::ptr::read_volatile(0x4000_4400 as *const u8) })
    } else {
        None
    }
}
```

Common patterns:
- Read status register
- Check specific bits
- Conditional read of data register

### GPIO Abstraction

```rust
pub fn set_pin(&mut self, pin: u8, state: bool) {
    unsafe {
        let gpio_base = 0x4002_0000 as *mut u32;
        let current = core::ptr::read_volatile(gpio_base.offset(1));
        if state {
            core::ptr::write_volatile(gpio_base.offset(1), current | (1 << pin));
        } else {
            core::ptr::write_volatile(gpio_base.offset(1), current & !(1 << pin));
        }
    }
}
```

Bit manipulation patterns:
- `|= (1 << pin)`: Set bit
- `&= !(1 << pin)`: Clear bit
- Read-modify-write for safety

## Memory Management with Heapless

### Static Vectors

```rust
use heapless::Vec;

let mut buffer: Vec<u8, 256> = Vec::new();
buffer.push(42).unwrap();  // Can fail if full!
```

- Fixed capacity at compile time
- No heap allocation
- Returns Result on operations

### Static Strings

```rust
use heapless::String;

let mut name: String<32> = String::new();
write!(name, "Sensor {}", id).unwrap();
```

- Fixed maximum length
- Implements core::fmt::Write

### SPSC Queue

```rust
use heapless::spsc::{Queue, Producer, Consumer};

static mut Q: Queue<u8, 16> = Queue::new();
let (mut producer, mut consumer) = unsafe { Q.split() };

// Producer side
producer.enqueue(42).ok();

// Consumer side  
if let Some(val) = consumer.dequeue() {
    // Process val
}
```

- Single Producer Single Consumer
- Lock-free for single core
- Wait-free operations

### HashMap Alternative

```rust
use heapless::FnvIndexMap;

let mut map: FnvIndexMap<u8, u16, 16> = FnvIndexMap::new();
map.insert(1, 100).ok();
```

- Fixed capacity
- FNV hash (fast, simple)
- No heap allocation

## Cross-Compilation Targets

### Target Triple Format

`<arch><sub>-<vendor>-<sys>-<env>`

Examples:
- `thumbv7em-none-eabihf`
  - thumbv7em: ARMv7E-M architecture
  - none: No vendor
  - eabi: Embedded ABI
  - hf: Hard float

- `riscv32imac-unknown-none-elf`
  - riscv32: 32-bit RISC-V
  - imac: Integer, Multiply, Atomic, Compressed
  - unknown: No specific vendor
  - none: No OS
  - elf: ELF binary format

### Cortex-M Variants

| Target | MCU Examples | Features |
|--------|--------------|----------|
| thumbv6m-none-eabi | Cortex-M0, M0+ | No hardware multiply |
| thumbv7m-none-eabi | Cortex-M3 | Hardware multiply |
| thumbv7em-none-eabi | Cortex-M4, M7 | DSP instructions |
| thumbv7em-none-eabihf | Cortex-M4F, M7F | Hardware float |
| thumbv8m.base-none-eabi | Cortex-M23 | ARMv8-M baseline |
| thumbv8m.main-none-eabi | Cortex-M33 | ARMv8-M mainline |

## Debugging and Logging

### defmt Logging

```rust
use defmt;

defmt::info!("System initialized");
defmt::debug!("Value: {}", value);
defmt::trace!("Entering function");
defmt::warn!("Low battery: {}%", level);
defmt::error!("Communication failed");
```

Advantages over println!:
- Formatting happens on host
- Much smaller code size
- Structured logging
- Compile-time filtering

### Log Levels

Set in Cargo.toml:
```toml
[features]
default = ["defmt-default"]
defmt-default = []
defmt-trace = []
defmt-debug = []
defmt-info = []
defmt-warn = []
defmt-error = []
```

### RTT (Real-Time Transfer)

```rust
use defmt_rtt as _;  // Link RTT transport
```

- Uses debug probe for communication
- No UART needed
- High speed, low overhead
- Works while debugging

### Panic Information

```rust
#[panic_handler]
fn panic(info: &PanicInfo) -> ! {
    defmt::error!("Panic: {}", defmt::Display2Format(info));
    // Reset or halt
    cortex_m::peripheral::SCB::sys_reset();
}
```

## Rust Embedded Patterns

### State Machines

```rust
enum State {
    Idle,
    Receiving { buffer: Vec<u8, 64>, count: usize },
    Processing { data: Message },
}

impl StateMachine {
    fn step(&mut self) {
        match self.state {
            State::Idle => {
                if let Some(byte) = self.uart.read() {
                    self.state = State::Receiving {
                        buffer: Vec::new(),
                        count: 0,
                    };
                }
            }
            State::Receiving { .. } => {
                // Handle receiving
            }
            State::Processing { .. } => {
                // Handle processing
            }
        }
    }
}
```

### Builder Pattern for Peripherals

```rust
impl Uart {
    pub fn new() -> Self { /* ... */ }
    
    pub fn baud_rate(mut self, rate: u32) -> Self {
        self.set_baud_rate(rate);
        self
    }
    
    pub fn parity(mut self, parity: Parity) -> Self {
        self.set_parity(parity);
        self
    }
    
    pub fn init(self) -> Result<Uart, Error> {
        // Perform initialization
        Ok(self)
    }
}

// Usage
let uart = Uart::new()
    .baud_rate(115200)
    .parity(Parity::None)
    .init()?;
```

### RAII for Critical Sections

```rust
use cortex_m::interrupt;

pub struct CriticalSection;

impl CriticalSection {
    pub fn new() -> Self {
        interrupt::disable();
        CriticalSection
    }
}

impl Drop for CriticalSection {
    fn drop(&mut self) {
        unsafe { interrupt::enable() };
    }
}

// Usage
{
    let _cs = CriticalSection::new();
    // Critical code here
} // Interrupts automatically re-enabled
```

### Type State Pattern

```rust
pub struct Pin<MODE> {
    pin: u8,
    _mode: PhantomData<MODE>,
}

pub struct Input;
pub struct Output;

impl Pin<Input> {
    pub fn read(&self) -> bool {
        // Read pin
    }
    
    pub fn into_output(self) -> Pin<Output> {
        // Configure as output
        Pin {
            pin: self.pin,
            _mode: PhantomData,
        }
    }
}

impl Pin<Output> {
    pub fn set_high(&mut self) {
        // Set pin high
    }
}
```

Benefits:
- Compile-time state checking
- Can't read from output pin
- Zero runtime cost

## Best Practices

1. **Avoid Panics**: Use Result types, handle all errors
2. **Minimize Stack Usage**: Embedded stacks are small
3. **Use const fn**: Compute at compile time when possible
4. **Profile Memory**: Know your RAM/Flash usage
5. **Test on Hardware**: Simulators aren't perfect
6. **Use HAL Crates**: Don't reinvent the wheel
7. **Document Memory Maps**: Make register addresses clear

## Common Pitfalls

1. **Stack Overflow**: Too much stack usage
   - Solution: Increase stack size or reduce usage

2. **Forgetting volatile**: Compiler optimizes out register reads
   - Solution: Always use read_volatile/write_volatile

3. **Race Conditions**: Interrupt modifies shared data
   - Solution: Use critical sections or atomics

4. **Wrong Clock Configuration**: Incorrect timing
   - Solution: Verify with oscilloscope

5. **Uninitialized RAM**: Assuming zero-initialized
   - Solution: Explicitly initialize all statics

## Next Steps

Continue to:
- [SystemC/TLM Documentation](03-systemc-guide.md)
- [Build System Architecture](04-build-architecture.md)