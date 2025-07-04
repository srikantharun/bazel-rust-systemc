#include <systemc>
#include <tlm>
#include <tlm_utils/simple_initiator_socket.h>
#include <iostream>
#include <fstream>
#include "peripheral_model.h"

class TestBench : public sc_core::sc_module {
public:
    tlm_utils::simple_initiator_socket<TestBench> socket;
    
    SC_CTOR(TestBench) : socket("socket") {
        SC_THREAD(run_test);
    }
    
    void run_test() {
        wait(10, sc_core::SC_NS);
        
        // Write to control register
        write_register(0x00, 0x01);
        
        // Read status register
        uint32_t status = read_register(0x04);
        std::cout << "[TB] Status: 0x" << std::hex << status << std::endl;
        
        // Wait for interrupt
        wait(200, sc_core::SC_US);
        
        // Read data
        uint32_t data = read_register(0x08);
        std::cout << "[TB] Data received: 0x" << std::hex << data << std::endl;
        
        sc_core::sc_stop();
    }
    
private:
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
    
    uint32_t read_register(uint32_t addr) {
        tlm::tlm_generic_payload trans;
        sc_core::sc_time delay = sc_core::SC_ZERO_TIME;
        uint32_t data;
        
        trans.set_command(tlm::TLM_READ_COMMAND);
        trans.set_address(addr);
        trans.set_data_ptr(reinterpret_cast<unsigned char*>(&data));
        trans.set_data_length(4);
        
        socket->b_transport(trans, delay);
        
        if (trans.is_response_error()) {
            SC_REPORT_ERROR("TestBench", "Transaction error");
        }
        
        return data;
    }
};

int sc_main(int argc, char* argv[]) {
    TestBench tb("testbench");
    PeripheralModel peripheral("peripheral");
    
    tb.socket.bind(peripheral.socket);
    
    sc_core::sc_start();
    
    return 0;
}