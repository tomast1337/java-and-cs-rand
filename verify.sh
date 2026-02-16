#!/usr/bin/env bash
#
# Verification script for three-way RNG comparison:
#   - Native Java (java.util.Random)
#   - Native C# (System.Random)
#   - Custom C# (JavaRandom - 48-bit LCG port)
#   - IKVM Java (java.util.Random via IKVM bridge)
#
# Compiles both projects, runs all versions with the same seed, and outputs diffs.
# Key comparison: Java output vs Custom C# and vs IKVM Java (both should match).
#

set -e

SEED="${1:-12345}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Building ==="

# Compile Java
echo "Compiling Java..."
javac TestRNG.java

# Compile C# (pulls IKVM via NuGet)
echo "Compiling C#..."
dotnet build TestRNG.csproj -c Release

echo ""
echo "=== Running (seed=$SEED) ==="

# Run Java and capture output
echo "Running Java..."
java TestRNG "$SEED" > java_out.txt

# Run C# and capture full output (LD_LIBRARY_PATH needed for IKVM native libs on Linux)
echo "Running C# (Native + Custom + IKVM)..."
IKVM_BIN="$SCRIPT_DIR/bin/Release/net10.0/ikvm/linux-x64/bin"
if [ -d "$IKVM_BIN" ]; then
    export LD_LIBRARY_PATH="$IKVM_BIN${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
dotnet run --project TestRNG.csproj -c Release -- "$SEED" 2>&1 | tee cs_full.txt || true

# Extract Custom C# section: 100 integer lines after "# Custom C#"
# Extract IKVM Java section: 100 integer lines after "# IKVM Java"
# (Use integer-only lines to avoid capturing error messages if IKVM crashes)
echo ""
echo "Extracting sections..."
awk '
  /^# Custom C#/ { in_custom=1; in_ikvm=0; next }
  /^# IKVM Java/ { in_custom=0; in_ikvm=1; next }
  in_custom && /^-?[0-9]+$/ { print > "custom_out.txt" }
  in_ikvm   && /^-?[0-9]+$/ { print > "ikvm_out.txt" }
' cs_full.txt

echo ""
echo "=== Diff: Java vs Custom C# (48-bit LCG) ==="
echo "(Should be empty if Custom C# port is correct)"
if diff -u java_out.txt custom_out.txt; then
    echo "PASS: Custom C# matches Java"
else
    echo "FAIL: Custom C# differs from Java"
fi

echo ""
echo "=== Diff: Java vs IKVM Java (java.util.Random via bridge) ==="
echo "(Should be empty if IKVM bridge preserves RNG behavior)"
if [ ! -s ikvm_out.txt ]; then
    echo "NOTE: IKVM section empty - IKVM may have crashed (e.g. libiava.so symbol error on Linux)."
    echo "      Try running on Windows, or check IKVM runtime requirements."
else
    if diff -u java_out.txt ikvm_out.txt; then
        echo "PASS: IKVM Java matches Native Java"
    else
        echo "FAIL: IKVM Java differs from Native Java (bridge may cause world-gen divergence)"
    fi
fi

echo ""
echo "=== Summary ==="
echo "Java output:    $(wc -l < java_out.txt) lines"
echo "Custom C#:      $(wc -l < custom_out.txt) lines"
echo "IKVM Java:      $(wc -l < ikvm_out.txt) lines"
