# edge_32_alu.v

## Purpose

`edge_32_alu` is the local, combinational RV32 fast integer datapath for
`edge-32`. It is derived from `edge_scalar_fast_alu`, but its architectural
operands and result are exactly 32 bits.

## Ownership and interface

The module calculates results only. Decode owns instruction legality and the
pipeline owns issue, completion, dependency, redirect, and writeback state.
There is no ready/valid state and no internal sequential state.

`PC_WIDTH` may be wider than 32 for an integration transition, but AUIPC and
jump link results consume `pc[31:0]`, matching the RV32 architectural result.
The shift amount is five bits and register shifts use `rs2[4:0]`.

## Supported operation classes

- RV32I OP-IMM: add, signed/unsigned compare, logic, and shifts
- RV32I OP: add/subtract, signed/unsigned compare, logic, and shifts
- LUI, AUIPC, JAL, and JALR writeback values
- Zba `sh1add`, `sh2add`, and `sh3add`

RV64 OP-IMM-32, OP-32, and Zba `.uw` classes do not exist at this boundary.
M-extension operations are not calculated here when `funct7_is_m` is set.

## Test

`tests/edge_32_alu_tb.v` checks arithmetic wraparound, signed and unsigned
comparisons, all logic operations, immediate and register shift masking,
arithmetic right shift sign fill, PC-relative results, Zba, and rejection of
the removed RV64-local operation values.
