#include "qemu/osdep.h"
#include "hw/arm/boot.h"
#include "hw/arm/armv7m.h"
#include "hw/boards.h"
#include "hw/char/serial.h"
#include "hw/sysbus.h"
#include "exec/address-spaces.h"
#include "sysemu/sysemu.h"

#define FLASH_BASE 0x08000000
#define FLASH_SIZE (256 * 1024)
#define SRAM_BASE  0x20000000
#define SRAM_SIZE  (64 * 1024)
#define PERIPH_BASE 0x40000000

typedef struct {
    MachineState parent;
    ARMv7MState armv7m;
} CustomMachineState;

static void custom_machine_init(MachineState *machine)
{
    CustomMachineState *s = (CustomMachineState *)machine;
    MemoryRegion *system_memory = get_system_memory();
    MemoryRegion *flash = g_new(MemoryRegion, 1);
    MemoryRegion *sram = g_new(MemoryRegion, 1);
    
    // Initialize Flash memory
    memory_region_init_rom(flash, NULL, "flash", FLASH_SIZE, &error_fatal);
    memory_region_add_subregion(system_memory, FLASH_BASE, flash);
    
    // Initialize SRAM
    memory_region_init_ram(sram, NULL, "sram", SRAM_SIZE, &error_fatal);
    memory_region_add_subregion(system_memory, SRAM_BASE, sram);
    
    // Initialize ARMv7M
    object_initialize_child(OBJECT(machine), "armv7m", &s->armv7m, TYPE_ARMV7M);
    qdev_prop_set_uint32(DEVICE(&s->armv7m), "num-irq", 96);
    qdev_prop_set_string(DEVICE(&s->armv7m), "cpu-type", machine->cpu_type);
    qdev_prop_set_bit(DEVICE(&s->armv7m), "enable-bitband", true);
    object_property_set_link(OBJECT(&s->armv7m), "memory",
                             OBJECT(system_memory), &error_abort);
    sysbus_realize(SYS_BUS_DEVICE(&s->armv7m), &error_fatal);
    
    // Load firmware
    if (machine->firmware) {
        armv7m_load_kernel(ARM_CPU(first_cpu), machine->firmware, 0, FLASH_SIZE);
    }
}

static void custom_machine_class_init(ObjectClass *oc, void *data)
{
    MachineClass *mc = MACHINE_CLASS(oc);
    
    mc->desc = "Custom ARM Cortex-M4 board";
    mc->init = custom_machine_init;
    mc->default_cpu_type = ARM_CPU_TYPE_NAME("cortex-m4");
}

static const TypeInfo custom_machine_type = {
    .name = MACHINE_TYPE_NAME("custom-arm"),
    .parent = TYPE_MACHINE,
    .instance_size = sizeof(CustomMachineState),
    .class_init = custom_machine_class_init,
};

static void custom_machine_register_types(void)
{
    type_register_static(&custom_machine_type);
}

type_init(custom_machine_register_types)