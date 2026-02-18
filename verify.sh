#!/usr/bin/env bash
#
# Compare Java (reference), custom JavaRandom (C#), and IKVM. Diff JavaRandom and IKVM against Java. Time all 3 with bash time.
#   java.txt : Native Java (java.util.Random)
#   cs_java_random.txt : Custom C# JavaRandom
#   ikvm.txt : IKVM (java.util.Random via bridge)
#
# Usage: ./verify.sh [seed] [count]
#

set -e

# If the parent shell exported a `dotnet` function (e.g. adds -nologo),
# bash will inherit it and it can break argument parsing. Always use the real binary.
unset -f dotnet 2>/dev/null || true

SEED="${1:-12345}"
COUNT="${2:-100}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ -d "$PWD/bin/Release/net10.0/ikvm/linux-x64/bin" ]; then
    export LD_LIBRARY_PATH="$PWD/bin/Release/net10.0/ikvm/linux-x64/bin:$LD_LIBRARY_PATH"
fi

echo "=== Building ==="
javac TestRNG.java
command dotnet build TestRNG.csproj -c Release

echo ""
echo "=== Running (seed=$SEED, count=$COUNT) — timed with bash time ==="

echo "--- Java (reference) -> java.txt ---"
time java TestRNG "$SEED" "$COUNT"

echo ""
echo "--- JavaRandom (C#) -> cs_java_random.txt ---"
time command dotnet run --project TestRNG.csproj -c Release --no-build -- "$SEED" "$COUNT" javarandom

echo ""
echo "--- IKVM -> ikvm.txt ---"
time command dotnet run --project TestRNG.csproj -c Release --no-build -- "$SEED" "$COUNT" ikvm 2>/dev/null || true

# Compare two files; treat 16-char hex (double bits) as equal if within 1 ULP (Java vs C#/IKVM log/sqrt can differ by 1 ULP).
cmp_with_ulp() {
    local ref="$1" other="$2" name="$3"
    if [ ! -f "$other" ] || [ ! -s "$other" ]; then
        echo "FAIL: $other missing or empty"
        return 1
    fi
    local ref_lines other_lines
    ref_lines=$(wc -l < "$ref")
    other_lines=$(wc -l < "$other")
    if [[ $ref_lines -ne $other_lines ]]; then
        echo "FAIL: line count mismatch (Java $ref_lines, $name $other_lines)"
        return 1
    fi
    local line=0 fail=0
    while IFS= read -r r <&3 && IFS= read -r o <&4; do
        (( line++ )) || true
        if [[ "$r" == "$o" ]]; then
            continue
        fi
        if [[ "$r" =~ ^[0-9a-f]{16}$ && "$o" =~ ^[0-9a-f]{16}$ ]]; then
            local v1 v2 diff
            v1=$(printf '%d' "0x$r")
            v2=$(printf '%d' "0x$o")
            diff=$(( v1 - v2 ))
            [[ $diff -lt 0 ]] && diff=$((-diff))
            if [[ $diff -le 1 ]]; then
                continue
            fi
        fi
        echo "First difference at line $line: ref='$r' $name='$o'"
        fail=1
        break
    done 3<"$ref" 4<"$other"
    if [[ $fail -eq 0 ]]; then
        echo "PASS: $name matches Java (within 1 ULP for doubles)"
    fi
    return $fail
}

echo ""
echo "=== Diff: Java vs JavaRandom (C#) ==="
cmp_with_ulp java.txt cs_java_random.txt "JavaRandom" || echo "FAIL: JavaRandom differs from Java"

echo ""
echo "=== Diff: Java vs IKVM ==="
if [ ! -f ikvm.txt ] || [ ! -s ikvm.txt ]; then
    echo "NOTE: ikvm.txt missing or empty (IKVM may have crashed, e.g. libiava.so on Linux)."
else
    cmp_with_ulp java.txt ikvm.txt "IKVM" || echo "FAIL: IKVM differs from Java"
fi

echo ""
echo "=== Summary ==="
echo "java.txt:           $(wc -l < java.txt 2>/dev/null || echo 0) lines"
echo "cs_java_random.txt: $(wc -l < cs_java_random.txt 2>/dev/null || echo 0) lines"
echo "ikvm.txt:           $(wc -l < ikvm.txt 2>/dev/null || echo 0) lines"
