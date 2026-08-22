    .section .text, "ax", @progbits
    .align  6
    .globl  __start
    .type   __start, @function
__start:
    .option push
    .option norvc
    li      x31, 99
    ebreak

    .org    0x80
restart_entry:
    la      t0, restart_data
    lw      t1, 0(t0)
    li      t2, 0x2468ace0
    bne     t1, t2, fail
    li      x31, 1
    ebreak
fail:
    li      x31, 0
    ebreak
    .option pop

    .section .data, "aw", @progbits
    .balign 64
restart_data:
    .word   0x2468ace0
    .space  60
