#!/usr/bin/env bash
# Puts the built-in mods next to the game: downloads them from the "CLAUDE" release of this repository and publishes their files in
# <site>/builtin/ with an index (see source/echo/EchoBuiltin.hx). usage: add_builtin.sh <site dir>
set -uo pipefail
site=$1
tmp=$(mktemp -d)

if gh release download CLAUDE --repo "$GITHUB_REPOSITORY" --pattern 'pico_mix_psych_port.zip' --dir "$tmp" && [ -s "$tmp/pico_mix_psych_port.zip" ]; then
	mkdir -p "$site/builtin"
	unzip -q "$tmp/pico_mix_psych_port.zip" -d "$site/builtin"
	rm -rf "$site/builtin/__MACOSX"
	python3 "$(dirname "$0")/make_builtin_index.py" "$site/builtin"
	if [ -n "$(find "$site/builtin" -type f -size +95M)" ]; then echo "A built-in file is too big for GitHub Pages"; exit 1; fi
	du -sh "$site/builtin"
else
	echo "::warning title=Built-in mods::Could not download pico_mix_psych_port.zip from the CLAUDE release: the game is published without Pico Mix."
fi
exit 0
