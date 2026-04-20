package com.jais.haven;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class FakeCallActionReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null) {
            return;
        }

        String callerNumber = intent.getStringExtra(FakeCallUiManager.EXTRA_CALLER_NUMBER);
        String action = intent.getAction();

        if (FakeCallUiManager.ACTION_ACCEPT.equals(action)) {
            FakeCallUiManager.cancelIncomingNotification(context);
            FakeCallUiManager.startOngoingActivity(context, callerNumber);
            return;
        }

        if (FakeCallUiManager.ACTION_DECLINE.equals(action)) {
            FakeCallUiManager.cancelIncomingNotification(context);
        }
    }
}
