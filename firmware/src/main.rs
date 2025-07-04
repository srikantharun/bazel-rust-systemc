#![no_std]
#![no_main]

use panic_halt as _;

#[cfg(feature = "cortex-m-target")]
use cortex_m_rt::entry;

#[cfg(feature = "riscv-target")]
use riscv_rt::entry;

use defmt_rtt as _;
use heapless::Vec;
use heapless::String;
use heapless::spsc::{Consumer, Producer, Queue};
use fugit::{Duration, Instant};

mod peripheral;
mod protocol;

use peripheral::{Uart, Gpio, Timer};
use protocol::{Message, Command};

const QUEUE_SIZE: usize = 16;
static mut COMMAND_QUEUE: Queue<Command, QUEUE_SIZE> = Queue::new();

pub struct System {
    uart: Uart,
    gpio: Gpio,
    timer: Timer,
    command_consumer: Consumer<'static, Command, QUEUE_SIZE>,
    message_buffer: Vec<Message, 32>,
}

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

    pub fn init(&mut self) {
        self.uart.init();
        self.gpio.init();
        self.timer.init();
        
        defmt::info!("System initialized");
    }

    pub fn run(&mut self) -> ! {
        let mut last_tick = Instant::<u32, 1, 1000>::from_ticks(0);
        
        loop {
            if let Some(command) = self.command_consumer.dequeue() {
                self.process_command(command);
            }
            
            let current_tick = self.timer.get_tick();
            if current_tick.duration_since(&last_tick) > Duration::<u32, 1, 1000>::from_ticks(1000) {
                self.heartbeat();
                last_tick = current_tick;
            }
            
            if let Some(data) = self.uart.read() {
                self.process_uart_data(data);
            }
        }
    }

    fn process_command(&mut self, cmd: Command) {
        match cmd {
            Command::SetGpio { pin, state } => {
                self.gpio.set_pin(pin, state);
                defmt::info!("GPIO pin {} set to {}", pin, state);
            }
            Command::SendMessage { data } => {
                self.uart.write(&data);
                defmt::info!("Sent message: {:?}", data);
            }
            Command::Reset => {
                defmt::info!("System reset requested");
                cortex_m::peripheral::SCB::sys_reset();
            }
        }
    }

    fn process_uart_data(&mut self, data: u8) {
        defmt::trace!("UART data received: {}", data);
    }

    fn heartbeat(&mut self) {
        self.gpio.toggle_led();
        defmt::trace!("Heartbeat");
    }
}

#[entry]
fn main() -> ! {
    let mut system = System::new();
    system.init();
    system.run()
}