package com.jais.haven;

import android.app.Activity;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.WindowManager;
import android.widget.ImageButton;
import android.widget.TextView;

import java.util.Locale;

public class FakeOngoingCallActivity extends Activity {

    private final Handler timerHandler = new Handler(Looper.getMainLooper());
    private long callStartedAtMs;
    private TextView callTimerView;
    private ImageButton muteButton;
    private ImageButton speakerButton;
    private TextView muteLabel;
    private TextView speakerLabel;

    private boolean muted = false;
    private boolean speakerOn = false;

    private final Runnable timerTick = new Runnable() {
        @Override
        public void run() {
            long elapsedSec = (System.currentTimeMillis() - callStartedAtMs) / 1000L;
            long min = elapsedSec / 60L;
            long sec = elapsedSec % 60L;
            callTimerView.setText(String.format(Locale.US, "%02d:%02d", min, sec));
            timerHandler.postDelayed(this, 1000L);
        }
    };

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

        setContentView(R.layout.activity_fake_ongoing_call);

        String callerName = FakeCallUiManager.normalizeCaller(
                getIntent().getStringExtra(FakeCallUiManager.EXTRA_CALLER_NAME)
        );
        String callerNumber = FakeCallUiManager.normalizeCaller(
                getIntent().getStringExtra(FakeCallUiManager.EXTRA_CALLER_NUMBER)
        );

        TextView callerNameView = findViewById(R.id.ongoingCallerName);
        TextView callerNumberView = findViewById(R.id.ongoingCallerNumber);
        callTimerView = findViewById(R.id.ongoingCallTimer);
        muteButton = findViewById(R.id.ongoingMute);
        speakerButton = findViewById(R.id.ongoingSpeaker);
        muteLabel = findViewById(R.id.ongoingMuteLabel);
        speakerLabel = findViewById(R.id.ongoingSpeakerLabel);

        callerNameView.setText(callerName);
        callerNumberView.setText(callerNumber);
        callTimerView.setText("00:00");

        findViewById(R.id.ongoingEndCall).setOnClickListener(v -> finish());

        findViewById(R.id.ongoingKeypad).setOnClickListener(v -> {
            // Placeholder to mimic dialer keypad action.
        });

        findViewById(R.id.ongoingAddCall).setOnClickListener(v -> {
            // Placeholder to mimic add call action.
        });

        muteButton.setOnClickListener(v -> {
            muted = !muted;
            updateActionState();
        });

        speakerButton.setOnClickListener(v -> {
            speakerOn = !speakerOn;
            updateActionState();
        });

        updateActionState();
        callStartedAtMs = System.currentTimeMillis();
        timerHandler.post(timerTick);
    }

    @Override
    protected void onDestroy() {
        timerHandler.removeCallbacks(timerTick);
        super.onDestroy();
    }

    private void updateActionState() {
        muteLabel.setText(muted ? "Muted" : "Mute");
        speakerLabel.setText(speakerOn ? "Speaker On" : "Speaker");

        muteButton.setSelected(muted);
        speakerButton.setSelected(speakerOn);

        muteLabel.setTextColor(muted ? 0xFFFFFFFF : 0xFFA0A0A0);
        speakerLabel.setTextColor(speakerOn ? 0xFFFFFFFF : 0xFFA0A0A0);
    }
}
