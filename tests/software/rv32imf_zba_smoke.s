    .section .text, "ax", @progbits
    .align  2
    .globl  __start
    .type   __start, @function
__start:
    .option push
    .option norvc
    li      x6, 6
    li      x7, 7
    mul     x8, x6, x7
    li      x12, 42
    bne     x8, x12, fail
    sh1add  x9, x6, x7
    li      x12, 19
    bne     x9, x12, fail
    la      x10, fp_data
    flw     f1, 0(x10)
    flw     f2, 4(x10)
    fadd.s  f3, f1, f2
    fsw     f3, 8(x10)
    lw      x11, 8(x10)
    li      x12, 0x40400000
    bne     x11, x12, fail
    li      x31, 1
    ebreak
fail:
    li      x31, 0
    ebreak
    .option pop

    .section .data, "aw", @progbits
    .align  2
fp_data:
    .word   0x3f800000
    .word   0x40000000
    .word   0x00000000
