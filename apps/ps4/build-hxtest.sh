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

# the sources that hxcpp itself compiles on Linux (taken from a real Linux build with -verbose)
RUNTIME="src/Array.cpp src/Dynamic.cpp src/Enum.cpp src/Math.cpp src/String.cpp src/cpp/encoding/Encodings.cpp
 src/hx/Anon.cpp src/hx/Boot.cpp src/hx/CFFI.cpp src/hx/Class.cpp src/hx/Date.cpp src/hx/Debug.cpp src/hx/Hash.cpp src/hx/Lib.cpp
 src/hx/NoFiles.cpp src/hx/Object.cpp src/hx/StdLibs.cpp src/hx/Thread.cpp src/hx/gc/GcCommon.cpp src/hx/gc/GcRegCapture.cpp
 src/hx/gc/Immix.cpp src/hx/thread/ConditionVariable.cpp src/hx/thread/CountingSemaphore.posix.cpp src/hx/thread/RecursiveMutex.cpp
 src/hx/thread/Scratch.cpp src/hx/thread/ThreadImpl.cpp src/hx/thread/ThreadImpl.noop.cpp src/hx/thread/ThreadLocal.cpp"

: > "$WORK/jobs.txt"
n=0
for f in $(cd "$OUT" && find src -name '*.cpp' | sort); do n=$((n+1)); echo "$OUT/$f $INT/gen$n.o" >> "$WORK/jobs.txt"; done
for f in $RUNTIME; do n=$((n+1)); echo "$H/$f $INT/rt$n.o" >> "$WORK/jobs.txt"; done

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
