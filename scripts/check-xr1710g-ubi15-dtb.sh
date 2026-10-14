#!/usr/bin/env bash
set -Eeuo pipefail

dtb=${1:?usage: check-xr1710g-ubi15-dtb.sh <compiled.dtb>}
[[ -s "$dtb" ]] || { echo "Missing compiled UBI 1.5 device tree" >&2; exit 1; }
command -v fdtget >/dev/null
partitions=/soc/spi@1fa10000/nand@0/partitions
ubi=$partitions/partition@700000
factory=$ubi/volumes/ubi-volume-factory

expect() {
	local actual="$1" expected="$2" description="$3"
	[[ "$actual" == "$expected" ]] || {
		printf '%s: expected [%s], got [%s]\n' "$description" "$expected" "$actual" >&2
		exit 1
	}
}
get() { fdtget -t "$1" "$dtb" "$2" "$3"; }

expect "$(get s / compatible)" 'gemtek,xr1710g-ubi15 airoha,an7581 airoha,en7581' 'Board identity'
expect "$(fdtget -l "$dtb" "$partitions" | LC_ALL=C sort)" \
	"$(printf '%s\n' partition@0 partition@600000 partition@700000 reserved_bmt@1e0c0000 | LC_ALL=C sort)" 'Partition set'
for entry in 'partition@0:0 600000:vendor' 'partition@600000:600000 100000:chainloader' \
	'partition@700000:700000 1d9c0000:ubi' 'reserved_bmt@1e0c0000:1e0c0000 1f40000:reserved_bmt'; do
	IFS=: read -r node reg label <<< "$entry"
	expect "$(get x "$partitions/$node" reg)" "$reg" "$label range"
	expect "$(get s "$partitions/$node" label)" "$label" "$node label"
	if [[ "$label" != ubi ]]; then
		fdtget -p "$dtb" "$partitions/$node" | grep -Fqx read-only
	fi
done
expect "$(get x "$factory/nvmem-layout/eeprom@0" reg)" '0 1e00' 'Legacy EEPROM range'
expect "$(get x "$factory/nvmem-layout/macaddr@5000" reg)" '5000 6' 'Legacy WAN MAC range'
expect "$(get x "$factory/nvmem-layout/macaddr@6000" reg)" '6000 6' 'Legacy LAN MAC range'
expect "$(get x /chosen rootdisk)" "$(get x "$ubi/volumes/ubi-volume-fit" phandle)" 'FIT rootdisk reference'
expect "$(get s "$ubi/volumes/ubi-volume-fit" volname)" fit 'Boot volume'
expect "$(get s /soc/npu@1e900000 status)" okay 'NPU device status'
echo 'Compiled XR1710G UBI 1.5 layout check passed (does not authorize flashing).'
