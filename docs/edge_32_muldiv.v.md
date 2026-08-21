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

## ASAP7 model

`rtl/edge_32_muldiv_asap7.v` is the first ASIC-oriented alternative. It keeps
the same RV32M request/result contract. Its multiplier reuses the measured
edge-rv-lite arithmetic structure, while division is native RV32:

- a pipelined radix-4 Booth 32x32 lane for all four multiply variants;
- magnitude conversion plus a 64-bit sign correction for `MULH`/`MULHSU`;
- two radix-4 restoring slices separated by a register boundary;
- 35-bit partial remainder paths (32 data bits plus three guard bits);
- 16-cycle normal division, with architectural divide-by-zero and overflow
  fast paths.

The generic unit remains the default core implementation. The ASAP7 leaf is a
separate physical-model boundary until its routed timing/area baseline is
recorded. From the parent project, run its functional test with
`edge_32_muldiv_asap7_vvp`, and run the physical probes with:

```sh
./synth/openroad/run_openroad.sh edge_32_mul_asap7 asap7-edge32-mul \
  synth/filelists/edge_32_muldiv_asap7.fl
./synth/openroad/run_openroad.sh edge_32_div_asap7 asap7-edge32-div-native32 \
  synth/filelists/edge_32_muldiv_asap7.fl
```

The initial ASAP7 RVT/TT global-route baselines use OpenROAD 26Q1 and skip
detailed route:

| Leaf | Clock | Die | Placed area | Utilization | Setup / hold slack | Wire | Overflow |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `edge_32_mul_asap7` | 500 ps | 60 x 60 um | 973 um2 | 31% | +10.02 / +40.25 ps | 35,442 um | 0 |
| `edge_32_div_asap7` native32 parallel-subtract | 1,000 ps | 105 x 105 um | 396 um2 | 4% | -404.01 / +51.71 ps | 15,697 um | 0 |

The old RV64-derived divider used 67-bit arithmetic, occupied 2,942 um2, routed
131,812 um of wire, and inserted about 1,008 `BUFx2` cells. Native RV32 reduces
those figures to 396 um2, 15,697 um, and 194 `BUFx2` cells respectively.

The native divider is not timing-closed yet. Computing all three candidate
remainders in parallel improved 1 ns WNS from -732.59 ps to -404.01 ps by
removing the serial compare-then-subtract dependency. The remaining worst path
is inside the `slice1` candidate subtract/result-selection cone. A 5x7-bit
carry-select experiment regressed WNS to -659.61 ps and was rejected.
Detailed-route DRC/LVS remains required before hard-macro signoff.
