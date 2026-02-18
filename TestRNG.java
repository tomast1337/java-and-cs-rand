import java.util.Random;
import java.io.PrintWriter;
import java.io.IOException;

/**
 * Standard Java program that takes a long seed and optional round count,
 * instantiates java.util.Random, and outputs one value per line from each
 * public method in order (nextInt, nextFloat, nextLong, nextDouble, nextBoolean,
 * nextInt(100), nextGaussian) per round.
 * Used as the reference for comparing Custom C# JavaRandom and IKVM-bridged Java.
 *
 * Usage: java TestRNG [seed] [count]
 *   seed: default 12345
 *   count: default 100. If provided, writes to java.txt; otherwise prints to stdout (legacy).
 */
public class TestRNG {
    private static final int BOUND_FOR_NEXT_INT = 100;

    private static void writeOneRound(Random rng, PrintWriter w) {
        w.println(rng.nextInt());
        w.println(String.format("%08x", Float.floatToIntBits(rng.nextFloat())));
        w.println(rng.nextLong());
        w.println(String.format("%016x", Double.doubleToLongBits(rng.nextDouble())));
        w.println(rng.nextBoolean());
        w.println(rng.nextInt(BOUND_FOR_NEXT_INT));
        w.println(String.format("%016x", Double.doubleToLongBits(rng.nextGaussian())));
    }

    public static void main(String[] args) throws IOException {
        long seed = args.length > 0 ? Long.parseLong(args[0]) : 12345L;
        int count = args.length > 1 ? Integer.parseInt(args[1]) : 100;

        if (args.length > 1) {
            try (PrintWriter out = new PrintWriter("java.txt")) {
                Random rng = new Random(seed);
                for (int i = 0; i < count; i++) {
                    writeOneRound(rng, out);
                }
            }
            return;
        }

        // Legacy: no count → print 100 nextInt() to stdout
        Random rng = new Random(seed);
        for (int i = 0; i < 100; i++) {
            System.out.println(rng.nextInt());
        }
    }
}
