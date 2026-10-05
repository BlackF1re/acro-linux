#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

fail()
{
	echo "ERROR: $*" >&2
	exit 1
}

mode=usb
auto_reboot=false

while [[ $# -gt 0 ]]; do
	case $1 in
	--reboot)
		auto_reboot=true
		shift
		;;
	--xmodem)
		mode=xmodem
		shift
		;;
	--)
		shift
		break
		;;
	-*)
		fail "unknown option: $1"
		;;
	*)
		break
		;;
	esac
done

tty=${1:-/dev/ttyACM0}
archive=${2:-/home/paul/xperia/build/hikari-debian-current/hikari-system-update.tar}

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
acm="$script_dir/hikari-acm-command.py"

test -c "$tty" || fail "not a tty: $tty"
test -s "$archive" || fail "missing archive: $archive"
test -x "$acm" || fail "missing ACM helper: $acm"

exec 9>/tmp/hikari-system-update.lock
flock -n 9 || fail "another SYSTEM update is running"

work=$(mktemp -d /tmp/hikari-system-update.XXXXXX)
rxpid=
verifypid=

cleanup()
{
	for pid in "${rxpid:-}" "${verifypid:-}"; do
		[[ -n $pid ]] || continue
		kill "$pid" 2>/dev/null || true
		wait "$pid" 2>/dev/null || true
	done
	rm -rf "$work"
}
trap cleanup EXIT

snapshot="$work/update.tar"
cp -- "$archive" "$snapshot"

printf '[1/4] Checking bundle... '

expected_members=$'zImage\nqcom-msm8260-sony-hikari.dtb\nhikari-root.cpio.gz\nkernel-release\nmodules.tar.gz\nSHA256SUMS'
actual_members=$(tar -tf "$snapshot")

[[ $actual_members == "$expected_members" ]] ||
	fail "unexpected archive contents"

tar -xf "$snapshot" -C "$work"

(
	cd "$work"
	sha256sum -c SHA256SUMS >/dev/null
) || fail "local checksum verification failed"

release=$(<"$work/kernel-release")

[[ -n $release ]] || fail "empty kernel-release"
[[ $release != *[!A-Za-z0-9._+-]* ]] ||
	fail "unsafe kernel-release: $release"

module_list="$work/modules.list"
tar -tzf "$work/modules.tar.gz" >"$module_list"

module_root="lib/modules/$release/"

grep -Fx "$module_root" "$module_list" >/dev/null ||
	fail "module archive does not contain $module_root"

while IFS= read -r member; do
	[[ $member == "$module_root"* ]] ||
		fail "foreign path in module archive: $member"
done <"$module_list"

manifest_sha=$(sha256sum "$work/SHA256SUMS" | awk '{print $1}')
archive_sha=$(sha256sum "$snapshot" | awk '{print $1}')

echo "OK"

# Never ask for a sudo password.
# Use direct access where possible, otherwise sudo -n only.
if [[ -r $tty && -w $tty ]]; then
	ACM=("$acm")
else
	ACM=(sudo -n "$acm")
fi

wait_for_marker()
{
	local log=$1
	local marker=$2
	local pid=$3
	local seconds=$4
	local deadline=$((SECONDS + seconds))

	while (( SECONDS < deadline )); do
		if grep -F "$marker" "$log" >/dev/null 2>&1; then
			return 0
		fi

		if ! kill -0 "$pid" 2>/dev/null; then
			# Check once more in case the marker was the final output.
			grep -F "$marker" "$log" >/dev/null 2>&1 && return 0
			return 1
		fi

		sleep 0.1
	done

	return 1
}

if [[ $mode == usb ]]; then
	iface=$(
		ip -o link |
		awk '
			/link\/ether 02:86:60:00:00:01/ {
				sub(/:$/, "", $2)
				print $2
			}
		' |
		head -n 1
	)

	[[ -n $iface ]] ||
		fail "Hikari NCM interface not found"

	if ! ip link show "$iface" | grep -E '<[^>]*UP[,>]' >/dev/null; then
		sudo -n ip link set "$iface" up ||
			fail "cannot bring up $iface without interactive sudo"
	fi

	if ! ip -4 addr show dev "$iface" |
	     grep -F '192.168.77.1/30' >/dev/null; then
		sudo -n ip address replace 192.168.77.1/30 dev "$iface" ||
			fail "cannot configure $iface without interactive sudo"
	fi

	rxlog="$work/receiver.log"
	: >"$rxlog"

	printf '[2/4] Starting BOOT receiver... '

	"${ACM[@]}" \
		--device "$tty" \
		--timeout 300 \
		hikari-receive-system usb \
		>"$rxlog" 2>&1 &
	rxpid=$!

	if ! wait_for_marker \
		"$rxlog" \
		'USB network receiver ready on 192.168.77.2:7777.' \
		"$rxpid" \
		20
	then
		cat "$rxlog" >&2
		fail "BOOT receiver did not become ready"
	fi

	echo "OK"

	# Give nc -l a moment to enter listen() after printing READY.
	sleep 0.5

	printf '[3/4] Sending and installing... '

	set +e
	timeout 200 nc -N 192.168.77.2 7777 <"$snapshot"
	nc_rc=$?
	set -e

		if ! wait_for_marker \
		"$rxlog" \
		'SYSTEM update installed and checksum-verified.' \
		"$rxpid" \
		180
	then
		echo
		echo "===== BOOT RECEIVER LOG =====" >&2
		cat "$rxlog" >&2
		fail "BOOT did not confirm installation"
	fi

	echo "OK"

	kill "$rxpid" 2>/dev/null || true
	wait "$rxpid" 2>/dev/null || true
	rxpid=

else
	fail "XMODEM path intentionally disabled in reliable sender; use USB"
fi

nonce="$(date +%s)-$$-$RANDOM"
marker="HIKARI_POSTVERIFY_OK_$nonce"

verify_cmd="set -eu; \
/usr/sbin/hikari-mount-system; \
boot=/system/boot/hikari-next; \
actual=\$(cat \"\$boot/kernel-release\"); \
[ \"\$actual\" = \"$release\" ] || { \
	echo \"EXPECTED=$release\"; \
	echo \"ACTUAL=\$actual\"; \
	exit 1; \
}; \
[ -d \"/system/lib/modules/$release\" ] || { \
	echo \"MISSING_MODULES=/system/lib/modules/$release\"; \
	exit 1; \
}; \
actual_manifest=\$(sha256sum \"\$boot/SHA256SUMS\" | awk '{print \$1}'); \
[ \"\$actual_manifest\" = \"$manifest_sha\" ] || { \
	echo \"MANIFEST_MISMATCH\"; \
	exit 1; \
}; \
cd \"\$boot\"; \
sha256sum -c SHA256SUMS >/dev/null; \
printf 'HIKARI_POSTVERIFY_OK_%s\\n' '$nonce'"

verifylog="$work/postverify.log"
: >"$verifylog"

printf '[4/4] Verifying installed bundle... '

"${ACM[@]}" \
	--device "$tty" \
	--no-interrupt \
	--timeout 180 \
	"$verify_cmd" \
	>"$verifylog" 2>&1 &
verifypid=$!

if ! wait_for_marker \
	"$verifylog" \
	"$marker" \
	"$verifypid" \
	120
then
	echo
	echo "===== POST-VERIFY LOG =====" >&2
	cat "$verifylog" >&2
	fail "installed SYSTEM bundle failed post-verification"
fi

echo "OK"

kill "$verifypid" 2>/dev/null || true
wait "$verifypid" 2>/dev/null || true
verifypid=

echo "Release: $release"

if [[ $auto_reboot == true ]]; then
	echo "Starting SYSTEM..."

	"${ACM[@]}" \
		--device "$tty" \
		--no-interrupt \
		--no-read \
		/usr/sbin/hikari-system >/dev/null 2>&1 ||
		fail "failed to start SYSTEM"
fi

echo "READY!"
