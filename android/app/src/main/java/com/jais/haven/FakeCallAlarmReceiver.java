package com.jais.haven;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class FakeCallAlarmReceiver extends BroadcastReceiver {

    public static final String ACTION_TRIGGER_FAKE_CALL =
            "com.jais.haven.action.TRIGGER_FAKE_CALL";

    public static final String MODE_NORMAL = "normal";
    public static final String MODE_ANGRY = "angry";

    public static final String EXTRA_MODE = "mode";
    public static final String EXTRA_DELAY_SECONDS = "delay_seconds";
    public static final String EXTRA_REMAINING_COUNT = "remaining_count";
    public static final String EXTRA_PHONE_NUMBER = "phone_number";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null) {
            return;
        }

        String mode = intent.getStringExtra(EXTRA_MODE);
        int delaySeconds = intent.getIntExtra(EXTRA_DELAY_SECONDS, 10);
        int remainingCount = intent.getIntExtra(EXTRA_REMAINING_COUNT, 1);
        String phoneNumber = intent.getStringExtra(EXTRA_PHONE_NUMBER);

        triggerCall(context, phoneNumber);

        if (MODE_ANGRY.equals(mode) && remainingCount > 1) {
            FakeCallScheduler.startAngryFatherMode(
                    context,
                    Math.max(1, delaySeconds),
                    remainingCount - 1,
                    phoneNumber
            );
        }
    }

    private void triggerCall(Context context, String phoneNumber) {
        FakeCallUiManager.showIncomingCall(context, normalizePhone(phoneNumber));
    }

    private String normalizePhone(String phoneNumber) {
        if (phoneNumber == null) {
            return "9999999999";
        }
        String normalized = phoneNumber.trim();
        return normalized.isEmpty() ? "9999999999" : normalized;
    }
}
