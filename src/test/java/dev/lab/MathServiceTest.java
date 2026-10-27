package dev.lab;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class MathServiceTest {
    @Test void additionWorks() { assertEquals(5, MathService.add(2, 3)); }
    @Test void primesWork() {
        assertTrue(MathService.isPrime(2));
        assertTrue(MathService.isPrime(97));
        assertFalse(MathService.isPrime(99));
        assertFalse(MathService.isPrime(1));
    }
    @Test void overflowIsRejected() {
        assertThrows(ArithmeticException.class, () -> MathService.add(Integer.MAX_VALUE, 1));
    }
    @Test void optionalFailureForBuildSystemExperiment() {
        if (Boolean.getBoolean("lab.forceFailure")) {
            assertEquals(10, MathService.add(2, 3), "Intentional test failure for CodeBuild lab");
        } else {
            assertEquals(5, MathService.add(2, 3));
        }
    }
}
