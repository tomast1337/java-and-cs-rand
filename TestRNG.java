import java.util.Random;

/**
 * Standard Java program that takes a long seed, instantiates java.util.Random,
 * and prints the first 100 nextInt() values.
 * Used as the reference for comparing Native C#, Custom C# JavaRandom, and IKVM-bridged Java.
 */
public class TestRNG {
    public static void main(String[] args) {
        long seed = args.length > 0 ? Long.parseLong(args[0]) : 12345L;
        Random rng = new Random(seed);
        for (int i = 0; i < 100; i++) {
            System.out.println(rng.nextInt());
        }
    }
}
