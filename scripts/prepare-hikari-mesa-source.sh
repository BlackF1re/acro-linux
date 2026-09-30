#!/usr/bin/env bash
# Apply the required upstream A2xx fixes to a Debian Mesa 25.0.7 source tree.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
mesa_tree=${1:?usage: prepare-hikari-mesa-source.sh MESA_SOURCE_TREE}
program_file=$mesa_tree/src/gallium/drivers/freedreno/a2xx/fd2_program.c
emit_file=$mesa_tree/src/gallium/drivers/freedreno/a2xx/fd2_emit.c
patch_dir=$repo_root/distro/mesa/patches

test -f "$mesa_tree/meson.build" || { echo "not a Mesa source tree: $mesa_tree" >&2; exit 1; }
test -f "$program_file" && test -f "$emit_file" || {
	echo "Mesa tree has no Freedreno A2xx backend" >&2
	exit 1
}

for patch_file in "$patch_dir"/*.patch; do
	if patch --directory="$mesa_tree" --strip=1 --forward --dry-run --silent < "$patch_file"; then
		patch --directory="$mesa_tree" --strip=1 --forward < "$patch_file"
	elif patch --directory="$mesa_tree" --strip=1 --reverse --dry-run --silent < "$patch_file"; then
		printf 'Already applied: %s\n' "$(basename "$patch_file")"
	else
		echo "Mesa tree is incompatible with $(basename "$patch_file")" >&2
		exit 1
	fi
done

grep -Fq 'ir2_glsl_type_size, 0);' "$program_file"
grep -Fq 'xy2d(scissor->maxx + 1,' "$emit_file"
printf 'Hikari Mesa A2xx fix series applied in %s\n' "$mesa_tree"
