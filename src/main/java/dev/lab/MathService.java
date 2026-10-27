package dev.lab;

public final class MathService {
    private MathService() {}

    public static int add(int left, int right) {
        return Math.addExact(left, right);
    }

    public static boolean isPrime(int n) {
        if (n < 2) return false;
        if (n == 2) return true;
        if ((n & 1) == 0) return false;
        for (int divisor = 3; (long) divisor * divisor <= n; divisor += 2) {
            if (n % divisor == 0) return false;
        }
        return true;
    }
}
