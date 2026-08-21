# edge_32_branch.v

## Purpose

`edge_32_branch` is the local combinational RV32 branch and jump unit. It
replaces the shared RV64 scalar branch unit in the `edge-32` core.

## Ownership and interface

The module owns no state or handshake. Decode supplies a legal operation,
32-bit operands and sign-extended 32-bit I/B/J immediates. The pipeline owns
redirect, flush, retirement, and exception behavior.

`PC_WIDTH` must be at least 32. The integration-facing PC may remain wider
during migration, but target arithmetic uses `pc[31:0]` and wraps modulo
2^32. The resulting RV32 address is zero-extended to `PC_WIDTH`.

## Behavior

- BEQ/BNE compare all 32 operand bits.
- BLT/BGE use signed 32-bit comparison.
- BLTU/BGEU use unsigned 32-bit comparison.
- JAL adds the J immediate to the low 32 PC bits.
- JALR adds the I immediate to `rs1`, wraps at 32 bits, and clears bit zero.
- Conditional branch targets add the B immediate to the low 32 PC bits.

Legality remains the responsibility of `edge_32_decode`; unsupported branch
`funct3` values produce `branch_taken=0` at this arithmetic boundary.

## Test

`tests/edge_32_branch_tb.v` checks all six conditional comparisons, signed
versus unsigned ordering, untaken behavior, JAL/JALR targets, JALR bit-zero
clearing, negative offsets, and 32-bit target wraparound.

`tests/edge_32_branch_core_tb.v` runs BLT, JAL, and JALR through the complete
three-stage core and checks link-register writeback plus wrong-path flushing.

The adjacent `edge32-branch32` Xilinx synthesis checkpoint maps the branch leaf
to 210 cells versus 301 for the shared RV64 leaf. The whole core changes from
10,682 to 10,415 cells: 267 fewer total cells and 150 fewer LUT1-LUT6 cells,
with the same 2,088 flip-flops and 4 DSP48E1 blocks.
