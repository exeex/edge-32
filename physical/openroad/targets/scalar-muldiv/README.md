# Edge32 scalar multiply/divide physical target

Owns the Edge32 multiplier/divider composition filelist and its ASAP7 profile
lineage. The profiles intentionally remain runnable as a relative inheritance
chain so accepted baselines and live variants can be reduced separately.

The old integration-repository paths are compatibility symlinks only.

Run the accepted detailed-route target from the integration workspace with:

```sh
synth/openroad/run_target.sh \
  src/edge-32/physical/openroad/targets/scalar-muldiv
```
