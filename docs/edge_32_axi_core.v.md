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
defaults to 64 bits. Edge CSR `0x7db` owns the readable I-cache address header
and CSR `0x7dc` owns the readable D-cache address header; both reset to zero.
The wrapper applies the I header to instruction refills and the D header to
data refills and dirty writebacks at the cache-BIU boundary. Neither header
widens the RV32 frontend, LSU, or cache tags.

Software must clean dirty data and execute `FENCE.I` before changing active
headers. Reset restores both headers to zero; cache metadata reset initialization
leaves all instruction and data lines invalid before a restarted program sets
the header selected by its boot policy.

The wrapper implements the same `boot_pc`, `core_start`, and
`core_force_stop` control form as edge-rv. Reset leaves the product frontend
stopped. A `core_start` pulse captures the 32-bit architectural `boot_pc`,
flushes stale frontend/pipeline contents, and begins fetching. A
`core_force_stop` pulse stops new fetch and discards buffered frontend work
without resetting GPR, CSR, cache, or AXI state. An already accepted cache/AXI
transaction is drained rather than electrically cancelled. The wrapper also
exposes halt, illegal, x31, cycle, and instret status for bring-up.
The focused force-stop test holds the first AXI instruction response, stops
the core after its request is accepted, drains the late response without
retiring it, and restarts from a different `boot_pc`.

`AXI_DATA_WIDTH` is fixed architecturally to 128 bits because both maintained
caches exchange 16-byte beats. Reads and dirty writebacks may progress
independently, matching the separate AXI read and write channels.

The integration CoreMark test places the project-built RV32IMF_Zba/ILP32F
image behind an AXI slave model, checks the `0xf1` and `0xd1` refill IDs and
burst attributes, and requires the current LLVM 22.1.8 Edge32 signature
`instret=587409`.
The same maintained harness accepts `+return_only` for shorter software smoke
images. That mode still checks architectural return state and instruction/data
cache traffic without imposing the CoreMark-specific retire signature.
