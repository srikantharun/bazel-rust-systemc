use heapless::Vec;

pub struct Uart {
    buffer: Vec<u8, 256>,
}

impl Uart {
    pub fn new() -> Self {
        Self {
            buffer: Vec::new(),
        }
    }

    pub fn init(&mut self) {
        defmt::debug!("UART initialized");
    }

    pub fn write(&mut self, data: &[u8]) {
        for &byte in data {
            unsafe {
                core::ptr::write_volatile(0x4000_4400 as *mut u8, byte);
            }
        }
    }

    pub fn read(&mut self) -> Option<u8> {
        let status = unsafe { core::ptr::read_volatile(0x4000_4404 as *const u32) };
        if status & 0x01 != 0 {
            Some(unsafe { core::ptr::read_volatile(0x4000_4400 as *const u8) })
        } else {
            None
        }
    }
}

pub struct Gpio {
    led_state: bool,
}

impl Gpio {
    pub fn new() -> Self {
        Self { led_state: false }
    }

    pub fn init(&mut self) {
        unsafe {
            let gpio_base = 0x4002_0000 as *mut u32;
            core::ptr::write_volatile(gpio_base.offset(0), 0x0000_0001);
        }
        defmt::debug!("GPIO initialized");
    }

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

    pub fn toggle_led(&mut self) {
        self.led_state = !self.led_state;
        self.set_pin(13, self.led_state);
    }
}

pub struct Timer {
    counter: u32,
}

impl Timer {
    pub fn new() -> Self {
        Self { counter: 0 }
    }

    pub fn init(&mut self) {
        unsafe {
            let tim_base = 0x4000_0000 as *mut u32;
            core::ptr::write_volatile(tim_base.offset(0), 0x0000_0001);
        }
        defmt::debug!("Timer initialized");
    }

    pub fn get_tick(&mut self) -> fugit::Instant<u32, 1, 1000> {
        self.counter = unsafe { core::ptr::read_volatile(0x4000_0004 as *const u32) };
        fugit::Instant::from_ticks(self.counter)
    }
}