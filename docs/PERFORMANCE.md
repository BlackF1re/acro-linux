# Performance

The current shell is Phosh with hardware GLES2 on FD220; see
[STATUS.md](STATUS.md) for exact identities. Earlier Cage/software-rendered
and reduced-RAM measurements are historical comparison points, not current
performance figures. They are preserved in the operational-document archive.

No release-grade comparative power/performance baseline is claimed. Measure
PSS/RSS, idle/load CPU, wakeups, frame timing and power on the same kernel,
thermal state and runtime. CPU DVFS/suspend acceptance is tracked separately.

Cleanup omits DWARF, KALLSYMS_ALL and optional firmware/USB/RCU debug extras
from the SYSTEM fragment. Dynamic debug, recovery logs and diagnostic tools
remain available. The exact historical resolved config is retained unchanged
as build provenance; newly generated configs use the maintained fragments.
