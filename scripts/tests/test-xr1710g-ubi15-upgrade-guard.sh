#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
fixture=$(mktemp -d "${TMPDIR:-/tmp}/gemtek-upgrade-test.XXXXXX")
trap 'rm -rf "$fixture"' EXIT HUP INT TERM
# Load only the platform functions, with mocked dependencies. No device access.
sed '\|^\. /lib/upgrade/gemtek-ubi.sh$|d' \
	target/linux/airoha/an7581/base-files/lib/upgrade/platform.sh > "$fixture/platform.sh"
. "$fixture/platform.sh"
board_name() { echo gemtek,xr1710g-ubi15; }
nand_do_upgrade() { touch "$fixture/write-called"; }
fit_do_upgrade() { touch "$fixture/write-called"; }
if platform_check_image unused-image; then
	echo 'Experimental image check unexpectedly allowed an upgrade' >&2
	exit 1
fi
if platform_do_upgrade unused-image; then
	echo 'Experimental write path unexpectedly allowed an upgrade' >&2
	exit 1
fi
[ ! -e "$fixture/write-called" ]
echo 'Experimental platform rejects image checks and writes without falling through to NAND.'
