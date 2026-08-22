    .section .text, "ax", @progbits
    .align  6
    .globl  __start
    .type   __start, @function
__start:
    .option push
    .option norvc
    la      a0, wrong_path_word
    li      t0, 0
    li      t1, 1

    # Exercise dependent not-taken and taken branches.
    beq     t0, t1, fail
    bne     t0, t1, branch_target
wrong_path_branch:
    sw      t1, 0(a0)
    csrw    0x7db, t1
    j       fail

branch_target:
    li      t2, 4
backward_loop:
    addi    t2, t2, -1
    bnez    t2, backward_loop

    jal     ra, jal_target
after_jal:
    sw      t1, 0(a0)
    j       fail
jal_target:
    la      t3, after_jal
    bne     ra, t3, fail

    la      t4, jalr_target
    ori     t4, t4, 1
    jalr    s0, 0(t4)
after_jalr:
    sw      t1, 0(a0)
    j       fail
    .balign 64
jalr_target:
    la      t3, after_jalr
    bne     s0, t3, fail

    # Wrong-path memory and CSR operations must not become visible.
    lw      t0, 0(a0)
    bnez    t0, fail
    csrr    t0, 0x7db
    bnez    t0, fail
    li      x31, 1
    ebreak
fail:
    li      x31, 0
    ebreak
    .option pop

    .section .data, "aw", @progbits
    .balign 64
wrong_path_word:
    .word   0
    .space  60
