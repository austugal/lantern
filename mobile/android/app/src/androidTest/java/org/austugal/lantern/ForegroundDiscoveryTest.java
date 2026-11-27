package org.austugal.lantern;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import androidx.lifecycle.Lifecycle;
import androidx.test.core.app.ActivityScenario;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.Collections;
import org.junit.Test;
import org.junit.runner.RunWith;

/** Actual Activity lifecycle checks; no nearby peer or radio delivery is exercised. */
@RunWith(AndroidJUnit4.class)
public final class ForegroundDiscoveryTest {
    @Test(timeout = 60000)
    public void stoppedChannelStartIsRejectedBeforeMutation() {
        try (ActivityScenario<MainActivity> scenario = ActivityScenario.launch(MainActivity.class)) {
            // ActivityScenario reaches CREATED through onStop, not initial onCreate.
            scenario.moveToState(Lifecycle.State.CREATED);
            scenario.onActivity(activity -> {
                assertFalse((Boolean) field(activity, "foreground"));
                assertFalse((Boolean) field(activity, "running"));
                assertNull(field(activity, "permissionResult"));
                Object generation = field(activity, "generation");
                Object displayName = field(activity, "displayName");
                ResultCapture result = new ResultCapture();
                invoke(activity, "handle", new Class<?>[]{MethodCall.class, MethodChannel.Result.class},
                        new MethodCall("start", Collections.singletonMap("name", "Lifecycle test")), result);
                result.assertError("state");
                assertEquals(generation, field(activity, "generation"));
                assertEquals(displayName, field(activity, "displayName"));
                assertFalse((Boolean) field(activity, "running"));
                assertNull(field(activity, "permissionResult"));
            });
        }
    }

    @Test(timeout = 60000)
    public void stoppedNativeStartIsRejectedAndResumeRestoresAdmission() {
        try (ActivityScenario<MainActivity> scenario = ActivityScenario.launch(MainActivity.class)) {
            scenario.moveToState(Lifecycle.State.CREATED);
            scenario.onActivity(activity -> {
                Object generation = field(activity, "generation");
                ResultCapture result = new ResultCapture();
                // Exercise the shared continuation used after permission approval directly.
                invoke(activity, "start", new Class<?>[]{MethodChannel.Result.class}, result);
                result.assertError("state");
                assertEquals(generation, field(activity, "generation"));
                assertFalse((Boolean) field(activity, "running"));
                assertNull(field(activity, "permissionResult"));
            });
            scenario.moveToState(Lifecycle.State.RESUMED);
            scenario.onActivity(activity -> {
                assertTrue((Boolean) field(activity, "foreground"));
                ResultCapture result = new ResultCapture();
                // A blank name reaches normal foreground validation without requesting permissions.
                invoke(activity, "handle", new Class<?>[]{MethodCall.class, MethodChannel.Result.class},
                        new MethodCall("start", Collections.singletonMap("name", "")), result);
                result.assertError("name");
                assertFalse((Boolean) field(activity, "running"));
                assertNull(field(activity, "permissionResult"));
            });
        }
    }

    private static Object field(MainActivity activity, String name) {
        try {
            Field field = MainActivity.class.getDeclaredField(name);
            field.setAccessible(true);
            return field.get(activity);
        } catch (ReflectiveOperationException failure) {
            throw new AssertionError("Cannot inspect native state: " + name, failure);
        }
    }

    private static void invoke(MainActivity activity, String name, Class<?>[] types, Object... args) {
        try {
            Method method = MainActivity.class.getDeclaredMethod(name, types);
            method.setAccessible(true);
            method.invoke(activity, args);
        } catch (ReflectiveOperationException failure) {
            throw new AssertionError("Cannot invoke native entry: " + name, failure);
        }
    }

    private static final class ResultCapture implements MethodChannel.Result {
        private int completions;
        private String errorCode;

        @Override public void success(Object value) { completions++; }
        @Override public void error(String code, String message, Object details) {
            completions++;
            errorCode = code;
        }
        @Override public void notImplemented() { completions++; }

        void assertError(String expected) {
            assertEquals("Method result must complete exactly once", 1, completions);
            assertEquals(expected, errorCode);
        }
    }
}
