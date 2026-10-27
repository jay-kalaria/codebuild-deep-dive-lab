package dev.lab;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

public final class BuildLab {
    public static void main(String[] args) throws Exception {
        if (args.length == 0) {
            System.out.println("CodeBuild Deep Dive Lab; run with 'cpu LIMIT WORKERS' or 'heap MIB'");
            return;
        }
        switch (args[0]) {
            case "cpu" -> runCpu(args);
            case "heap" -> runHeap(args);
            default -> throw new IllegalArgumentException("Unknown workload: " + args[0]);
        }
    }

    private static void runCpu(String[] args) throws Exception {
        if (args.length != 3) throw new IllegalArgumentException("Usage: cpu LIMIT WORKERS");
        int limit = Integer.parseInt(args[1]);
        int workers = Integer.parseInt(args[2]);
        if (limit < 100 || limit > 20_000_000 || workers < 1 || workers > 16) {
            throw new IllegalArgumentException("LIMIT must be 100..20000000 and WORKERS 1..16");
        }
        System.out.printf("availableProcessors=%d maxHeapMiB=%d limit=%d workers=%d%n",
                Runtime.getRuntime().availableProcessors(),
                Runtime.getRuntime().maxMemory() / (1024 * 1024), limit, workers);
        long start = System.nanoTime();
        ExecutorService executor = Executors.newFixedThreadPool(workers);
        try {
            List<Callable<Integer>> tasks = new ArrayList<>();
            for (int index = 0; index < workers; index++) {
                int from = 2 + (limit - 1) * index / workers;
                int to = 2 + (limit - 1) * (index + 1) / workers;
                tasks.add(() -> {
                    int count = 0;
                    for (int candidate = from; candidate < to; candidate++) {
                        if (MathService.isPrime(candidate)) count++;
                    }
                    return count;
                });
            }
            int count = 0;
            for (Future<Integer> future : executor.invokeAll(tasks)) count += future.get();
            double secs = (System.nanoTime() - start) / 1_000_000_000.0;
            System.out.printf("primeCount=%d computeSeconds=%.3f%n", count, secs);
        } finally {
            executor.shutdown();
            if (!executor.awaitTermination(30, TimeUnit.SECONDS)) executor.shutdownNow();
        }
    }

    private static void runHeap(String[] args) {
        if (args.length != 2) throw new IllegalArgumentException("Usage: heap MIB");
        int mib = Integer.parseInt(args[1]);
        if (mib < 1 || mib > 128) throw new IllegalArgumentException("MIB must be 1..128");
        System.out.printf("requestedAllocationMiB=%d maxHeapMiB=%d%n",
                mib, Runtime.getRuntime().maxMemory() / (1024 * 1024));
        List<byte[]> hold = new ArrayList<>();
        for (int i = 0; i < mib; i++) {
            byte[] chunk = new byte[1024 * 1024];
            chunk[0] = (byte) i;
            hold.add(chunk);
        }
        System.out.println("allocatedMiB=" + hold.size());
    }
}
