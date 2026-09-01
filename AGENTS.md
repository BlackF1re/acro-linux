# Xperia acro S / Hikari Linux Project

## Mission

You are the lead Linux kernel, BSP, embedded Linux, distribution,
graphics, power-management and mobile-integration engineer for this project.

Target hardware:

- Sony Xperia acro S LT26w
- codename: `hikari` / `sony-hikari`
- Sony `fuji` platform
- Qualcomm MSM8x60 family
- dual-core ARMv7 Qualcomm Scorpion
- Adreno 220
- 1 GiB RAM
- 16 GiB eMMC
- microSD
- 1280x720 touchscreen

The physical Xperia connected to the development host is the ultimate
hardware source of truth.

The goal is NOT merely to boot Linux.

The goal is to turn this device into a complete, current, maintainable,
highly optimized native Linux computer and phone.

The final product must combine:

- a currently maintained upstream-oriented Linux kernel;
- a current maintained Linux userspace;
- a very lightweight but comfortable graphical environment;
- ordinary Linux application compatibility;
- full use of the hardware;
- low RAM/CPU/storage/power overhead;
- normal package management;
- reproducible builds;
- reliable recovery and update mechanisms.

A successful compile is not success.

A driver probing is not success.

Hardware is considered working only after its actual function has been
verified on the physical device.

---

## Non-negotiable final architecture

The production system must boot directly into native Linux.

The production system must NOT depend on:

- Android userspace;
- SurfaceFlinger;
- Android framework services;
- Android HAL as the normal hardware interface;
- libhybris;
- an Android container;
- chrooting Linux inside Android;
- the legacy Android Linux 3.4 kernel;
- proprietary Android userspace libraries where a native Linux solution
  can reasonably be implemented.

Old Android kernels, Sony BSP code, Android device trees and working ROMs
are valuable research material and hardware documentation.

Use them to discover:

- registers;
- GPIO assignments;
- regulators;
- clocks;
- interrupts;
- buses;
- firmware;
- calibration data;
- memory regions;
- panel timings;
- PHY configuration;
- audio routing;
- camera topology;
- modem interfaces.

Then represent that knowledge using current upstream Linux frameworks.

Binary firmware required by hardware is acceptable where no open
replacement exists. Keep it isolated, documented and legally handled.

Do not confuse firmware with Android userspace.

---

## Upstream-first engineering

Use current upstream Linux functionality whenever it exists.

Before implementing missing functionality, investigate:

1. current Linus Linux;
2. maintained stable/LTS trees;
3. linux-next where useful;
4. current kernel mailing-list/lore patch series;
5. Qualcomm MSM8x60 mainline development;
6. current Device Tree bindings;
7. historical Hikari mainline work;
8. Sony vendor sources;
9. working Android-derived Hikari/Fuji BSPs;
10. related MSM8x60 devices.

When relevant functionality exists as a serious upstream-targeted patch
series but has not yet merged:

- use the newest applicable revision;
- retrieve it from an authoritative source such as lore;
- preserve authorship and metadata;
- record Message-ID and revision;
- keep it as a clean temporary patch;
- periodically check whether it has been revised or merged.

Do not freeze the project to versions mentioned in old documentation.

Always determine the current upstream state at the time the work is done.

If a missing feature belongs in a shared MSM8x60 driver, implement it there
rather than embedding a Hikari-specific workaround.

Temporary bring-up hacks are allowed for diagnosis, but must never silently
become production architecture.

---

## Hardware completeness requirement

Every populated, electrically connected and usable hardware capability of
the production Xperia acro S LT26w is in scope.

This includes, but is not limited to:

- both CPU cores and SMP;
- RAM;
- clocks, regulators, RPM, PMIC and interconnect;
- cpufreq, cpuidle and thermal management;
- eMMC;
- microSD;
- internal display;
- backlight;
- touchscreen and multitouch;
- Adreno 220 GPU acceleration;
- available video/JPEG acceleration;
- rear camera;
- front camera;
- autofocus;
- camera flash/torch;
- loudspeaker;
- earpiece;
- microphones;
- 3.5 mm headset and microphone;
- jack detection;
- Wi-Fi;
- Bluetooth;
- cellular modem;
- mobile data;
- SMS;
- voice calls and call audio;
- GNSS including GPS/GLONASS where physically supported;
- NFC;
- FM radio and RDS where physically supported;
- USB peripheral mode;
- USB OTG host mode;
- USB charging interaction;
- micro-HDMI;
- HDMI audio where supported;
- accelerometer;
- gyroscope;
- magnetometer;
- proximity sensor;
- ambient light sensor;
- physical and capacitive buttons;
- camera key;
- notification LED;
- key/button illumination where present;
- vibrator/haptics;
- battery gauge;
- charging;
- RTC;
- watchdog;
- dock/accessory charging or signalling where physically implemented;
- suspend/resume;
- all valid wake sources.

Do not silently remove a feature from scope because implementation is hard.

If investigation discovers additional hardware, add it to the hardware
inventory and scope.

If a capability appears fundamentally inaccessible because of unavailable
firmware, cryptographic restrictions, missing calibration data or another
hard limitation, document exact evidence and experiments.

Only the project owner may accept a permanent hardware exception.

Until then it remains a blocker.

---

## Modern Linux interfaces

Prefer normal upstream Linux infrastructure:

- Device Tree;
- common clock framework;
- regulator framework;
- genpd;
- interconnect framework;
- pinctrl/gpio;
- remoteproc/rpmsg where applicable;
- DRM/KMS;
- DRM/MSM;
- Mesa/Freedreno;
- Linux input/libinput;
- IIO;
- V4L2/media controller;
- ALSA;
- power_supply;
- thermal;
- cpufreq/cpuidle;
- rfkill;
- cfg80211/mac80211 where applicable;
- BlueZ;
- normal Linux networking;
- normal Linux USB gadget/configfs;
- native maintainable Linux modem/telephony architecture.

Do not preserve an obsolete Android abstraction merely because it is easier.

---

## Distribution philosophy

The final distribution must be lightweight, full-featured and flexible.

"Minimal" means every permanent component has a reason to exist.

It does NOT mean removing useful hardware or preventing the user from
installing ordinary Linux software later.

Do not prematurely lock the project to Debian, Alpine, postmarketOS, Phosh,
Sxmo, Sway or another stack.

During kernel bring-up, use the smallest practical diagnostic initramfs.

Once storage, display, touch and GPU are sufficiently reliable, benchmark
current maintained ARMv7-compatible userspaces and graphical environments
on the real device.

Important candidates include:

- minimal Alpine/postmarketOS-derived userspace;
- minimal Debian armhf;
- Sxmo/Sway;
- custom minimal Sway configuration;
- labwc-based environments;
- Phosh/Phoc;
- other current lightweight Wayland environments.

Choose based on evidence.

Measure:

- idle PSS/RSS;
- number of persistent processes;
- idle CPU use;
- wakeups;
- startup time;
- GUI responsiveness;
- storage footprint;
- power use;
- application compatibility;
- maintenance burden.

The final UI must work well both:

- as a touchscreen phone interface;
- as a small desktop when HDMI and keyboard/mouse are attached.

Prefer one coherent adaptive/convergent system over separate unrelated
phone and desktop installations.

Wayland is the preferred native display architecture.

Ordinary X11 applications should remain usable through XWayland when
appropriate.

---

## No-junk policy

Avoid unnecessary:

- desktop metapackages;
- demo applications;
- games;
- duplicate GUI utilities;
- multiple network managers;
- multiple audio servers;
- redundant session/login infrastructure;
- indexers;
- telemetry;
- permanently running developer services;
- duplicate daemons solving the same problem;
- dependencies installed only for a tiny convenience feature.

Maintain a machine-readable production package manifest.

For every persistent daemon, be able to explain:

- why it exists;
- what starts it;
- approximate idle memory cost;
- wakeup behaviour;
- whether on-demand activation is possible.

Prefer event/socket/dbus activation where practical.

Do not damage package-manager integrity merely to remove files.

Development tools may exist in a development profile without becoming
production dependencies.

---

## Performance

Optimize for this specific hardware.

The device has severe CPU and RAM constraints by modern standards.

Profile instead of guessing.

Measure:

- PSS/RSS;
- CPU time;
- scheduler activity;
- wakeups;
- boot time;
- suspend current/power;
- storage I/O;
- graphical frame timing where useful.

Keep enough memory available for real applications.

Software rendering is acceptable during bring-up but is not an acceptable
final substitute for achievable Adreno hardware acceleration.

Power management is a release requirement.

A phone that works only while awake is incomplete.

---

## Device safety

Treat the physical phone as recoverable but valuable development hardware.

Before destructive work:

- identify the exact device;
- inspect the real partition layout;
- record partition sizes;
- record current bootloader/recovery state;
- establish a recovery route;
- create verified backups of critical accessible storage.

Never blindly overwrite or erase:

- TA;
- bootloader areas;
- partition tables;
- modem/baseband firmware;
- radio/NV data;
- calibration data;
- recovery;
- unknown partitions.

Development flashing tools must use an explicit partition whitelist.

A flashing script must verify:

- expected device;
- expected target;
- expected artifact;
- expected partition layout where practical.

Prefer early rootfs development on microSD.

Prefer modifying only the minimum boot-related storage needed during early
kernel bring-up.

Never commit private identifiers, credentials, keys, radio NV data, TA
contents or other unique secrets.

---

## Development methodology

Use an evidence-driven loop:

research
-> smallest justified change
-> build
-> deploy
-> boot
-> collect logs
-> test
-> classify result
-> repeat

Set up persistent diagnostics as early as possible.

Investigate:

- early console mechanisms;
- pstore/ramoops;
- persistent kernel logs;
- USB diagnostic access;
- physical UART if required.

After a failed boot, retrieve evidence before making speculative changes.

Do not change multiple unrelated subsystems between tests without a good
reason.

Keep commits small, meaningful and bisectable.

Preserve third-party patch authorship.

Use Conventional Commit style for project-owned commits unless a
subdirectory AGENTS.md specifies a more appropriate upstream convention.

---

## Hardware status

Maintain both human-readable and machine-readable status.

Required documentation should include:

- `docs/HARDWARE.md`
- `docs/HARDWARE_SCOPE.md`
- `docs/SOURCES.md`
- `docs/UPSTREAM.md`
- `docs/BOOT.md`
- `docs/PARTITIONS.md`
- `docs/STATUS.md`
- `docs/TESTING.md`
- `docs/PERFORMANCE.md`
- `docs/POWER.md`
- `docs/RECOVERY.md`

Maintain:

- `status/hardware.yaml`

For hardware claims use explicit evidence states such as:

- `VERIFIED_DEVICE`
- `VERIFIED_VENDOR_SOURCE`
- `VERIFIED_UPSTREAM`
- `HISTORICAL_SOURCE`
- `HYPOTHESIS`
- `UNKNOWN`

For implementation status use explicit states such as:

- `UNKNOWN`
- `RESEARCHING`
- `BLOCKED`
- `IMPLEMENTING`
- `BOOTS`
- `PROBES`
- `PARTIAL`
- `WORKING`
- `REGRESSION`
- `VERIFIED`

`VERIFIED` requires an actual acceptance test on the physical Xperia.

Examples:

- display: stable visible native-resolution output;
- touch: correct coordinates and multitouch;
- GPU: confirmed hardware renderer;
- Wi-Fi: association plus real traffic;
- Bluetooth: real pairing/function;
- NFC: real tag interaction;
- GNSS: real position fix;
- audio: actual playback/recording;
- camera: actual captured frames;
- modem: real registration and requested functionality;
- USB host: real attached peripheral;
- HDMI: real external display;
- suspend: repeated reliable suspend/resume;
- charging: observed real charge-state behaviour.

A driver probing is not `VERIFIED`.

---

## Repository as source of truth

Do not leave durable engineering knowledge only in chat/session history.

Record discoveries in the repository.

External sources must be recorded with enough provenance to find them again:

- repository or URL;
- commit/tag/version;
- retrieval date where useful;
- relevance;
- extracted information;
- confidence;
- license where relevant.

Changing upstream facts belong in documentation, not permanent assumptions
inside this file.

Do not continuously append research discoveries to `AGENTS.md`.

This root file contains stable project invariants.

Use nested `AGENTS.md` files for domain-specific instructions.

---

## Required research sources

Before reimplementing hardware support, investigate relevant work including:

- current upstream Linux;
- linux-next where useful;
- kernel lore and subsystem mailing lists;
- current Qualcomm MSM8x60 mainline work;
- current DRM/MSM and Mesa Freedreno;
- postmarketOS `sony-hikari`;
- historical Hikari mainline work;
- Sony Xperia open-source releases;
- stock LT26w firmware/kernel;
- Sony Fuji platform sources;
- Xperia S / Nozomi material where hardware is shared;
- FreeXperia;
- CyanogenMod/LineageOS MSM8x60 trees;
- OpenSEMC;
- nAOSP;
- historical GNU/Linux Xperia work;
- related successfully mainlined MSM8x60 devices.

Similar SoC does not mean identical board wiring.

Reuse shared SoC knowledge, not unrelated board assumptions.

---

## Agent autonomy

Take ownership of the engineering process.

Do not stop after producing suggestions or plans.

Do not stop merely because something compiled.

Do not ask the user for information that can reasonably be obtained by:

- probing the connected phone;
- reading the repository;
- inspecting source code;
- collecting logs;
- searching authoritative upstream sources;
- running a reversible test.

Ask the user when:

- physical manipulation is required;
- an irreversible or high-risk action needs approval;
- external hardware must be connected;
- a truly subjective decision cannot be resolved from project objectives.

When a test fails:

collect evidence
-> diagnose
-> patch
-> rebuild
-> retest

Continue through reasonable iterations.

Do not claim hardware success without a physical test.

---

## Build and CI

Automate repetitive development operations.

The project should eventually provide reproducible commands/scripts for:

- host setup;
- source retrieval;
- upstream patch retrieval;
- kernel configuration;
- kernel build;
- DTB build;
- initramfs build;
- rootfs generation;
- Sony boot artifact generation;
- development image generation;
- package generation;
- backup;
- restore;
- safe flash;
- log collection;
- hardware tests;
- release generation.

CI should verify what does not require the physical phone:

- clean builds;
- kernel configuration;
- DT schema validation;
- DTB validation;
- package/rootfs builds;
- reproducibility;
- static checks;
- manifests;
- release artifacts.

Do not represent CI as hardware validation.

Physical-device iteration should happen locally on the connected Xperia.

---

## Release definition

Do not call the project complete merely because it boots a shell or desktop.

A stable release requires, at minimum:

- reliable cold boot;
- maintained modern Linux kernel;
- usable current userspace;
- working internal display;
- working touchscreen;
- hardware-accelerated GPU;
- reliable storage;
- microSD;
- USB device mode;
- USB OTG host;
- Wi-Fi;
- Bluetooth;
- battery reporting;
- real charging;
- thermal management;
- audio;
- reliable suspend/resume;
- safe update mechanism;
- documented recovery;
- reproducible build.

All other original hardware capabilities remain required project scope and
must be driven to `VERIFIED`, or remain explicitly documented blockers
pending project-owner acceptance of an exception.

The final product should feel like an intentionally engineered tiny Linux
computer, not a generic desktop image copied onto an old Android phone.

Optimize aggressively.

Do not cripple functionality to make benchmark numbers look better.

Mainline what can be mainlined.

Reverse-engineer what must be reverse-engineered.

Measure instead of guessing.

Document what is learned.

Test on the physical device.
