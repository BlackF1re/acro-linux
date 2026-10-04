# Superseded intermediate stages

The working prepared kernel source tree is unchanged by this retirement.
Before and after: `647d27c053892b371aed58fd1c6e2f94866e031c`.

- 0047's temporary direct MDP LUT alias was replaced by 0048's distinct CCF
  wrapper. 0048b now implements that final wrapper directly.
- 0053's pixel-RCG ops/parent-propagation experiment was completely undone by
  0057. 0057b adds only the final DSI divider table; no temporary ops switch.
- 0011 edits an intermediate Hikari DTS subsequently overwritten by canonical
  `kernel/dts/`. It is no longer replayed.
- 0009b retains 0009's drivers/bindings/build integration but omits its obsolete
  Hikari board DTS copy. Final board data is installed by the existing prepare
  helper.
- 0085 duplicates all four canonical board files; canonical preparation owns
  these files exclusively now. The files themselves are unchanged.

All original mail patches remain here, including original authors and trailers.
No experiment result was rewritten and no A220 hardware operation was removed.
