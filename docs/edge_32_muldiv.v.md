# edge_32_muldiv.v

## Purpose

`edge_32_muldiv` is the first simple RV32M implementation for `edge-32`. It
owns one accepted operation until its result pulse. The core holds EX while
`busy` is asserted, so no sequence or destination metadata is stored here.

## Multiply implementation

All multiply variants use direct Verilog `*` expressions. The signed operands
are explicitly extended to 33 bits so `MULH` and `MULHSU` retain the correct
64-bit product bits. This representation is deliberately portable and allows
Yosys FPGA synthesis to infer DSP primitives. Multiply completes on the
accepting edge and exposes a one-cycle result-valid pulse.

Supported variants are `MUL`, `MULH`, `MULHSU`, and `MULHU`.

## Divide implementation

Division uses one radix-2 restoring iteration per cycle and takes 32 cycles.
The unit keeps absolute operands internally and applies quotient/remainder signs
at completion. Divide-by-zero and signed `INT_MIN / -1` complete immediately
with the architectural RV32M result.

Supported variants are `DIV`, `DIVU`, `REM`, and `REMU`.

`op_ready` is low throughout an iterative divide. Reset cancels an outstanding
divide without producing a stale result.

## Test and synthesis

`tests/edge_32_muldiv_tb.v` covers all eight RV32M operations, signed corner
cases, divide-by-zero, overflow, busy backpressure, and reset cancellation.
The synthesis probe uses the same RTL and checks that Xilinx mapping contains
DSP cells for the direct multiply operators.

With Yosys `synth_xilinx -family xc7`, the current leaf maps to four
`DSP48E1`, 560 estimated logic cells, and 170 flip-flops. This is FPGA mapping
evidence only, not an ASIC area claim.
