use heapless::Vec;

#[derive(Debug, Clone)]
pub struct Message {
    pub id: u16,
    pub payload: Vec<u8, 64>,
}

#[derive(Debug)]
pub enum Command {
    SetGpio { pin: u8, state: bool },
    SendMessage { data: Vec<u8, 128> },
    Reset,
}

impl Message {
    pub fn new(id: u16) -> Self {
        Self {
            id,
            payload: Vec::new(),
        }
    }

    pub fn add_data(&mut self, data: &[u8]) -> Result<(), ()> {
        self.payload.extend_from_slice(data).map_err(|_| ())
    }

    pub fn serialize(&self) -> Vec<u8, 128> {
        let mut buffer = Vec::new();
        let _ = buffer.push((self.id >> 8) as u8);
        let _ = buffer.push(self.id as u8);
        let _ = buffer.push(self.payload.len() as u8);
        let _ = buffer.extend_from_slice(&self.payload);
        buffer
    }
}