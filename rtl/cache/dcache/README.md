# D-cache physical module

`edge_32_dcache.v` is the complete product and hardening boundary. This
directory owns its scalar adapter, lookup/miss/maintenance engine, queues,
scheduler and tag/data/dirty/metadata arrays. `edge_dcache.v` is the retained
internal engine name, not a second public product boundary.

The scalar LSU owns instruction execution and address generation outside the
cache. DTCM routing and the shared cache BIU/AXI bridge also stay outside.
CPU request/response, maintenance and refill/writeback are the public groups;
internal queue identities and SRAM control signals do not cross the boundary.

Filelists explicitly select native, FPGA or ASIC array implementations. Keep
generated physical views and mapped replacements in their owning build/APR
flow; do not duplicate functional control logic in an APR wrapper.

Behavioral contract and tests remain under `src/test-32/edge_core`; APR recipes
remain under `src/test-32/physical/openroad/targets`.
