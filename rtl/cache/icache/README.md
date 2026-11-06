# I-cache physical module

`edge_32_icache.v` is the complete product and hardening boundary. This
directory owns its request/response adapter, lookup/refill/invalidate engine
and tag/data arrays, including alternative FPGA array implementations.
The selected APR recipe substitutes array technology views without changing
the public module's protocol.

`edge_ifu_icache.v` is the cache engine's retained module name; it does not
contain the IFU/frontend. PC sequencing, instruction buffering, predecode,
redirect and discarding canceled fetch responses belong to the scalar
frontend outside this directory. The cache completes accepted requests.
The shared cache BIU/AXI bridge also stays outside this boundary.

Use the public top at integration boundaries. Internal array and engine
interfaces are private. Do not compile native and `_yosys` array alternatives
together. Filelists select the implementation explicitly.

Behavioral contract and tests remain under `src/test-32/edge_core`; APR recipes
remain under `src/test-32/physical/openroad/targets`.
