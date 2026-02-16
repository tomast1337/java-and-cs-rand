/*
 * .NET 10 console application comparing three RNG implementations:
 *   1. Native C#: System.Random
 *   2. Custom C#: JavaRandom (48-bit LCG matching java.util.Random exactly)
 *   3. IKVM Java: java.util.Random via IKVM bridge
 *
 * Usage: TestRNG [seed]
 *        If no seed is provided, defaults to 12345.
 *
 * Outputs three sections (Native, Custom, IKVM) of 100 nextInt() values each.
 * Compare against Java TestRNG output to verify IKVM bridge correctness.
 */


/// <summary>
/// C# port of Java's 48-bit LCG (Linear Congruential Generator) from java.util.Random.
/// Implements the exact algorithm: seed = (seed * 0x5DEECE66DL + 0xBL) &amp; ((1L &lt;&lt; 48) - 1)
/// </summary>
internal sealed class JavaRandom
{
    private const long Multiplier = 0x5DEECE66DL;
    private const long Addend = 0xBL;
    private const long Mask = (1L << 48) - 1;

    private long _seed;

    public JavaRandom(long seed)
    {
        SetSeed(seed);
    }

    public void SetSeed(long seed)
    {
        _seed = InitialScramble(seed);
    }

    private static long InitialScramble(long seed)
    {
        return (seed ^ Multiplier) & Mask;
    }

    /// <summary>
    /// Port of Java's next(bits). Returns up to 32 random bits.
    /// </summary>
    private int Next(int bits)
    {
        _seed = (_seed * Multiplier + Addend) & Mask;
        return (int)(_seed >> (48 - bits));
    }

    /// <summary>
    /// Port of Java's nextInt() - returns next(32).
    /// </summary>
    public int NextInt()
    {
        return Next(32);
    }
}

internal static class Program
{
    private static void RunNativeCSharp(long seed)
    {
        Console.WriteLine("# Native C# (System.Random)");
        var rng = new System.Random((int)(seed & 0x7FFFFFFF));
        for (int i = 0; i < 100; i++)
            Console.WriteLine(rng.Next());
    }

    private static void RunCustomCSharp(long seed)
    {
        Console.WriteLine("# Custom C# (JavaRandom - 48-bit LCG)");
        var rng = new JavaRandom(seed);
        for (int i = 0; i < 100; i++)
            Console.WriteLine(rng.NextInt());
    }

    private static void RunIKVMJava(long seed)
    {
        Console.WriteLine("# IKVM Java (java.util.Random)");
        var rng = new java.util.Random(seed);
        for (int i = 0; i < 100; i++)
            Console.WriteLine(rng.nextInt());
    }

    public static void Main(string[] args)
    {
        long seed = args.Length > 0 ? long.Parse(args[0]) : 12345L;

        RunNativeCSharp(seed);
        Console.WriteLine();

        RunCustomCSharp(seed);
        Console.WriteLine();

        RunIKVMJava(seed);
    }
}
