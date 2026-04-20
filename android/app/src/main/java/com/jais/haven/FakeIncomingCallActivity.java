package com.jais.haven;

import android.app.Activity;
import android.content.Intent;
import android.media.Ringtone;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.os.VibratorManager;
import android.view.WindowManager;
import android.widget.TextView;

public class FakeIncomingCallActivity extends Activity {

    private Ringtone ringtone;
    private Vibrator vibrator;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true);
            setTurnScreenOn(true);
        } else {
            getWindow().addFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                            | WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                            | WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            );
        }

        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        setContentView(R.layout.activity_fake_incoming_call);

        String callerName = FakeCallUiManager.normalizeCaller(
                getIntent().getStringExtra(FakeCallUiManager.EXTRA_CALLER_NAME)
        );
        String callerNumber = FakeCallUiManager.normalizeCaller(
                getIntent().getStringExtra(FakeCallUiManager.EXTRA_CALLER_NUMBER)
        );

        TextView callerNameView = findViewById(R.id.incomingCallerName);
        callerNameView.setText(callerName);

        TextView callerNumberView = findViewById(R.id.incomingCallerNumber);
        callerNumberView.setText(callerNumber);

        findViewById(R.id.incomingDecline).setOnClickListener(v -> {
            stopAlerting();
            FakeCallUiManager.cancelIncomingNotification(this);
            finish();
        });

        findViewById(R.id.incomingAccept).setOnClickListener(v -> {
            stopAlerting();
            FakeCallUiManager.cancelIncomingNotification(this);
            FakeCallUiManager.startOngoingActivity(this, callerName, callerNumber);
            finish();
        });

        findViewById(R.id.incomingAnswer).setOnClickListener(v -> {
            stopAlerting();
            FakeCallUiManager.cancelIncomingNotification(this);
            FakeCallUiManager.startOngoingActivity(this, callerName, callerNumber);
            finish();
        });

        FakeCallUiManager.cancelIncomingNotification(this);
        startRinging();
        startVibrating();
    }

    @Override
    protected void onDestroy() {
        stopAlerting();
        super.onDestroy();
    }

    private void startRinging() {
        try {
            Uri ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE);
            ringtone = RingtoneManager.getRingtone(this, ringtoneUri);
            if (ringtone != null && !ringtone.isPlaying()) {
                ringtone.play();
            }
        } catch (Exception ignored) {
        }
    }

    private void startVibrating() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                VibratorManager vibratorManager =
                        (VibratorManager) getSystemService(VIBRATOR_MANAGER_SERVICE);
                if (vibratorManager != null) {
                    vibrator = vibratorManager.getDefaultVibrator();
                }
            } else {
                vibrator = (Vibrator) getSystemService(VIBRATOR_SERVICE);
            }

            if (vibrator == null || !vibrator.hasVibrator()) {
                return;
            }

            long[] pattern = new long[]{0, 800, 700};
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, 0));
            } else {
                vibrator.vibrate(pattern, 0);
            }
        } catch (Exception ignored) {
        }
    }

    private void stopAlerting() {
        if (ringtone != null && ringtone.isPlaying()) {
            ringtone.stop();
        }
        ringtone = null;

        if (vibrator != null) {
            vibrator.cancel();
            vibrator = null;
        }
    }
}
