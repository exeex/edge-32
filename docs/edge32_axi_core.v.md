# edge32_axi_core.v

Product-facing module name for the Edge-32 cached AXI core. It preserves the existing
AXI128, 64-bit AXI address, 64-bit scalar-DTCM compatibility, accelerator
request, and debug ports of `edge_rv_lite_axi_core`, while fixing the scalar PC
width to 32 bits at product instantiation sites.

The renamed top deliberately adds no protocol state. E3/E4 select the Edge-32
or RV64-lite filelist at build time instead of compiling both internal module
sets together, whose historical `edge_rv_lite_*` names overlap.
