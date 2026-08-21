# edge_32_decode.v

## Purpose and ownership

`edge_32_decode` owns RV32 instruction legality for the `edge-32` core. It
layers width-specific checks over the shared `edge_instruction_classifier`,
which continues to own common opcode classification and Edge64 accelerator
metadata.

The local boundary prevents the RV64 baseline from leaking these encodings
into RV32 execution:

- OP-IMM-32 (`0x1b`) and OP-32 (`0x3b`)
- six-bit RV64 immediate shift amounts
- integer `LD`, `LWU`, and `SD`

Rejected instructions report class 15, clear `writes_gpr`, and retain decoded
register indices only for debug visibility. Valid Edge64 accelerator commands
remain supported as a product protocol and are not architectural XLEN values.

## Test

`tests/edge_32_decode_tb.v` checks accepted RV32I/RV32M/Zba encodings, every
RV32 integer load/store width, shift boundary encodings, all OP-32 and
OP-IMM-32 funct3/funct7 combinations, and valid/invalid Edge64 commands.
