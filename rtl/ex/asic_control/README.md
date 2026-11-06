# ASIC control

`edge_accel_pipe.v` owns the existing accelerator command decode/dispatch
interface used by product integration. `issue.svh` contains scalar EX request,
operand and response-completion wiring. It is included inside EX; request
started/retirement state remains owned by the existing EX transaction slot.

Directory membership does not move the accelerator pipe instance into EX or
change its handshake. Tensor, ACTU, CMPU, DMA and their implementation state
remain in their owning modules; this directory contains control integration.
