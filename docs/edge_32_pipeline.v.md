# edge_32_pipeline

The containing `edge_32_core` handles the read-only hardware-ID CSR
`0xfc0` as a local single-cycle system operation. Its core fields are constants
owned by lite; its product fields come from the elaboration-time
`EDGE_ASIC_ID` parameter. No runtime ID interface crosses this pipeline.

This is a standard single-issue three-stage pipeline: IF, ID/register-read, and
EX/writeback. Independent fast operations may occupy all stages concurrently.
An unfinished EX operation freezes ID and IF; no younger operation can enter a
functional unit or bypass a load, store, MUL/DIV, FPU, or ASIC command.

At the product boundary, `core_start` flushes stale IF/ID/EX payloads while the
frontend captures `boot_pc`; `core_force_stop` flushes buffered frontend and
pipeline work and prevents new fetch. These controls do not reset architectural
registers, cache state, counters, or accepted AXI transactions. Software or the
SoC must only restart after externally visible memory traffic has quiesced.

The only data bypass is the completing EX GPR result into the ID operands that
advance on the same edge. A redirect from EX clears ID and the current EX valid
after the branch completes; the frontend independently restarts target fetch.
There are no sequence IDs, epochs, RTU records, completion ports, or snapshots.

The architectural value path is 32 bits: the GPR file, ID operands, EX operand
registers, completion forwarding, immediates, and GPR writeback all use XLEN=32.
Wider cache, DTCM, AXI, counter, and FPU interfaces are system
boundaries and are explicitly extended or truncated at the containing core.

The `edge32-xlen32` Xilinx synthesis checkpoint maps the complete lite core to
10,682 cells, including 4 DSP48E1, 2,088 flip-flops, and 5,120 LUT1-LUT6 cells.
This is the first retained whole-core checkpoint after narrowing the value path,
so it is a cumulative baseline rather than an adjacent-revision area delta.

The compatibility pipeline container remains 64 bits, but edge-32 always keeps
its upper word zero and `is_64b` false. The instruction adapter is stateless:
opcode `7'h3f` is a complete ASIC32 command and never captures another parcel.

ID classifies each instruction once with `edge_32_decode` and the
pipeline carries `op_class`, `legal`, and `writes_gpr` beside the instruction
into EX. EX does not reclassify or maintain a second opcode/funct legality
table. Product capability checks remain local: a build without FPU rejects FP,
and lite rejects system/custom operations for which it has no implementation.
The local decode wrapper owns RV32 width legality while the shared classifier
remains authoritative for common encodings, accelerator metadata, and Edge
cache-operation fields.

An Edge64 instruction remains the sole EX owner until the serialized
accelerator request is accepted and its matching response arrives. This is a
single-owner handshake, not a command queue: no younger scalar or accelerator
instruction can execute while the command is outstanding.

The containing core uses one `ex_faulting` commit gate. A fetch/decode fault
completes without issuing ALU redirects, MUL/DIV, LSU, FPU, cache, or accelerator
requests. An LSU or accelerator response error suppresses GPR writeback. Every
faulting instruction halts as illegal without incrementing `instret`; only a
non-faulting `ebreak` or Edge break performs its normal halt-side effects.

A terminal instruction becomes architecturally visible on its `ex_done` edge.
That same edge flushes younger ID/IF and any partial Edge64 assembly. The sticky
`halted` state then gates frontend requests/output, execute-unit issue,
writeback, and retirement until reset. An outstanding fetch response may return
after halt but is marked killed and cannot re-enter the pipeline. EX payload
registers are left unchanged so the terminal PC and instruction remain visible
for hierarchical debug.

The request operands follow the shared Edge64 classifier rather than assuming
ordinary scalar `rs1/rs2` conventions. `accel_req_src0` carries the classified
base GPR and `accel_req_src1` carries the command-specific capture GPR;
commands without a capture operand drive the latter to zero.
