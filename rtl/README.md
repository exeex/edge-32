# Edge32 RTL ownership

Organize implementation files by architectural responsibility. Directory
membership does not change module instantiation, pipeline latency or physical
hierarchy. In particular, the GPR read owner remains a sibling of ID in the
core even though its sources live under `id/gpr/`.

```text
if/           IF stage, frontend, fetch/admission/predecode implementation
id/           ID stage, decoder/classifier, dependency/admission implementation
  gpr/        GPR bank and local source-index/RAW owner
ex/           EX stage and issue/completion/transaction implementation
  alu/        integer ALU
  branch/     compare and branch target
  lsu/        scalar memory-operation owner
  muldiv/     multiplier, divider and their arbitration
  csr/        CSR read/modify dispatch, cache maintenance and counters
  asic_control/ accelerator command pipe and EX request/response wiring
wb/           WB stage, completion capture and architectural retirement
cache/        cached-core/AXI composition, shared BIU and cache/DTCM routing
  icache/     complete independently hardened instruction-cache boundary
  dcache/     complete independently hardened data-cache boundary
fpu/          independent FP owner, FPR, arithmetic and memory formatting
```

The decoder/classifier under `id/` is also consumed by IF predecode. Its source
location is not an extra decode stage. The frontend file includes narrow
frontend-control/capacity helpers used across the existing stage boundary.
Counters remain independently instantiated in the core. FP memory formatting
belongs to the FPU owner, not to the integer LSU.

Scalar core composition remains at this directory's root, together with
cross-stage type and external-FPU interface headers.
Cache integration lives in `cache/`; I/D-cache does not own IFU or LSU.

Independently hardened leaves retain explicit subdirectories within their
architectural group; source placement must not silently expand a hardening
boundary. Filelists select RTL/FPGA/ASIC implementations. APR wrappers and
technology views stay in the physical flow. Tests and detailed behavioral
contracts stay under `src/test-32`.
