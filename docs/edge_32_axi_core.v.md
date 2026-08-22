# edge32_axi_core (`edge_32_axi_core.v`)

`DTCM_ADDR_WIDTH` parameterizes the scalar DTCM word-address port. It defaults
to 14 for the 128 KiB e3 configuration and is 15 for the 256 KiB e4 setup.

This integration wrapper composes `edge_32_cached_core` and
`edge_32_cache_biu`. Its AXI port names, widths, IDs, burst lengths and
cache attributes match the `biu_pad_*`/`pad_biu_*` boundary of the maintained
Edge product core. It is therefore the first lite boundary that can connect to
the existing SoC AXI interconnect without testbench SRAM ports.

`cpurst_b` is the asynchronous board/product reset input. A two-flop
`ASYNC_REG` chain asserts internal reset asynchronously and deasserts it
synchronously to `forever_cpuclk`. Both the cached core and cache BIU receive
the same synchronized reset, so pipeline, cache-controller and AXI state cannot
leave reset on different clock edges. Functional activity begins only after
the second rising edge following external reset release.

The scalar instruction/cache address domain is 32 bits. `AXI_ADDR_WIDTH`
defaults to 64 bits, and the wrapper zero-extends instruction refill addresses
only at the cache-BIU boundary. This leaves the external AXI fabric ready for
native 64-bit DMA traffic without carrying unused upper address bits through
the RV32 frontend or I-cache. Future I-cache high-header CSR concatenation
belongs at this same boundary.

The wrapper implements the same `boot_pc`, `core_start`, and
`core_force_stop` control form as edge-rv. Reset leaves the product frontend
stopped. A `core_start` pulse captures the 32-bit architectural `boot_pc`,
flushes stale frontend/pipeline contents, and begins fetching. A
`core_force_stop` pulse stops new fetch and discards buffered frontend work
without resetting GPR, CSR, cache, or AXI state. An already accepted cache/AXI
transaction is drained rather than electrically cancelled. The wrapper also
exposes halt, illegal, x31, cycle, and instret status for bring-up.

`AXI_DATA_WIDTH` is fixed architecturally to 128 bits because both maintained
caches exchange 16-byte beats. Reads and dirty writebacks may progress
independently, matching the separate AXI read and write channels.

The integration CoreMark test places the project-built RV32IMF_Zba/ILP32F
image behind an AXI slave model, checks the `0xf1` and `0xd1` refill IDs and
burst attributes, and requires the current LLVM 22.1.8 Edge32 signature
`instret=587409`.
