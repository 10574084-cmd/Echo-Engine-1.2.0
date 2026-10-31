#!/usr/bin/env bash
# Builds apps/ps4/hxtest (Haxe -> C++ with hxcpp) for the PS4 with the OpenOrbis clang, and links it into eboot.bin objects.
# Needs: OO_PS4_TOOLCHAIN, haxe + hxcpp (haxelib), clang, lld. Output: $1/hello_world/x64/Debug/*.o (ready for the sample's Makefile).
set -euo pipefail
WORK=$1                       # the copy of the OpenOrbis hello_world sample
TC=$OO_PS4_TOOLCHAIN
HERE=$(cd "$(dirname "$0")" && pwd)
H=$(haxelib libpath hxcpp)
OUT=$WORK/hx
INT=$WORK/hello_world/x64/Debug
mkdir -p "$INT"

rm -rf "$OUT"
( cd "$HERE/hxtest" && haxe -cp . -cpp "$OUT" -main Main -D HXCPP_M64 -D no-compilation )
cp "$HERE/hxtest/ps4glue.h" "$OUT/include/"

# The runtime sources hxcpp compiles on Linux: take the list from a real Linux build of the same program (-verbose prints every
# compiler call). Only the compiling matters here, the Linux link may fail (it lacks the PS4 notification function).
( cd "$OUT" && haxelib run hxcpp Build.xml -verbose -DHXCPP_M64 > "$WORK/linux-build.log" 2>&1 || true )
sed 's/\x1b\[[0-9;]*m//g' "$WORK/linux-build.log" | grep "Running command: g++" | grep -o "[^ ]*\.cpp" | grep -v "^\./src/" | sort -u > "$WORK/runtime.txt"
echo "hxcpp runtime sources: $(wc -l < "$WORK/runtime.txt")"
test "$(wc -l < "$WORK/runtime.txt")" -gt 15
RUNTIME=$(cat "$WORK/runtime.txt")
rm -rf "$OUT/obj"

: > "$WORK/jobs.txt"
n=0
for f in $(cd "$OUT" && find src -name '*.cpp' ! -name '__files__.cpp' ! -name '__lib__.cpp' | sort); do n=$((n+1)); echo "$OUT/$f $INT/gen$n.o" >> "$WORK/jobs.txt"; done
for f in $RUNTIME; do n=$((n+1)); echo "$f $INT/rt$n.o" >> "$WORK/jobs.txt"; done

FLAGS="--target=x86_64-pc-freebsd12-elf -fPIC -funwind-tables -c -O2 -w -std=c++11 -frtti -fexceptions -fcxx-exceptions \
 -isysroot $TC -isystem $TC/include -isystem $TC/include/c++/v1 -I$OUT/include -I$H/include \
 -D_GNU_SOURCE -DHX_LINUX -DHXCPP_M64 -DHXCPP_VISIT_ALLOCS -DHX_SMART_STRINGS -DHXCPP_API_LEVEL=430 -Wno-invalid-offsetof"
export FLAGS
set +e
cat "$WORK/jobs.txt" | xargs -P 4 -L 1 sh -c 'clang++ $FLAGS -x c++ "$0" -o "$1" 2>&1 || { echo "FAILED: $0"; exit 255; }' > "$WORK/compile.log" 2>&1
status=$?
set -e
if [ $status -ne 0 ]; then
	grep -E "error:|FAILED" "$WORK/compile.log" | head -40
	exit 1
fi
echo "compiled $n files"
