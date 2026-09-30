#!/system/bin/sh

# Capture Hikari's vendor-kernel power routing while USB debugging is absent.
# Output intentionally lives in /data/local/tmp so it survives cable changes.

out=/data/local/tmp/hikari-power-monitor.log
samples=${1:-600}

read_value()
{
	if [ -r "$1" ]; then
		tr '\n' ' ' < "$1"
	else
		printf -- '- '
	fi
}

printf 'BEGIN epoch=%s samples=%s\n' "$(date +%s)" "$samples" > "$out"
dmesg >> "$out"
printf '\nSAMPLES\n' >> "$out"

i=0
while [ "$i" -lt "$samples" ]; do
	printf 'S epoch=%s usb=' "$(date +%s)" >> "$out"
	read_value /sys/class/power_supply/hsusb_chg/online >> "$out"
	printf 'cradle=' >> "$out"
	read_value /sys/class/power_supply/semc_chg_cradle/online >> "$out"
	printf 'ac=' >> "$out"
	read_value /sys/class/power_supply/ac/online >> "$out"
	printf 'status=' >> "$out"
	read_value /sys/class/power_supply/bq24160/status >> "$out"
	printf 'uV=' >> "$out"
	read_value /sys/class/power_supply/bq27520/voltage_now >> "$out"
	printf 'uA=' >> "$out"
	read_value /sys/class/power_supply/bq27520/current_now >> "$out"
	printf 'cap=' >> "$out"
	read_value /sys/class/power_supply/bq27520/capacity >> "$out"
	printf 'usb_state=' >> "$out"
	read_value /sys/devices/platform/msm_hsusb/gadget/usb_state >> "$out"
	printf 'chg_type=' >> "$out"
	read_value /sys/devices/platform/msm_hsusb/gadget/chg_type >> "$out"
	printf 'chg_mA=' >> "$out"
	read_value /sys/devices/platform/msm_hsusb/gadget/chg_current >> "$out"
	printf 'is_otg=' >> "$out"
	read_value /sys/devices/platform/msm_hsusb/udc/msm_hsusb/is_otg >> "$out"
	printf '\n' >> "$out"

	# These four lines expose the two-stage host VBUS switch and cradle detect.
	grep -E 'gpio-(28|104|126|225) ' /sys/kernel/debug/gpio \
		| tr '\n' ';' >> "$out"
	printf '\n' >> "$out"

	# A newly enumerated host peripheral appears here even if userspace ignores it.
	for d in /sys/bus/usb/devices/*; do
		[ -r "$d/idVendor" ] || continue
		printf 'U epoch=%s path=%s vid=' "$(date +%s)" "$d" >> "$out"
		read_value "$d/idVendor" >> "$out"
		printf 'pid=' >> "$out"
		read_value "$d/idProduct" >> "$out"
		printf 'product=' >> "$out"
		read_value "$d/product" >> "$out"
		printf '\n' >> "$out"
	done

	i=$((i + 1))
	sleep 1
done

printf '\nEND epoch=%s\n' "$(date +%s)" >> "$out"
dmesg >> "$out"
