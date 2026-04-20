package com.jais.haven;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.SystemClock;

public final class FakeCallScheduler {

    private static final int REQUEST_CODE_NORMAL = 8100;
    private static final int REQUEST_CODE_ANGRY = 8200;

    private FakeCallScheduler() {}

    public static boolean scheduleNormalCall(Context context, int delaySeconds, String phoneNumber) {
        cancelNormalCall(context);
        long triggerAt = SystemClock.elapsedRealtime() + Math.max(1, delaySeconds) * 1000L;
        PendingIntent pendingIntent = buildPendingIntent(
                context,
                REQUEST_CODE_NORMAL,
                FakeCallAlarmReceiver.MODE_NORMAL,
                Math.max(0, delaySeconds),
                1,
                normalizePhone(phoneNumber)
        );
            return scheduleAlarm(context, triggerAt, pendingIntent);
    }

            public static boolean startAngryFatherMode(
            Context context,
            int delaySeconds,
            int repeatCount,
            String phoneNumber
    ) {
        cancelAngryFatherMode(context);
        int safeRepeatCount = Math.max(1, repeatCount);
        long triggerAt = SystemClock.elapsedRealtime() + Math.max(1, delaySeconds) * 1000L;
        PendingIntent pendingIntent = buildPendingIntent(
                context,
                REQUEST_CODE_ANGRY,
                FakeCallAlarmReceiver.MODE_ANGRY,
                Math.max(1, delaySeconds),
                safeRepeatCount,
                normalizePhone(phoneNumber)
        );
            return scheduleAlarm(context, triggerAt, pendingIntent);
    }

    public static void cancelNormalCall(Context context) {
        PendingIntent pendingIntent = buildPendingIntent(
                context,
                REQUEST_CODE_NORMAL,
                FakeCallAlarmReceiver.MODE_NORMAL,
                0,
                0,
                ""
        );
        cancelPendingIntent(context, pendingIntent);
    }

    public static void cancelAngryFatherMode(Context context) {
        PendingIntent pendingIntent = buildPendingIntent(
                context,
                REQUEST_CODE_ANGRY,
                FakeCallAlarmReceiver.MODE_ANGRY,
                0,
                0,
                ""
        );
        cancelPendingIntent(context, pendingIntent);
    }

    private static PendingIntent buildPendingIntent(
            Context context,
            int requestCode,
            String mode,
            int delaySeconds,
            int remainingCount,
            String phoneNumber
    ) {
        Intent intent = new Intent(context, FakeCallAlarmReceiver.class);
        intent.setAction(FakeCallAlarmReceiver.ACTION_TRIGGER_FAKE_CALL);
        intent.putExtra(FakeCallAlarmReceiver.EXTRA_MODE, mode);
        intent.putExtra(FakeCallAlarmReceiver.EXTRA_DELAY_SECONDS, delaySeconds);
        intent.putExtra(FakeCallAlarmReceiver.EXTRA_REMAINING_COUNT, remainingCount);
        intent.putExtra(FakeCallAlarmReceiver.EXTRA_PHONE_NUMBER, phoneNumber);

        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }
        return PendingIntent.getBroadcast(context, requestCode, intent, flags);
    }

    private static boolean scheduleAlarm(Context context, long triggerAtElapsed, PendingIntent pendingIntent) {
        AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (alarmManager == null) {
            return false;
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
                alarmManager.setAndAllowWhileIdle(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
                        triggerAtElapsed,
                        pendingIntent
                );
                return true;
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
                        triggerAtElapsed,
                        pendingIntent
                );
                return true;
            }

            alarmManager.setExact(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerAtElapsed,
                    pendingIntent
            );
            return true;
        } catch (SecurityException ex) {
            try {
                alarmManager.setAndAllowWhileIdle(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
                        triggerAtElapsed,
                        pendingIntent
                );
                return true;
            } catch (Exception ignored) {
                return false;
            }
        }
    }

    private static void cancelPendingIntent(Context context, PendingIntent pendingIntent) {
        AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (alarmManager != null) {
            alarmManager.cancel(pendingIntent);
        }
        pendingIntent.cancel();
    }

    private static String normalizePhone(String phoneNumber) {
        if (phoneNumber == null) {
            return "";
        }
        String normalized = phoneNumber.trim();
        return normalized.isEmpty() ? "9999999999" : normalized;
    }
}
