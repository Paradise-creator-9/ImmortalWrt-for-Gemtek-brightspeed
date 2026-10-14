#!/bin/bash
set -eu
cd "$(dirname "$0")/../.."
fixture=$(mktemp -d "${TMPDIR:-/tmp}/gemtek-kernel-test.XXXXXX")
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/build/linux-6.18.55/tools/objtool" "$fixture/build/backports-1"
printf 'CONFIG_NET_AIROHA_NPU=y\nCONFIG_IPV6_TUNNEL=m\n' > "$fixture/build/linux-6.18.55/.config"
touch "$fixture/build/linux-6.18.55/Makefile"
printf '# CONFIG_NET_AIROHA_NPU is not set\n' > "$fixture/build/linux-6.18.55/tools/objtool/.config"
printf 'CONFIG_MAC80211=y\n' > "$fixture/build/backports-1/.config"
bash scripts/collect-gemtek-kernel-diagnostics.sh "$fixture/build" "$fixture/out" > "$fixture/log"
cp 1710-ubi15.config "$fixture/seed"
bash scripts/check-gemtek-profile-isolation.sh --config "$fixture/seed" --kernel-config "$fixture/out/kernel.config"
sed '/CONFIG_NET_AIROHA_NPU=y/d' "$fixture/out/kernel.config" > "$fixture/missing.config"
if bash scripts/check-gemtek-profile-isolation.sh --config "$fixture/seed" --kernel-config "$fixture/missing.config" >/dev/null 2>&1; then
 echo 'FAIL: accepted missing NPU'; exit 1
fi
mkdir -p "$fixture/build/linux-6.18.56"
touch "$fixture/build/linux-6.18.56/.config" "$fixture/build/linux-6.18.56/Makefile"
if bash scripts/collect-gemtek-kernel-diagnostics.sh "$fixture/build" "$fixture/ambiguous" >/dev/null 2>&1; then
 echo 'FAIL: accepted ambiguous kernel configs'; exit 1
fi
mkdir -p "$fixture/empty"
if bash scripts/collect-gemtek-kernel-diagnostics.sh "$fixture/empty" "$fixture/missing" >/dev/null 2>&1; then
 echo 'FAIL: accepted missing kernel config'; exit 1
fi
printf 'Kernel config selection: correct source, nested decoy ignored, missing NPU rejected, ambiguity and missing source rejected.\n'
