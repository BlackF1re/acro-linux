#!/usr/bin/env bash
# Package the Hikari Mesa/Freedreno build as an ordinary Debian upgrade.
set -euo pipefail

build_dir=${1:?usage: package-hikari-mesa.sh MESA_BUILD_DIR OUTPUT_DIR ROOTFS}
output_dir=${2:?usage: package-hikari-mesa.sh MESA_BUILD_DIR OUTPUT_DIR ROOTFS}
rootfs=${3:?usage: package-hikari-mesa.sh MESA_BUILD_DIR OUTPUT_DIR ROOTFS}
base_version=25.0.7-2+deb13u1
package_version=${base_version}+hikari6
library=libgallium-${base_version}.so
source_library=$build_dir/src/gallium/targets/dri/$library

test -f "$source_library" || {
	echo "missing Mesa Gallium library: $source_library" >&2
	exit 1
}

soname=$(readelf -d "$source_library" | sed -n 's/.*Library soname: \[\(.*\)\]/\1/p')
test "$soname" = "$library" || {
	echo "unexpected Gallium SONAME: ${soname:-none}" >&2
	exit 1
}

# Debian's libEGL_mesa is built for both X11 and Wayland and imports this
# DRI3 loader entry point from its private, version-locked Gallium library.
# Refuse a narrower build: it loads successfully but leaves GLVND without an
# EGL vendor, which is otherwise reported only as a missing platform extension.
readelf -Ws "$source_library" |
	grep 'loader_dri3_get_buffers@@libgallium-' >/dev/null || {
	echo "Gallium library is not ABI-compatible with Debian libEGL_mesa" >&2
	exit 1
}

stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
install -Dm755 "$source_library" \
	"$stage/usr/lib/arm-linux-gnueabihf/$library"
/usr/bin/llvm-strip --strip-unneeded \
	"$stage/usr/lib/arm-linux-gnueabihf/$library"
install -d "$stage/DEBIAN" "$stage/usr/share/doc/mesa-libgallium"

cat >"$stage/DEBIAN/control" <<EOF
Package: mesa-libgallium
Version: $package_version
Architecture: armhf
Maintainer: Hikari Linux Project <noreply@invalid>
Depends: libc6 (>= 2.38), libdrm2 (>= 2.4.121), libexpat1 (>= 2.0.1), libgcc-s1 (>= 3.5), libstdc++6 (>= 11), libxcb1, libxcb-dri3-0, libxcb-present0, libxcb-randr0, libxcb-sync1, libxcb-xfixes0, libxshmfence1, libzstd1 (>= 1.5.5), zlib1g (>= 1:1.2.3.4)
Section: libs
Priority: optional
Description: Mesa Gallium library for Sony Xperia acro S (Hikari)
 Device-specific rebuild of Debian Mesa with Freedreno and softpipe. It carries
 the required upstream A2xx fixes while retaining Debian's private Gallium ABI
 and its X11/Wayland loader interface.
EOF

cat >"$stage/usr/share/doc/mesa-libgallium/changelog.Debian" <<EOF
mesa ($package_version) trixie; urgency=medium

  * Backport upstream Freedreno A2xx shader-input fix 5a3300f4a34a.
  * Backport upstream Freedreno A2xx window-scissor fix 34b78fb26b9b.
  * Backport six additional upstream A2xx correctness fixes for fragment
    coordinates, source swizzles, packed varyings, immediates and textures.
  * Fix A2xx fragment linkage indexing when varying order differs from its
    assigned driver locations.
  * Build Gallium with Freedreno and softpipe for the Hikari system image.
  * Preserve Debian's X11 and Wayland Gallium loader ABI.

 -- Hikari Linux Project <noreply@invalid>  Thu, 24 Sep 2026 00:00:00 +0700
EOF
gzip -n -9 "$stage/usr/share/doc/mesa-libgallium/changelog.Debian"

(
	cd "$stage"
	find usr -type f -print0 | sort -z | xargs -0 md5sum >DEBIAN/md5sums
)

mkdir -p "$output_dir"
artifact=$output_dir/mesa-libgallium_${package_version}_armhf.deb
SOURCE_DATE_EPOCH=1790182800 dpkg-deb --root-owner-group -Zxz --build "$stage" "$artifact"
dpkg-deb --info "$artifact"

# Debian's EGL, GBM and GLX packages deliberately depend on exactly the same
# mesa-libgallium version.  Publish a coherent local rebuild set instead of
# leaving dpkg with unsatisfied exact-version dependencies.  Their binaries do
# not change; only their package version and intra-Mesa dependencies do.
for companion in libegl-mesa0 libgbm1 libgl1-mesa-dri libglx-mesa0; do
	stock_deb=/tmp/${companion}_${base_version}_armhf.deb
	sudo rm -f "$rootfs$stock_deb"
	sudo chroot "$rootfs" sh -c \
		"cd /tmp && apt-get download '${companion}=${base_version}'"
	test -f "$rootfs$stock_deb" || {
		echo "failed to download $companion $base_version for armhf" >&2
		exit 1
	}

	companion_stage=$stage/$companion
	mkdir -p "$companion_stage"
	sudo dpkg-deb -R "$rootfs$stock_deb" "$companion_stage"
	sudo chown -R "$(id -u):$(id -g)" "$companion_stage"
	sed -i \
		-e "s/^Version: ${base_version}$/Version: ${package_version}/" \
		-e "s/= ${base_version})/= ${package_version})/g" \
		"$companion_stage/DEBIAN/control"
	grep -Fxq "Version: $package_version" "$companion_stage/DEBIAN/control"
	grep -Fq "(= $package_version)" "$companion_stage/DEBIAN/control"
	if grep -Fq "(= $base_version)" "$companion_stage/DEBIAN/control"; then
		echo "unconverted intra-Mesa dependency in $companion" >&2
		exit 1
	fi
	companion_artifact=$output_dir/${companion}_${package_version}_armhf.deb
	SOURCE_DATE_EPOCH=1790182800 dpkg-deb --root-owner-group -Zxz \
		--build "$companion_stage" "$companion_artifact"
	sudo rm -f "$rootfs$stock_deb"
done

printf '%s\n' \
	"$artifact" \
	"$output_dir/libegl-mesa0_${package_version}_armhf.deb" \
	"$output_dir/libgbm1_${package_version}_armhf.deb" \
	"$output_dir/libgl1-mesa-dri_${package_version}_armhf.deb" \
	"$output_dir/libglx-mesa0_${package_version}_armhf.deb"
