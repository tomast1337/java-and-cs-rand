/*
 * .NET 10 console application: generate x numbers with seed from Java (reference), IKVM, and custom JavaRandom.
 * Diffs: IKVM vs Java, JavaRandom (C#) vs Java. Timings for all three.
 *
 * Usage: TestRNG [seed] [count] [mode]
 *        seed: default 12345, count: rounds (default 100).
 *        mode: "javarandom" | "ikvm" | omit = both. Used so verify.sh can time each with bash time.
 *
 * Each round: nextInt(), nextFloat(), nextLong(), nextDouble(), nextBoolean(), nextInt(100), nextGaussian()
 */

/// <summary>
/// C# port of Java's 48-bit LCG (Linear Congruential Generator) from Random.
/// Original source: https://github.com/openjdk/jdk/blob/master/src/java.base/share/classes/Random.java
/// Implements the exact algorithm: seed = (seed * 0x5DEECE66DL + 0xBL) &amp; ((1L &lt;&lt; 48) - 1)
/// </summary>
public class JavaRandom
{
    private static long _seedUniquifier = 8682522807148012L;
    private readonly object _lock = new object();
    private bool _haveNextNextGaussian = false;
    private double _nextNextGaussian;
    private const float FloatUnit = 1.0f / (1 << 24);
    private const double DoubleUnit = 1.0 / (1L << 53);
    private const long Multiplier = 0x5DEECE66DL;
    private const long Addend = 0xBL;
    private const long Mask = (1L << 48) - 1;

    private long _seed;

    public JavaRandom(long seed)
    {
        SetSeed(seed);
    }

    public JavaRandom()
        : this(SeedUniquifier() ^ DateTime.UtcNow.Ticks)
    {
    }
    public void SetSeed(long seed)
    {
        lock (_lock)
        {
            Interlocked.Exchange(ref _seed, InitialScramble(seed));
            _haveNextNextGaussian = false;
        }
    }

    private static long InitialScramble(long seed)
    {
        return (seed ^ Multiplier) & Mask;
    }

    private int Next(int bits)
    {
        long oldSeed, nextSeed;
        do
        {
            oldSeed = Interlocked.Read(ref _seed);
            nextSeed = (oldSeed * Multiplier + Addend) & Mask;
        } 
        while (Interlocked.CompareExchange(ref _seed, nextSeed, oldSeed) != oldSeed);

        return (int)((ulong)nextSeed >> (48 - bits));
    }

    public int NextInt()
    {
        return Next(32);
    }
    public float NextFloat()
    {
        return Next(24) * FloatUnit;
    }

    public long NextLong()
    {
        return ((long)Next(32) << 32) + Next(32);
    }

    public double NextDouble()
    {
        return (((long)Next(26) << 27) + Next(27)) * DoubleUnit;
    }

    public int NextInt(int bound)
    {
        if (bound <= 0)
            throw new ArgumentException("bound must be positive");

        int r = Next(31);
        int m = bound - 1;

        if ((bound & m) == 0)
        {
            r = (int)((bound * (long)r) >> 31);
        }
        else
        {
            for (int u = r; u - (r = u % bound) + m < 0; u = Next(31)){ }
        }

        return r;
    }

    public bool NextBoolean() => Next(1) != 0;
    public double NextGaussian()
    {
        lock (_lock)
        {
            // See Knuth, TAOCP, Vol. 2, 3rd edition, Section 3.4.1 Algorithm C.
            if (_haveNextNextGaussian)
            {
                _haveNextNextGaussian = false;
                return _nextNextGaussian;
            }

            double v1, v2, s;
            do
            {
                v1 = 2 * NextDouble() - 1; // between -1 and 1
                v2 = 2 * NextDouble() - 1; // between -1 and 1
                s = v1 * v1 + v2 * v2;
            } while (s >= 1 || s == 0);

            // Math.Log and Math.Sqrt in C# are equivalent to Java's StrictMath
            double multiplier = Math.Sqrt(-2 * Math.Log(s) / s);

            _nextNextGaussian = v2 * multiplier;
            _haveNextNextGaussian = true;

            return v1 * multiplier;
        }
    }

    private static long SeedUniquifier()
    {
        while (true)
        {
            long current = Interlocked.Read(ref _seedUniquifier);
            long next = current * 1181783497276652981L;

            if (Interlocked.CompareExchange(ref _seedUniquifier, next, current) == current)
            {
                return next;
            }
        }
    }
}

internal static class Program
{
    private const int BoundForNextInt = 100;

    private static void WriteOneRound(JavaRandom rng, StreamWriter w)
    {
        w.WriteLine(rng.NextInt());
        w.WriteLine(BitConverter.SingleToInt32Bits(rng.NextFloat()).ToString("x8"));
        w.WriteLine(rng.NextLong());
        w.WriteLine(BitConverter.DoubleToInt64Bits(rng.NextDouble()).ToString("x16"));
        w.WriteLine(rng.NextBoolean() ? "true" : "false");
        w.WriteLine(rng.NextInt(BoundForNextInt));
        w.WriteLine(BitConverter.DoubleToInt64Bits(rng.NextGaussian()).ToString("x16"));
    }

    private static void WriteOneRoundIKVM(java.util.Random rng, StreamWriter w)
    {
        w.WriteLine(rng.nextInt());
        float f = rng.nextFloat();
        w.WriteLine(BitConverter.SingleToInt32Bits(f).ToString("x8"));
        w.WriteLine(rng.nextLong());
        double d = rng.nextDouble();
        w.WriteLine(BitConverter.DoubleToInt64Bits(d).ToString("x16"));
        w.WriteLine(rng.nextBoolean() ? "true" : "false");
        w.WriteLine(rng.nextInt(BoundForNextInt));
        double g = rng.nextGaussian();
        w.WriteLine(BitConverter.DoubleToInt64Bits(g).ToString("x16"));
    }

    private static void RunNativeCSharp(long seed)
    {
        Console.WriteLine("# Native C# (System.Random)");
        var rng = new System.Random((int)(seed & 0x7FFFFFFF));
        for (int i = 0; i < 100; i++)
            Console.WriteLine(rng.Next());
    }

    private static void RunIKVMJava(long seed)
    {
        Console.WriteLine("# IKVM Java (java.util.Random)");
        var rng = new java.util.Random(seed);
        for (int i = 0; i < 100; i++)
            Console.WriteLine(rng.nextInt());
    }

    private static void WriteToFiles(long seed, int count, string? mode)
    {
        bool doJavaRandom = mode != "ikvm";
        bool doIkvm = mode != "javarandom";

        if (doJavaRandom)
        {
            var customRng = new JavaRandom(seed);
            using (var csw = new StreamWriter("cs_java_random.txt"))
            {
                for (int i = 0; i < count; i++)
                    WriteOneRound(customRng, csw);
            }
        }

        if (doIkvm)
        {
            try
            {
                var ikvmRng = new java.util.Random(seed);
                using (var ikvmW = new StreamWriter("ikvm.txt"))
                {
                    for (int i = 0; i < count; i++)
                        WriteOneRoundIKVM(ikvmRng, ikvmW);
                }
            }
            catch (Exception)
            {
                File.WriteAllText("ikvm.txt", "");
            }
        }
    }

    public static void Main(string[] args)
    {
        long seed = args.Length > 0 ? long.Parse(args[0]) : 12345L;
        int? count = args.Length > 1 ? int.Parse(args[1]) : null;
        string? mode = args.Length > 2 ? args[2] : null; // "javarandom" | "ikvm" | null = both

        if (count.HasValue)
        {
            WriteToFiles(seed, count.Value, mode);
            return;
        }

        RunNativeCSharp(seed);
        Console.WriteLine();

        RunIKVMJava(seed);
    }
}
