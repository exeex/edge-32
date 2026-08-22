# `edge_instruction_classifier`

This combinational leaf owns instruction-family classification shared by
Edge32 and the retiring edge-rv compatibility paths. Its maintained ownership
is `edge-32`; compatibility cores consume it from this repository rather than
keeping another implementation. It has no clock, sequence ID, epoch, queue,
snapshot, or completion state. For scalar instructions it reports legality, broad
execution class, pairing class, and GPR-definition behavior. For an Edge64
length marker it reports vector versus Tensor, sub-op, capture source, optional
vector base source, and Tensor sync/getcsr properties.

The leaf does not schedule instructions or allocate operands. `edge_predecoder`
adds dual-issue, producer-version, snapshot, and redirect policy. Lite consumes
the same properties serially. Vector execution legality remains owned by its
execution decoder; allocated Tensor/ASIC sub-ops are checked here.
The allocated Tensor set must stay aligned with `edge_accel_pipe`, including
Tensor direct/tile starts, ACTU/CMPU starts, and direct/circular WLD and SLD
variants; otherwise the strict serialized lite path rejects an instruction
that the accelerator pipe implements.

Opcode8 `0x89` is the common Edge ASIC-domain power instruction; `imm8[0]`
selects on or off. It is legal in the classifier shared by edge-rv and
edge-rv-lite; product platforms, rather than the classifier, own startup
latency and ready state.
