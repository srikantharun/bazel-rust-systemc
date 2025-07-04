#include "peripheral_model.h"
#include <iostream>

void PeripheralModel::b_transport(tlm::tlm_generic_payload& trans, sc_core::sc_time& delay) {
    tlm::tlm_command cmd = trans.get_command();
    sc_dt::uint64 addr = trans.get_address();
    unsigned char* ptr = trans.get_data_ptr();
    unsigned int len = trans.get_data_length();
    
    if (len != 4) {
        trans.set_response_status(tlm::TLM_GENERIC_ERROR_RESPONSE);
        return;
    }
    
    uint32_t offset = addr & 0xFF;
    
    if (cmd == tlm::TLM_READ_COMMAND) {
        switch (offset) {
            case CTRL_REG_OFFSET:
                *reinterpret_cast<uint32_t*>(ptr) = control_register;
                break;
            case STATUS_REG_OFFSET:
                *reinterpret_cast<uint32_t*>(ptr) = status_register;
                break;
            case DATA_REG_OFFSET:
                *reinterpret_cast<uint32_t*>(ptr) = data_register;
                status_register &= ~0x01; // Clear data ready bit
                break;
            default:
                trans.set_response_status(tlm::TLM_ADDRESS_ERROR_RESPONSE);
                return;
        }
    } else if (cmd == tlm::TLM_WRITE_COMMAND) {
        switch (offset) {
            case CTRL_REG_OFFSET:
                control_register = *reinterpret_cast<uint32_t*>(ptr);
                if (control_register & 0x01) {
                    interrupt_event.notify();
                }
                break;
            case DATA_REG_OFFSET:
                data_register = *reinterpret_cast<uint32_t*>(ptr);
                std::cout << "[SystemC] Data written: 0x" << std::hex << data_register << std::endl;
                break;
            default:
                trans.set_response_status(tlm::TLM_ADDRESS_ERROR_RESPONSE);
                return;
        }
    }
    
    trans.set_response_status(tlm::TLM_OK_RESPONSE);
    delay += sc_core::sc_time(10, sc_core::SC_NS);
}

bool PeripheralModel::get_direct_mem_ptr(tlm::tlm_generic_payload& trans, tlm::tlm_dmi& dmi_data) {
    return false;
}

unsigned int PeripheralModel::transport_dbg(tlm::tlm_generic_payload& trans) {
    return 0;
}

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