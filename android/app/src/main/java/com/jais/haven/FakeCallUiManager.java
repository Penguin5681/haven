package com.jais.haven;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;

public final class FakeCallUiManager {

    public static final String EXTRA_CALLER_NAME = "extra_caller_name";
    public static final String EXTRA_CALLER_NUMBER = "extra_caller_number";
    public static final String ACTION_ACCEPT = "com.jais.haven.action.FAKE_CALL_ACCEPT";
    public static final String ACTION_DECLINE = "com.jais.haven.action.FAKE_CALL_DECLINE";

    private static final String CHANNEL_ID = "haven_fake_call_channel";
    private static final int NOTIFICATION_ID = 4101;

    private FakeCallUiManager() {
    }

    public static void showIncomingCall(Context context, String callerName, String callerNumber) {
        String normalizedName = normalizeCaller(callerName);
        String normalizedNum = normalizeCaller(callerNumber);
        createChannel(context);

        Intent fullScreenIntent = new Intent(context, FakeIncomingCallActivity.class);
        fullScreenIntent.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK
                        | Intent.FLAG_ACTIVITY_CLEAR_TOP
                        | Intent.FLAG_ACTIVITY_SINGLE_TOP
        );
        fullScreenIntent.putExtra(EXTRA_CALLER_NAME, normalizedName);
        fullScreenIntent.putExtra(EXTRA_CALLER_NUMBER, normalizedNum);

        PendingIntent fullScreenPendingIntent = PendingIntent.getActivity(
                context,
                1001,
                fullScreenIntent,
                immutableUpdateFlags()
        );

        Intent acceptIntent = new Intent(context, FakeCallActionReceiver.class);
        acceptIntent.setAction(ACTION_ACCEPT);
        acceptIntent.putExtra(EXTRA_CALLER_NAME, normalizedName);
        acceptIntent.putExtra(EXTRA_CALLER_NUMBER, normalizedNum);
        PendingIntent acceptPendingIntent = PendingIntent.getBroadcast(
                context,
                1002,
                acceptIntent,
                immutableUpdateFlags()
        );

        Intent declineIntent = new Intent(context, FakeCallActionReceiver.class);
        declineIntent.setAction(ACTION_DECLINE);
        declineIntent.putExtra(EXTRA_CALLER_NAME, normalizedName);
        declineIntent.putExtra(EXTRA_CALLER_NUMBER, normalizedNum);
        PendingIntent declinePendingIntent = PendingIntent.getBroadcast(
                context,
                1003,
                declineIntent,
                immutableUpdateFlags()
        );

        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(normalizedName)
                .setContentText("Incoming call")
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setAutoCancel(false)
                .setOngoing(true)
                .setFullScreenIntent(fullScreenPendingIntent, true)
                .setContentIntent(fullScreenPendingIntent)
                .setDeleteIntent(declinePendingIntent)
                .addAction(
                        android.R.drawable.sym_action_call,
                        "Answer",
                        acceptPendingIntent
                )
                .addAction(
                        android.R.drawable.ic_menu_close_clear_cancel,
                        "Decline",
                        declinePendingIntent
                );

        NotificationManagerCompat nm = NotificationManagerCompat.from(context);
        if (nm.areNotificationsEnabled()) {
            nm.notify(NOTIFICATION_ID, builder.build());
        }

        // Force immediate UI appearance while keeping full-screen notification fallback.
        startIncomingActivity(context, normalizedName, normalizedNum);
    }

    public static void startIncomingActivity(Context context, String callerName, String callerNumber) {
        Intent incomingIntent = new Intent(context, FakeIncomingCallActivity.class);
        incomingIntent.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK
                        | Intent.FLAG_ACTIVITY_CLEAR_TOP
                        | Intent.FLAG_ACTIVITY_SINGLE_TOP
        );
        incomingIntent.putExtra(EXTRA_CALLER_NAME, normalizeCaller(callerName));
        incomingIntent.putExtra(EXTRA_CALLER_NUMBER, normalizeCaller(callerNumber));
        context.startActivity(incomingIntent);
    }

    public static void startOngoingActivity(Context context, String callerName, String callerNumber) {
        Intent ongoingIntent = new Intent(context, FakeOngoingCallActivity.class);
        ongoingIntent.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK
                        | Intent.FLAG_ACTIVITY_CLEAR_TOP
                        | Intent.FLAG_ACTIVITY_SINGLE_TOP
        );
        ongoingIntent.putExtra(EXTRA_CALLER_NAME, normalizeCaller(callerName));
        ongoingIntent.putExtra(EXTRA_CALLER_NUMBER, normalizeCaller(callerNumber));
        context.startActivity(ongoingIntent);
    }

    public static void cancelIncomingNotification(Context context) {
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID);
    }

    public static String normalizeCaller(String callerNumber) {
        if (callerNumber == null) {
            return "Unknown";
        }
        String normalized = callerNumber.trim();
        return normalized.isEmpty() ? "Unknown" : normalized;
    }

    private static int immutableUpdateFlags() {
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }
        return flags;
    }

    private static void createChannel(Context context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return;
        }
        NotificationManager manager =
                (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (manager == null) {
            return;
        }

        NotificationChannel existing = manager.getNotificationChannel(CHANNEL_ID);
        if (existing != null) {
            return;
        }

        NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "Fake Calls",
                NotificationManager.IMPORTANCE_HIGH
        );
        channel.setDescription("Incoming fake call alerts");
        channel.setLockscreenVisibility(NotificationCompat.VISIBILITY_PUBLIC);
        manager.createNotificationChannel(channel);
    }
}
