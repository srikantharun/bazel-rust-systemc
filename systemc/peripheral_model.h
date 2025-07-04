#ifndef PERIPHERAL_MODEL_H
#define PERIPHERAL_MODEL_H

#include <systemc>
#include <tlm>
#include <tlm_utils/simple_target_socket.h>

class PeripheralModel : public sc_core::sc_module {
public:
    tlm_utils::simple_target_socket<PeripheralModel> socket;
    
    SC_CTOR(PeripheralModel) : socket("socket") {
        socket.register_b_transport(this, &PeripheralModel::b_transport);
        socket.register_get_direct_mem_ptr(this, &PeripheralModel::get_direct_mem_ptr);
        socket.register_transport_dbg(this, &PeripheralModel::transport_dbg);
        
        SC_THREAD(interrupt_generator);
    }
    
    virtual void b_transport(tlm::tlm_generic_payload& trans, sc_core::sc_time& delay);
    virtual bool get_direct_mem_ptr(tlm::tlm_generic_payload& trans, tlm::tlm_dmi& dmi_data);
    virtual unsigned int transport_dbg(tlm::tlm_generic_payload& trans);
    
private:
    void interrupt_generator();
    
    sc_core::sc_event interrupt_event;
    uint32_t control_register;
    uint32_t status_register;
    uint32_t data_register;
    
    static const uint32_t CTRL_REG_OFFSET = 0x00;
    static const uint32_t STATUS_REG_OFFSET = 0x04;
    static const uint32_t DATA_REG_OFFSET = 0x08;
};

#endif