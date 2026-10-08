# Debian SYSTEM

The target is Debian trixie `armhf` on the microSD filesystem labelled
`HIKARI_ROOT`. Debian supplies userspace and packages; the repository's
kernel patches, DT and exact matching modules remain the BSP.

The package manifest is [debian/packages.txt](../debian/packages.txt). Besides
the minimal system it includes SSH, NetworkManager/wpa_supplicant/iw, htop, tmux, nano,
strace, lsof, tcpdump, usbutils, i2c-tools, gpiod, evtest, rsync and curl.
Persistent services are limited to systemd/udev, NetworkManager, lightweight
systemd-timesyncd clock synchronization, Bluetooth and SSH.

Phosh uses the hardware GLES2 runtime. The event-driven `hikari-screen-sleep`
session helper requests logind suspend two seconds after screen blanking;
logind keeps responsibility for inhibitors and system sleep. It uses
python3-dbus/python3-gi and performs no periodic polling. On the fixed test
kernel, physical power-key sleep/wake reached CPU/RPM collapse; limitations
and evidence are in [POWER.md](POWER.md).
Root SSH and USB console access are intentionally retained by owner request.

## Wi-Fi and SSH

Configure credentials with NetworkManager on the device, never in git:

```sh
nmcli --ask device wifi connect superwhite_station ifname wlan0
nmcli connection show --active
```

NetworkManager stores the connection root-only, enables automatic association
and owns DHCP for both `wlan0` and the USB NCM development link. The repository
does not install a board-specific Wi-Fi management wrapper.

SSH listens on available network interfaces. During bring-up, `root` may log
in with an empty password; public-key authentication remains available. Install
a public key into the canonical rootfs before deployment:

```sh
scripts/provision-hikari-ssh-key.sh ~/.ssh/id_ed25519.pub
```

Empty-password root SSH is currently retained by explicit owner request. No Wi-Fi passphrase, private SSH key, device calibration
or identifier may be committed. BCM4330 firmware/calibration is locally materialized from the
owner's stock image with `scripts/materialize-hikari-bcm4330-firmware.sh`.

## Updates

BOOT receives complete SYSTEM kernel/module bundles over USB NCM. Use a full
rootfs stream only when packages or base configuration changed. Normal module
development and userspace work happen on SYSTEM; fastboot is reserved for
changes to the persistent BOOT environment.
