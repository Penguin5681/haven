package com.jais.haven;

import android.accessibilityservice.AccessibilityService;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.SystemClock;
import android.view.KeyEvent;
import android.view.accessibility.AccessibilityEvent;
import android.widget.Toast;

import androidx.core.app.NotificationCompat;
import androidx.core.content.ContextCompat;

public class SosAccessibilityService extends AccessibilityService {

    private static final String SOS_CHANNEL_ID = "haven_sos_channel";
    private static final int SOS_NOTIFICATION_ID = 5001;
    private static final int REQUIRED_PRESS_COUNT = 5;
    private static final long PRESS_WINDOW_MS = 3500L;

    private boolean isVolUpPressed = false;
    private boolean isVolDownPressed = false;

    private int pressCount = 0;
    private long lastPressAtMs = 0L;

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
    }

    @Override
    public void onInterrupt() {
    }

    @Override
    protected boolean onKeyEvent(KeyEvent event) {
        if (event.getAction() != KeyEvent.ACTION_DOWN) {
            return false;
        }

        final int keyCode = event.getKeyCode();
        if (keyCode != KeyEvent.KEYCODE_VOLUME_UP && keyCode != KeyEvent.KEYCODE_VOLUME_DOWN) {
            return false;
        }

        registerVolumePress(event);

        return false;
    }

    private void registerVolumePress(KeyEvent event) {
        final int keyCode = event.getKeyCode();

        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            isVolUpPressed = true;
        } else if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            isVolDownPressed = true;
        }

        if (isVolUpPressed && isVolDownPressed) {
            isVolUpPressed = false;
            isVolDownPressed = false;

            triggerSosNotification();
        }
    }

    private void triggerSosNotification() {
        createNotificationChannel();

        Intent launchIntent = new Intent(this, MainActivity.class);
        launchIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent pendingIntent = PendingIntent.getActivity(
                this,
                0,
                launchIntent,
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                        ? PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT
                        : PendingIntent.FLAG_UPDATE_CURRENT);

        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, SOS_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_notify_error)
                .setContentTitle("Haven SOS Triggered")
                .setContentText("SOS was triggered using volume button presses.")
                .setStyle(new NotificationCompat.BigTextStyle()
                        .bigText("SOS was triggered using 5 rapid presses of the volume button."))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC);

        NotificationManager manager = getSystemService(NotificationManager.class);
        if (manager == null) {
            Toast.makeText(this, "SOS triggered", Toast.LENGTH_LONG).show();
            return;
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            int permissionState = ContextCompat.checkSelfPermission(
                    this,
                    android.Manifest.permission.POST_NOTIFICATIONS);
            if (permissionState != PackageManager.PERMISSION_GRANTED) {
                Toast.makeText(
                        this,
                        "SOS triggered (notification permission missing)",
                        Toast.LENGTH_LONG).show();
                return;
            }
        }

        try {
            manager.notify(SOS_NOTIFICATION_ID, builder.build());
        } catch (SecurityException ex) {
            Toast.makeText(this, "SOS triggered", Toast.LENGTH_LONG).show();
        }
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return;
        }

        NotificationChannel channel = new NotificationChannel(
                SOS_CHANNEL_ID,
                "Haven SOS Alerts",
                NotificationManager.IMPORTANCE_HIGH);
        channel.setDescription("Notifications shown when SOS is triggered by hardware buttons.");

        NotificationManager manager = getSystemService(NotificationManager.class);
        if (manager != null) {
            manager.createNotificationChannel(channel);
        }
    }
}
