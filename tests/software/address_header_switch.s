    .section .text, "ax", @progbits
    .align  6
    .globl  __start
    .type   __start, @function
__start:
    .option push
    .option norvc
    csrr    t0, 0x7db
    bnez    t0, fail
    csrr    t0, 0x7dc
    bnez    t0, fail

    la      a0, cache_line
    li      t1, 0x13579bdf
    sw      t1, 0(a0)

    # Clean the old address space and invalidate the line before switching.
    li      t2, 7
    .insn   r 0x0b, 1, 0, x0, a0, t2

    li      t2, 0x9abcdef0
    csrw    0x7dc, t2
    csrr    t0, 0x7dc
    bne     t0, t2, fail
    lw      t0, 0(a0)
    bne     t0, t1, fail

    li      t2, 0x12345678
    csrw    0x7db, t2
    csrr    t0, 0x7db
    bne     t0, t2, fail
    fence.i

    # Align the post-fence target away from the line containing the CSR write.
    j       switched_fetch
    .balign 64
switched_fetch:
    li      x31, 1
    ebreak
fail:
    li      x31, 0
    ebreak
    .option pop

    .section .data, "aw", @progbits
    .balign 64
cache_line:
    .word   0
    .space  60
