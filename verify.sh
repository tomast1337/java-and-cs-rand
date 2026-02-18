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

SEED="${1:-12345}"
COUNT="${2:-100}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ -d "$PWD/bin/Release/net10.0/ikvm/linux-x64/bin" ]; then
    export LD_LIBRARY_PATH="$PWD/bin/Release/net10.0/ikvm/linux-x64/bin:$LD_LIBRARY_PATH"
fi

echo "=== Building ==="
javac TestRNG.java
dotnet build TestRNG.csproj -c Release

echo ""
echo "=== Running (seed=$SEED, count=$COUNT) — timed with bash time ==="

echo "--- Java (reference) -> java.txt ---"
time java TestRNG "$SEED" "$COUNT"

echo ""
echo "--- JavaRandom (C#) -> cs_java_random.txt ---"
time dotnet run --project TestRNG.csproj -c Release --no-build -- "$SEED" "$COUNT" javarandom

echo ""
echo "--- IKVM -> ikvm.txt ---"
time dotnet run --project TestRNG.csproj -c Release --no-build -- "$SEED" "$COUNT" ikvm 2>/dev/null || true

echo ""
echo "=== Diff: Java vs JavaRandom (C#) ==="
if [ ! -f cs_java_random.txt ] || [ ! -s cs_java_random.txt ]; then
    echo "FAIL: cs_java_random.txt missing or empty"
else
    if diff -u java.txt cs_java_random.txt; then
        echo "PASS: JavaRandom matches Java"
    else
        echo "FAIL: JavaRandom differs from Java"
    fi
fi

echo ""
echo "=== Diff: Java vs IKVM ==="
if [ ! -f ikvm.txt ] || [ ! -s ikvm.txt ]; then
    echo "NOTE: ikvm.txt missing or empty (IKVM may have crashed, e.g. libiava.so on Linux)."
else
    if diff -u java.txt ikvm.txt; then
        echo "PASS: IKVM matches Java"
    else
        echo "FAIL: IKVM differs from Java"
    fi
fi

echo ""
echo "=== Summary ==="
echo "java.txt:           $(wc -l < java.txt 2>/dev/null || echo 0) lines"
echo "cs_java_random.txt: $(wc -l < cs_java_random.txt 2>/dev/null || echo 0) lines"
echo "ikvm.txt:           $(wc -l < ikvm.txt 2>/dev/null || echo 0) lines"
