# EX CSR and system-control dispatch

This directory collects CSR-facing operations without moving architectural
state away from its existing commit owner.

- `operations.svh`: selects cycle/instret, FP CSR, hardware-ID and cache-header
  read values; computes cache-header read/modify/write data.
- `cache_control.svh`: dispatches cache maintenance and fence.i requests to
  cache interfaces and observes their completion. Cache implementation remains
  in `rtl/cache`; EX still owns the outstanding-operation lifetime.
- `edge_32_counter64.v`: counter mechanism used for cycle and instret. Existing
  core instances provide enables and export values to CSR reads.

The `.svh` files are private EX implementation, not standalone modules. Header
register updates remain WB commit-qualified; FP CSR state remains in the FPU.
Instret read serialization, cancellation and all request/completion cycles are
unchanged. This is a dispatch boundary, not a replacement register bank for all
CSR state.
