# Edge32: an RV32 control core built for physical timing

Edge32 is the public RV32 successor to `edge-rv-lite` for NPU control. It is a
single-issue, four-stage, in-order core implementing RV32IMF with Zba. The
redesign prioritizes ASAP7 physical timing and routability: register
reads, frontend control, multiplication, division, and the boundaries between
pipeline stages. The NPU performs bulk computation outside the scalar core.

The main tradeoff is visible in software. Compared with the former RV64 lite
core, Edge32 uses substantially fewer FPGA logic resources and has more
measured pre-CTS timing margin. Its two-iteration CoreMark checkpoint takes
25.5% more cycles per iteration. A historical product-level Tensor comparison
is slightly faster on Edge32; the Tensor implementation is outside this public
repository and is not described here.

## What changed

| Upgrade | Result |
| --- | --- |
| Four-stage scalar pipeline | IF/predecode, ID/read, EX/execute, WB/retire replace the former three-stage RV64 scalar path. |
| Physically local register reads | IF captures source indices for a new 2-read/1-write GPR; bit-sliced storage and local read muxes shorten the register-read cone. |
| Smaller RV32M unit | One native RV32 multiplier/divider replaces the former RV64 leaf. The multiplier uses six smaller products; division uses a native radix-4 implementation. |
| Narrower scalar state | RV32 registers and scalar addresses reduce the cached-core FPGA estimate by 48.5% in total cells and 37.4% in LUTs. |
| 64-bit product addressing | Cache address headers and split DMA address commands retain access to 64-bit physical addresses. |
| Product behavior | Recorded 64x64 Tensor windows improve by 0.74% and 0.97% against the matched RV64-lite reference. |
| Scalar cost | CoreMark grows from 785,777 to 985,783 cycles per iteration at the measured RTL checkpoints. |

## Architecture chosen for ASAP7 timing

The scalar pipeline has four stages:

| Stage | Work |
| --- | --- |
| **IF** | Fetch and predecode GPR/FPR indices and coarse instruction properties. |
| **ID** | Read operands, check dependencies and legality, and capture the issue controls. |
| **EX** | Execute one scalar instruction or issue an accelerator command. A variable-latency operation retains EX ownership until it completes. |
| **WB** | Commit register/CSR state and retirement in program order. |

Predecoding indices in IF removes instruction-field decode from the ID register
read path. The `edge_32_gpr` register file has two read ports and one write
port. Its 31 writable 32-bit words are organized as 32 physical bit slices,
with local storage and two local read muxes per slice. WB-to-ID forwarding
preserves architectural same-cycle reads. The FPR file keeps a separate write
path through registered WB. Frontend stop and request-capacity logic are kept
near the frontend rather than joined to a wide EX completion path.

The RV32M owner is `edge_32_muldiv_asap7`. Its six-product 3x2 multiplier tree
reduces wide multiplier wiring; the native radix-4 divider avoids carrying the
old RV64 arithmetic datapath into Edge32. These structures were selected for
physical timing and routing pressure. A multiply occupies a six-stage product
pipeline, which increases scalar latency relative to the former lite leaf.

### Physical evidence and limit

The design was iterated against a 1 GHz ASAP7 TT physical flow with actual
placement coordinates and estimated wire RC, rather than judging timing from
RTL depth alone. The comparable integration checkpoints are:

| ASAP7 checkpoint | Setup slack | Repaired core area |
| --- | ---: | ---: |
| Preceding three-stage GPR design | +4.82 ps | 3,702 µm² |
| Four-stage GPR design | +158.12 ps | 3,735 µm² |
| Later frontend-local control checkpoint | +158.69 ps | 3,588.50 µm² |

The four-stage change added timing margin on the measured placement path. The
later control checkpoint passed 320/320 functional tests. Its worst path was in
the divider; the separate +200 ps setup-reserve target was still 41.31 ps
short. These figures are **pre-CTS placement-RC checkpoints**, not extracted
post-route timing or foundry signoff for the current RTL. They show the
physical constraints that guided the redesign; they do not establish a final
routed clock frequency.

## Resource comparison with edge-rv-lite

Yosys 0.67+post (`b8e7da6f`) ran `synth_xilinx -family xc7 -noiopad
-noclkbuf` with default DSP mapping and the same FPGA RAM model. The
comparison covers cached scalar cores with FPU disabled and default 16 KiB
I-cache and D-cache. The old baseline is `edge-rv-lite` `a25755d` with its
`edge-rv` dependency `e875ea8`; Edge32 RTL is `e8c13c0` (unchanged in the
subsequent documentation revision). The cores differ in ISA width, pipeline,
and arithmetic architecture, so this measures the full upgrade.

| Cached-core resource | RV64 lite | Edge32 | Change |
| --- | ---: | ---: | ---: |
| Total Yosys cells | 32,709 | 16,860 | -48.5% |
| LUT1–LUT6 | 15,447 | 9,669 | -37.4% |
| Flip-flops | 6,702 | 3,959 | -40.9% |
| CARRY4 | 653 | 299 | -54.2% |
| MUXF7 + MUXF8 | 2,991 | 874 | -70.8% |
| DSP48E1 | 4 | 6 | +2 |
| RAMB18E1 / RAMB36E1 | 32 / 6 | 32 / 5 | 0 / -1 |

The separate mul/div synthesis makes the arithmetic tradeoff clearer:

| Mul/div resource | RV64 lite leaf | Edge32 RV32M | Change |
| --- | ---: | ---: | ---: |
| Total Yosys cells | 4,318 | 1,636 | -62.1% |
| LUT1–LUT6 | 1,973 | 852 | -56.8% |
| Flip-flops | 743 | 394 | -47.0% |
| CARRY4 | 273 | 138 | -49.5% |
| MUXF7 + MUXF8 | 130 | 1 | -99.2% |
| DSP48E1 | 4 | 6 | +2 |

The two additional DSP blocks buy a much smaller LUT/carry/mux network.
These are FPGA synthesis estimates, not ASIC area, routed wire length, or Fmax.
The [parent synthesis guide](../../synth/README.md) describes the runnable
profiles; the historical lite source revisions are pinned above.

## Performance: the scalar tradeoff and the Tensor result

### CoreMark

The current Edge32 RTL (`abe4ae0`) ran the two-iteration bare-metal CoreMark
image on its cached AXI core in Verilator 5.050. LLVM 22.1.8 compiled
RV32IMF_Zba / ILP32F at `-O2`; the FPU and default 16 KiB caches were enabled.
The historical testbench came from `edge-cores` `c257689b` and used its pinned
CoreMark source `4bda0ead`. CRC validation, retired-count checking, and I/D
cache traffic checks passed. The RV64-lite number is taken from the
[old lite README](https://github.com/exeex/edge-rv-lite/blob/a25755dc4e8904b13af1f68152a3f165764fa55b/README.md#coremark-and-tensor-benchmark-report);
that core was not rerun.

| Metric | RV64 lite | Edge32 | Edge32 change |
| --- | ---: | ---: | ---: |
| Internal `rdcycle` cycles per iteration | 785,777 | 985,783 | +200,006 (+25.5%) |
| Iterations per MHz, derived from cycles | 1.273 | 1.014 | -20.3% |
| Retired instructions, complete image | 616,228 | 587,409 | Different RV64/RV32 images |

The two-iteration run is a development checkpoint, not an official CoreMark
submission. Both cycle figures use the timed `rdcycle` interval rather than
whole-testbench runtime. The six-stage multiplier contributes to scalar cost,
but the measured gap cannot be assigned to it alone: the binaries, pipeline,
and memory behavior differ. The Edge32 run counted 19,032 integer multiplies
and two divides across the complete two-iteration image. Verilator does not
include physical wire delay; elapsed time also depends on post-route clock
frequency.

### Tensor product checkpoint

The following **historical** 2026-08-21 measurement uses the same 64x64
software workload and the same `X30` timing boundary on the three products.
It includes weight production and Tensor execution, while excluding boot,
input packing, and output scatter. The Edge32 product ran at checkpoint
`654ddab`; it was not rerun after the later four-stage and RV32M changes.

| 64x64 case | `edge-rv@e3` | `edge-rv-lite@e3` | `edge32@e3` | Edge32 vs lite |
| --- | ---: | ---: | ---: | ---: |
| 64 tokens, X30 cycles | 4,660 | 4,699 | **4,664** | **-35 (-0.74%)** |
| 128 tokens, X30 cycles | 8,772 | 8,785 | **8,700** | **-85 (-0.97%)** |

Edge32 was slightly faster in these matched Tensor windows despite the scalar
CoreMark tradeoff. This is the measured product-level result of the optimized
integration; it does not isolate individual cycle savings. The Tensor RTL is
outside this public repository, so this README reports the result without
implementation details. The lite README also contains a different
`tiled_circular` case; its figures are not mixed with this `runtime_shape`
comparison.

## RV32 with 64-bit physical addresses

The PC, GPRs, and scalar effective addresses are 32 bits. Each I-cache and
D-cache operates within a selected 4 GiB address window; a separate 32-bit
header CSR supplies the upper physical-address bits at the AXI boundary.
Software must maintain cache state when changing headers because low addresses
can alias across windows. The default cache capacities are 16 KiB each and do
not determine the window size.

DMA has a separate 64-bit address path. `edge_dma_setsrc` and
`edge_dma_settar` emit low-32 and high-32 commands, and `edge_accel_pipe`
combines them into 64-bit source and target addresses. RV32 scalar addressing
therefore does not truncate DMA physical addresses.

## Using the public RTL

The canonical source lists are [`filelists/edge_32.fl`](filelists/edge_32.fl)
for the cached core and
[`filelists/edge_32_muldiv.fl`](filelists/edge_32_muldiv.fl) for the standalone
RV32M owner. Public software uses
[`include/intrinsic.hpp`](include/intrinsic.hpp) or the explicit
[`edge32_intrinsic.hpp`](include/edge32_intrinsic.hpp). Build for
`riscv32-unknown-elf` with `-march=rv32imf_zba -mabi=ilp32f`.

The local CMake project exposes RTL sources. Software-image construction,
Verilator tests, and ASAP7 physical experiments belong to the composed
`edge-cores` test harness; the current `src/edge-32/CMakeLists.txt` does not
provide standalone CoreMark or Tensor test targets. To run the maintained
public FPGA resource profile from the parent checkout:

```sh
./synth/run_profile.sh --check edge-32 xilinx
./synth/run_profile.sh edge-32 xilinx
```

The public Edge32 RTL is licensed under
[CERN-OHL-P-2.0](LICENSE.md). The parent `edge-cores` repository has its own
Apache-2.0 license; the license of this submodule applies to the files here.
