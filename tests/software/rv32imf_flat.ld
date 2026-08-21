OUTPUT_ARCH(riscv)
ENTRY(__start)

MEMORY
{
    ROM (rwx) : ORIGIN = 0x00000000, LENGTH = 0x00100000
}

__stack_top = ORIGIN(ROM) + LENGTH(ROM);
__edge_stack_top = __stack_top;
__edge_dtcm_base = 0x40000000;
__edge_dtcm_size = 0x00010000;
__edge_dtcm_mask = 0xffff0000;

SECTIONS
{
    .text : ALIGN(4) {
        KEEP(*(.init))
        *(.text .text.*)
    } > ROM

    .rodata : ALIGN(4) {
        *(.srodata .srodata.*)
        *(.rodata .rodata.*)
    } > ROM

    .data : ALIGN(4) {
        __global_pointer$ = . + 0x800;
        *(.sdata .sdata.*)
        *(.data .data.*)
    } > ROM

    .edge_rom_output : ALIGN(4) {
        __edge_rom_output_start = .;
        KEEP(*(.edge_rom_output))
        __edge_rom_output_end = .;
    } > ROM

    .bss (NOLOAD) : ALIGN(4) {
        __bss_start = .;
        *(.sbss .sbss.*)
        *(.bss .bss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > ROM

    . = ALIGN(4);
    PROVIDE(__sim_exit_code = .);
    . += 4;
    PROVIDE(tohost = .);
    . += 4;
    PROVIDE(fromhost = .);
    . += 4;
    PROVIDE(end = .);
}
