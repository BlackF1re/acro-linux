# Hikari BCM4330 SDIO status (2026-10-08)

## Finding

The earlier MMCI PIO fix addresses a cyclic FIFO-window read bug. It does not
fix or validate the separate BAM/DML DMA path. The failing experimental kernel
successfully acquired DMA channels; long SDIO reads therefore bypassed the PIO
FIFO helper. `brcmf_sdio_readframes: RXHEADER FAILED: -70` is `-ECOMM`, matching
the host's `MCI_STARTBITERR`: the controller did not see an SDIO data start bit.
brcmfmac then reported failed backplane access and stopped servicing the device.
That is a failed CMD53 transaction followed by driver recovery failure, not
evidence that the soldered radio or its power rail disappeared.

The experimental kernel reproduced selected Sony BAM settings (descriptor
threshold 64 and `CNFG_BITS = ~BAM_FULL_PIPE`), but this is not a complete
port of Sony's SPS/BAM/DML transfer path. DMA still failed intermittently; the
exact missing DMA sequencing/clocking detail is not yet isolated. Do not treat
BAM enablement as an accepted fix.

## Physical results

The source-level PIO cyclic-window fix had earlier passed a 355 MiB HTTPS
receive run and reconnect checks (see `internal-wifi-bringup-2026-09-16.md`).
The 2026-10-08 DMA run then passed one 10,000-packet test but failed on its next
run after about 5,355 packets with the error above. A separate 48 MHz DMA
transfer also failed after about 16 MiB. These failures do not test the PIO
FIFO fix.

A temporary PIO build enabling the Sony operational SDIO IRQ bit 25 was staged
separately as `/boot/hikari-wifi-sdioirq-test`:

- source base `8d297c8a7a0010560d9f536d2df2d3f6bb5a754e`;
- zImage SHA-256 `92f612a5e16814313fd0106aad85a6c37ae77cc0bb29e524071a5c3960499fa1`;
- matching existing kernel release, no BAM DMA changes;
- first run: 7,724 transmitted, 7,722 received plus 41 duplicates, 0.026% loss,
  no MMCI/brcmfmac error;
- second run: 10,000/10,000 replies, 26 duplicates, 0% loss, no MMCI/brcmfmac error.

The stock `/boot/hikari-next` control then also passed 10,000/10,000 replies,
50 duplicates, 0% loss, with no MMCI/brcmfmac errors. Live inspection confirms
that this stock SDCC4 instance has no DMA channels and runs PIO at 24 MHz. The
test therefore does not establish that the bit-25 change is causal; keep it as
an unaccepted diagnostic candidate.

## Sony-derived BAM/DML follow-up

Three isolated physical attempts used the same current kernel base and the
Sony-like SDCC4 BAM/DML setup at 24 MHz. The DMA channels were present and the
BCM4330 joined Wi-Fi in every run:

- r3: 9,360 ping replies, 0% loss; a 32 MiB HTTPS receive then stopped at about
  15 MiB with `RXHEADER FAILED: -70`, followed by failed backplane access.
- r4: changed the Sony SDCC descriptor FIFO allocation from `dma_alloc_wc()`
  to `dma_alloc_coherent()`. The same failure occurred at about 7.8 MiB.
- r5: restored the r3 allocator and added the Sony `mb()` after DML producer or
  consumer start. The same failure occurred at about 8.3 MiB.

The descriptor-memory allocation and post-start barrier are therefore each
insufficient. The Sony DML ordering is now represented more closely, but this
is still not a successful SPS/BAM port. Keep DMA disabled in production and
retain the verified PIO path. None of r3-r5 changed `/boot/hikari-next`.

## Current state and next step

The last confirmed runtime was r5: Linux 7.3, DMA channels RX 1/TX 2, Wi-Fi
associated before the large receive, then the SDIO RX path halted after
`RXHEADER FAILED: -70`. A BOOT-to-kexec recovery into `/boot/hikari-next` was
issued and its bundle checksums passed, but USB NCM/SSH did not return before
this note was updated; the production boot is therefore not yet confirmed.
No canonical kernel patch was changed. The validated FIFO fix is specific to
PIO; keep the production bundle and 24 MHz PIO configuration as the recovery
target. The next Sony-DMA step needs an ordered comparison of the full SPS
transfer completion/recovery path with current DMAengine, rather than another
isolated register or allocation tweak.

## Follow-up physical tests (2026-10-09)

The verified `/boot/hikari-next` bundle was loaded from immutable BOOT and
reported its expected checksums. On that PIO runtime, a 23,822,896-byte Debian
package download started over Wi-Fi and then reproduced:

```text
brcmf_sdio_readframes: RXHEADER FAILED: -70
brcmf_sdio_dpc: failed backplane access over SDIO, halting operation
```

At the time of capture, `mmc2` was at 24 MHz, 4-bit SD high-speed, and the
interface RX counter was about 9.3 MB. The transfer object was incomplete; its
exact received length was not recorded because the SSH session for that first
test itself used Wi-Fi. This establishes that the failure is not exclusive to
the BAM/DML candidate.

The isolated r6 bundle was then loaded through BOOT. Its boot log confirmed
RX `dma0chan1` and TX `dma0chan2`; the route to the same Debian mirror was over
`wlan0`. Running the same package download while controlling the test over USB
gave:

```text
HTTP 200, 14,318,703 bytes, 32.326829 s, curl exit 28 (speed timeout)
partial-file SHA256 18918eb071f214091214584575abf87491b6b7310c14491f760884d027a7f368
RXHEADER FAILED: -70
failed backplane access over SDIO, halting operation
```

Thus r6 is **not a fix**: the download was demonstrably reachable and began,
but the same SDIO receive-header failure occurred with DMA enabled. Its DML
idle wait did not report a busy timeout. The subsequent attempt to recover the
radio by unbinding its SDIO function blocked in `mmc_wait_for_req_done`; that
attempt was interrupted by returning through BOOT. No production kernel or
BOOT files were changed. The final verified `hikari-next` kexec handoff was
issued, but the system had not yet re-established SSH when this update was
written.

The Sony 6.2.B.1.96 `msm_sdcc.c` has another concrete host-side behavior not
present in current MMCI: it adds a 200 microsecond CPU DMA-latency QoS request
and asserts it around MMC host enable/disable, explicitly preventing idle
power collapse during host activity. This is a focused next discriminator for
the shared PIO/DMA failure; test that QoS vote on the known-good PIO bundle
before adopting it. A separate r7 diagnostic build was prepared in
`/home/paul/xperia/build/hikari-wifi-cpu-qos-r7-20261009`; it inherits r6 and
adds only this 200 us request-scoped vote in MMCI. Build succeeded. Its zImage
SHA-256 is
`ed37e1cc2af7cdb4029ab8cc18df2f51a5998832c5f77debbab2bf35af3b41bf`, and its
DTB SHA-256 is
`1b6cc7877e45f1ef3d631b2c22ffe4b0c7d0d71ec4d3cbef2467d209eccad224`.
It has **not** been staged to the device or physically tested. Do not classify
the QoS change as a fix until a PIO runtime-vote test or repeated r7 downloads
complete without the SDIO header/backplane failure.

After the final verified `hikari-next` handoff, SSH did not return and host USB
NCM had no carrier. The phone's final running state is therefore UNKNOWN; BOOT
and the production bundle remain untouched.

## Follow-up: CPU latency QoS and Sony RX_DATA_PEND (2026-10-09)

On the stock PIO SYSTEM kernel (`7.3.0-rc1-hikari-system-g8d297c8a7a00`), a
runtime `PM_QOS_CPU_DMA_LATENCY` request was held open at 200 us while fetching
the same 23,822,896-byte Debian package. The four-byte QoS request was accepted,
but the transfer stopped at 2,095,076 bytes. At 128.624 s, brcmfmac reported
`RXHEADER FAILED: -70`, followed by repeated `failed backplane access over
SDIO`. Thus the Sony 200 us idle-latency vote alone is **not a fix**.

Source comparison found another explicit Sony Hikari read-path action:
`msmsdcc_start_data()` sets `MCI_RX_DATA_PEND` (bit 20 of `MMCIDATACTRL`) on
every read. Current mainline MMCI defined the Qualcomm bit but did not set it.
A temporary Hikari-only r8 candidate on source commit
`8d297c8a7a0010560d9f536d2df2d3f6bb5a754e` added that bit for SDCC4 reads via
`qcom,rx-data-pend`. It booted as
`7.3.0-rc1-hikari-wifi-rxpend-r8+`; the active DT property was verified at
`/sys/firmware/devicetree/base/soc/amba-bus/mmc@121c0000/qcom,rx-data-pend`.
The candidate zImage SHA-256 was
`438cd26341d2c9446c0b63e1ee472651a2b53627693b07ec4a4243cc04952cdf`; DTB
SHA-256 was
`7a5758550d77e5fda1bcc6d75407b161845362879aebe623d814984a7c2fd3a9`.

Physical result was inconsistent, so r8 is **not a fix**:

| Run | Result |
| --- | --- |
| Initial 23.8 MB transfer | HTTP 200, 23,822,896 bytes, 10.618 s; SHA-256 `e008a53fdfde6b7d2a8e7eae78d793e6d1e1a888c5bccbc9ee48ecea202f1c88`; no SDIO fault |
| Repeat transfer | 15,382,500 bytes in 64.889 s, curl exit 28; `RXHEADER FAILED: -70` at 126.782 s, then backplane access halted |

The r8 bundle and its module directory were removed from the device. During
cleanup, extracting its module archive into `/` replaced the merged-`/usr`
`/lib` symlink with a directory; this was immediately repaired to `/lib ->
usr/lib`, and dynamic binaries were verified before leaving the test kernel.
The known-good production bundle then passed SHA verification and its kexec
handoff was issued. At the last host check, USB was enumerated but NCM had no
carrier and ACM returned no shell output, so post-handoff runtime is UNKNOWN.

### Next Sony-derived difference

The Sony Fuji board assigns SDCC4 the `sps_to_ddr_bus_voting_data` table.
For 4-bit SD high-speed operation at 24 MHz, its policy requests 26 MiB/s
instantaneous bandwidth and 13 MiB/s average bandwidth. Current Hikari SDCC4
has no `interconnects` consumer path, although the current kernel has an
MSM8660 ICC provider. The provider's `sfab_mas_sps` node currently links only
to `sfab_slv_sps`, not onward to the APPSS/EBI path used by Sony's SPS-to-DDR
vote. This is the next concrete kernel-side differential to validate; it has
not yet been patched or physically tested. Do not treat this source difference
as a cause until an ICC candidate passes repeated full transfers.

### Recovery pstore after missing display/USB (2026-10-09)

After returning to immutable BOOT, `/sys/fs/pstore` appeared empty because
pstorefs was not mounted. Mounting it at `/tmp/pstore-check` exposed
`console-ramoops-0` (116,519 bytes, 2,425 lines). There is no panic/oops record.
The console instead contains 2,375 repetitions of `unexpected IRQ trap at
vector 19`; the kernel reports 28,714 callbacks suppressed. On ARM this format
prints the IRQ in hexadecimal, so vector `0x19` is Linux IRQ 25. Its descriptor
dump identifies `msm_gpio_irq_handler` and `bad_chained_irq`, with no active
GPIO child reported by the chained handler. This establishes a GPIO-parent
spurious/unhandled IRQ storm as the observed failure mode, but does not identify
which physical GPIO or device caused it. In the MSM8660 DT, the TLMM aggregate
parent is `GIC_SPI 16` (GIC INTID 48); Linux IRQ 25 is its virtual IRQ number in
the failed kernel, not GPIO 25. The current Hikari wireless DT assigns the
BCM4330 host-wake input to TLMM GPIO128, making it a relevant line to inspect,
but the pstore dump contains no child GPIO number/status and does not implicate
Wi-Fi. It could explain the system becoming unresponsive and losing display/USB
service; pstore alone does not prove the initiating device or a kernel panic.

Ramoops uses the expected reserved range `0x7ffe0000+0x20000` and ECC size 16.
The BOOT kernel reported two corrected header bytes during initialization;
the recovered record reports 2,015 corrected bytes and 2 unrecoverable ECC
blocks, so treat the text as useful but partially damaged evidence. The
recovered console timestamps are around 951.6–952.0 seconds of the prior boot.
