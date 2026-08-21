# edge_32_lsu.v

`edge_32_lsu` owns one RV32 scalar or FP memory instruction from issue through
its terminal response. Its base, offset, effective-address register, store
operand, and architectural load result are all 32 bits. Effective-address
addition wraps modulo 2^32.

The memory-side address is 32 bits. The current integration boundary still
uses a 64-bit cache/DTCM beat, so the LSU produces lane-aligned 64-bit store
data and an 8-bit strobe from the low three address bits. The containing core
zero-extends the 32-bit scalar address for the existing cached/AXI wrappers.
Future I/D high-address CSRs belong at that expansion boundary, not in this
LSU. DMA retains its independent native 64-bit address path.

Integer operations are LB/LBU, LH/LHU, LW, and SB/SH/SW. Integer size `11`
(LD/SD) is rejected locally in addition to decode legality. FP16/BF16, FP32,
and both FP8 formats retain their existing size mapping. All multi-byte
accesses require natural alignment; a rejected access completes with
`op_error=1` without emitting a memory request.

`op_ready` is asserted only in IDLE. A captured request remains stable through
backpressure. Loads and ordinary stores wait for the response; local memories
may select `STORE_ACK_ON_ACCEPT=1`. With `MEM_RESP_FORMATTED=0`, the LSU extracts
and sign/zero-extends raw beat data to 32 bits. With it set, the cached response
is already formatted and its low 32 bits are forwarded.

`tests/edge_32_lsu_tb.v` checks request stability, response ownership, signed
loads, lane formatting, natural-alignment faults, LD rejection, and 32-bit
effective-address wraparound.

The adjacent `edge32-lsu32` Xilinx synthesis checkpoint maps this leaf to 490
cells versus 810 for the previous 64-bit LSU. The whole core changes from
10,415 to 10,060 cells, including 96 fewer flip-flops and 149 fewer LUT1-LUT6
cells; the 4 DSP48E1 blocks are unchanged.
