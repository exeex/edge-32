# Edge32 multiplier primitives

The RTL under `rtl/muldiv/` implements the shared radix-4 Booth recoding,
compression, lane multiplication, and carry-select addition mechanisms used by
the Edge32 ASAP7 multiplier. These leaves are owned by `edge-32` because the
maintained RV32 mul/div implementation and its physical target select their
pipeline and correction structure.

Legacy edge-rv and edge-rv-lite multiplier experiments may temporarily consume
these leaves while those repositories are removed from the main product path.
They must not keep a copied implementation.

The leaves have no architectural state. Their exact composition and registered
boundaries are tested through `edge_32_muldiv_asap7` and the compatibility
multiplier tests. The owning OpenROAD filelist is
`physical/openroad/targets/scalar-muldiv/filelists/edge_32_muldiv_asap7.fl`.

