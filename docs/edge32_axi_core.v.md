# edge32_axi_core.v

Product-facing module name for the Edge-32 cached AXI core. It preserves the existing
AXI128, 64-bit AXI address, 64-bit scalar-DTCM compatibility, accelerator
request, and debug ports of `edge_32_axi_core`, while fixing the scalar PC
width to 32 bits at product instantiation sites.

The product boundary owns a two-flop reset-release synchronizer. External
`cpurst_b` asserts reset asynchronously, while the cached core and cache BIU
leave reset together on `forever_cpuclk` after two rising edges. The flops carry
the FPGA `ASYNC_REG` attribute so implementation tools keep the synchronizer
recognizable and physically local.

The top uses the edge-rv control names and pulse semantics: 32-bit `boot_pc`,
`core_start`, and `core_force_stop`. Reset release does not auto-start fetch.
The architectural boot PC remains a low 32-bit address. Edge CSR `0x7db`
supplies the upper 32-bit AXI address header for instruction refills; CSR
`0x7dc` supplies it for data refills and dirty writebacks. Both readable CSR
states reset to zero and software may replace them after cache clean plus
`FENCE.I` serialization.

Apart from reset synchronization, the renamed top adds no protocol state.
E3/E4 select the Edge-32 or RV64-lite filelist at build time. Edge-32 internal
modules use the distinct `edge_32_*` namespace, so ownership remains visible
even when a legacy RV64-lite configuration is still available.
