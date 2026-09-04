# Hikari g33 missing SCM provider diagnosis

Status: sanitized `VERIFIED_DEVICE` runtime diagnosis. Display scanout, panel
pixels, fbcon, and physical backlight output remain `NOT_VERIFIED`.

## Physical artifact and outcome

```text
/home/paul/xperia/build/hikari-artifacts-g33-display/hikari-display-secure-mmcc.elf
size: 12,516,700 bytes
SHA-256: 8f0dbccff8f06dbdadb21f1837d83a9b36d2ed718e2fdaac654aabe8d232d7cd
kernel: 7.3.0-rc1-g067c4e54fde9
```

The target booted its native initramfs and retained the previously verified
USB ACM shell. There was no DRM card or visible display output. AS3676 was
present in sysfs with requested brightness 32, but that software state is not
evidence that the physical backlight emitted light.

The relevant live state was:

```text
qcom_scm: convention: smc legacy
4000000.clock-controller: unbound
4700000.dsi: supplier 4000000.clock-controller not ready
5100000.display-controller: supplier 4000000.clock-controller not ready
```

There was no bound `qcom_scm` platform device and the live DT contained no
`qcom,scm` compatible. Therefore the secure-MMCC driver's
`qcom_scm_is_available()` gate returned false and deferred MMCC exactly as
designed. The convention line alone is architecture initialization and does
not instantiate the DT-backed SCM platform driver.

## Correction

The Hikari root DT now contains an MSM8660 SCM firmware node:

```text
compatible = "qcom,scm-msm8660", "qcom,scm"
clock-names = "core"
core clock = RPM_DAYTONA_FABRIC_CLK (binding ID 10)
```

Kernel commit `073f7ab967d08d6c60f9c491e7ac2fa81fb1600f` contains the
node. The project static gate resolves the final-DTB clock phandle and ID, not
merely the DTS spelling. A scoped `dtbs_check` against
`qcom,scm.yaml` completed without a Hikari warning.

The next local artifact also installs three compact read-only reports in the
diagnostic initramfs: `hikari-diag`, `hikari-display-diag`, and
`hikari-power-diag`. BusyBox itself remains unchanged at 408 compiled applets.
These helpers do not write MMIO, I2C, GPIO, regulators, clocks, or storage.
