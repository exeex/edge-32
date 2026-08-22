# edge_32_cached_core.v

`DTCM_ADDR_WIDTH` is passed to the DTCM router and sizes the exported DTCM
word address. The no-DTCM configuration ties off the complete parameterized
width.

This integration leaf composes the bootable single-issue lite core with the
maintained `edge_ifu_icache` and `edge_dcache`. The lite adapters translate the
one-owner 32-bit fetch and scalar LSU handshakes into the existing cache
contracts. No testbench memory may connect directly to the core-side request
ports at this boundary.

Product integration sets `AUTO_START=0` and forwards the edge-rv-compatible
`boot_pc`, `core_start`, and `core_force_stop` controls to the scalar frontend.
Reset alone cannot issue an instruction refill in that configuration. The
default `AUTO_START=1` is retained only for focused legacy leaf tests that
instantiate the core below the product boundary.

Scalar effective addresses originate as 32-bit values in `edge_32_lsu` and
are zero-extended before the existing 64-bit D-cache/DTCM address contracts.
DMA addressing is independent of this scalar path and remains natively 64-bit.

The frontend, branch targets, I-cache tags, and instruction refill address are
all 32 bits. Address expansion is deliberately outside this module at the
64-bit AXI boundary. The readable I/D header CSRs are applied there without
widening the RV32 cache internals.

The external instruction interface is one aligned 16-byte refill. The external
data interface is the maintained 64-byte D-cache refill protocol carried as
four 128-bit beats, plus the 128-bit dirty-line writeback stream and completion
acknowledgement. These are the cache-to-BIU ports that the later
`edge_core_top`-compatible wrapper will arbitrate onto AXI.

Instruction refill errors pass through the maintained I-cache and lite adapter
to the core fetch response. An errored refill satisfies the outstanding miss
without updating the I-cache data or tag arrays, so bad AXI data cannot become
an executable cache hit.

`FENCE.I` is a serialized execute-stage operation. The core stops advancing
younger instructions and requests a full I-cache valid-bit sweep after any
already accepted instruction refill has drained. The cached wrapper blocks new
fetch requests while invalidate request, inflight, or cache-busy state is set;
the direct busy gate also covers the wrapper/cache state transition cycle. When
the 1024-line 16 KiB sweep (or
2048-line 32 KiB sweep) completes, the pipeline discards all younger IF/ID
state and restarts at `fence_pc + 4`, so the next access refills modified code.
Software must first make code bytes visible in backing instruction memory—for
example by completing D-cache clean/writeback or DMA—and then execute
`FENCE.I`. The instruction has no separate software-visible error result;
ordinary refill errors are reported when the new fetch occurs.

Only lane 0 is connected. Lane 1, redirect-kill metadata, and backend pause
inputs are tied inactive because the lite core cannot have a younger
outstanding scalar memory operation. D-cache sequence and epoch fields are
constant zero. This module adds no RTU, snapshot, replay or completion queue.

The focused test boots through real I-cache misses, proves the D-cache
load/store result `x30=42`, calls a cached code line, modifies its backing
instruction, executes `FENCE.I`, and calls it again. It requires the invalidate
sweep to block fetch, exactly two refills of the modified line, and the new
instruction result `x31=2`.

The AXI software header test boots with both header CSRs at zero, dirties a
D-cache line, performs clean+invalidate while the old header is active, then
switches the D header and observes a new refill. It subsequently switches the
I header and executes `FENCE.I`; the next aligned code target must refill using
the new instruction header. CSR reset and readback checks are performed by the
RV32 program rather than testbench backdoor writes.
After the first run has populated both caches, the same test asserts product
reset and boots the image again. It requires both CSRs to return to zero and
observes fresh zero-header instruction and data refills, proving stale cache
metadata cannot survive reset.

The AXI control-flow software test covers dependent taken/not-taken branches,
a backward loop, JAL and odd-target JALR link semantics, and redirects across
I-cache lines. Stores and an I-header CSR write placed on wrong paths must
remain architecturally invisible.

The cached CoreMark integration test loads the parent harness memory image only
behind these refill/writeback ports. It services I-cache lines and D-cache
four-beat refills independently, commits dirty writeback beats to the backing
array, and requires the local LLVM 19.1.1 image baseline
`instret=743510`. The LLVM 22.1.8 image is tracked separately at
`instret=616228`; instruction counts must not be mixed across those generated
images. This is the first lite CoreMark test that includes real cache hit/miss
state; it still stops at the pre-BIU boundary and therefore does not model AXI
arbitration.
