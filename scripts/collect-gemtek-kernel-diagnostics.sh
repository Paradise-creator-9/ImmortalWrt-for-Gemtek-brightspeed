#!/usr/bin/env bash
set -Eeuo pipefail

build_root=${1:-build_dir/target-aarch64_cortex-a53_musl/linux-airoha_an7581}
output=${2:-diagnostics}
mkdir -p "$output"
[[ ! -f .config ]] || cp .config "$output/openwrt.config"

# A recursive */linux-*/.config also matches configs in tools and backports
# because linux-airoha_an7581 is already an ancestor. Only accept the kernel
# source directory itself, and fail if selection is ambiguous.
configs=()
for dir in "$build_root"/linux-[0-9]*; do
	[[ -f "$dir/Makefile" && -f "$dir/.config" ]] || continue
	configs+=("$dir/.config")
done
printf '%s\n' "${configs[@]+"${configs[@]}"}" > "$output/kernel-config-paths.txt"
[[ ${#configs[@]} == 1 ]] || {
	echo "Expected exactly one final Linux kernel config; found ${#configs[@]}" >&2
	exit 1
}
kernel_dir=${configs[0]%/.config}
cp "$kernel_dir/.config" "$output/kernel.config"
for file in .config.target .config.override .config.set .config.prev; do
	[[ ! -f "$kernel_dir/$file" ]] || cp "$kernel_dir/$file" "$output/kernel${file}"
done
for file in drivers/net/ethernet/airoha/Kconfig modules.builtin; do
	[[ ! -f "$kernel_dir/$file" ]] || cp "$kernel_dir/$file" "$output/$(basename "$file")"
done
for file in "$build_root"/image-an7581*1710*.dtb; do
	[[ ! -f "$file" ]] || cp "$file" "$output/"
done
{
	printf 'Final kernel config: %s\n' "${configs[0]}"
	for file in "$output"/kernel.config*; do
		printf '\n%s\n' "$file"
		grep -E '(^|CONFIG_)(ARCH_AIROHA|NET_VENDOR_AIROHA|NET_AIROHA|NET_AIROHA_NPU|NET_DSA|IPV6|IPV6_TUNNEL|AIROHA_PON_COMPAT|PTP_1588_CLOCK_AIROHA_TOD)(=| )' "$file" || true
	done
} | tee "$output/kernel-summary.txt"
