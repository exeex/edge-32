# Cache subsystem source group

```text
icache/                 complete I-cache hardening boundary
dcache/                 complete D-cache hardening boundary
edge_32_cached_core.v    scalar core plus caches and memory routing
edge_32_axi_core.v       cached core plus cache-to-AXI bridge
edge_32_cache_biu.v      shared refill/writeback transport and AXI ownership
edge_32_dtcm_router.v    transaction ownership between cache and DTCM paths
```

The four integration files belong to this source group but remain outside
the individual hardened cache macros. The DTCM router does not own DTCM SRAM.
IFU/frontend and LSU execution stay in their stage directories. Grouping these
files changes neither RTL hierarchy nor transaction/clock/retirement behavior.

The public cache tops remain `edge_32_icache` and `edge_32_dcache`; their
subdirectory READMEs describe the internal boundaries. Filelists select the
appropriate array implementation, while APR recipes and tests stay in test-32.
