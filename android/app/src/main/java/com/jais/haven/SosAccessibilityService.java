package com.jais.haven;

import android.accessibilityservice.AccessibilityService;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.location.Location;
import android.location.LocationManager;
import android.os.Build;
import android.os.SystemClock;
import android.telephony.SmsManager;
import android.text.TextUtils;
import android.util.Log;
import android.view.KeyEvent;
import android.view.accessibility.AccessibilityEvent;
import android.widget.Toast;

import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.location.Priority;
import com.google.android.gms.tasks.CancellationTokenSource;
import com.google.android.gms.tasks.Tasks;

import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;
import androidx.core.content.ContextCompat;

import org.json.JSONObject;

import java.io.BufferedOutputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.TimeZone;
import java.util.concurrent.TimeUnit;

public class SosAccessibilityService extends AccessibilityService {

    private static final String TAG = "SosAccessibility";
    private static final String SOS_TRIGGER_URL =
            "https://haven-backend-671108073568.asia-south2.run.app/api/sos/trigger";
    private static final String PREFS_NAME = "FlutterSharedPreferences";
    private static final String PREFS_TOKEN_KEY = "flutter.jwt_token";
    private static final String PREFS_CONTACTS_KEY = "flutter.trusted_contacts_v1";

    private static final String SOS_CHANNEL_ID = "haven_sos_channel";
    private static final int SOS_NOTIFICATION_ID = 5001;
    private static final long COMBO_WINDOW_MS = 700L;
    private static final long TRIGGER_COOLDOWN_MS = 10_000L;

    private boolean isVolUpPressed = false;
    private boolean isVolDownPressed = false;

    private long lastKeyAtMs = 0L;
    private long lastTriggerAtMs = 0L;

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
        final long now = SystemClock.elapsedRealtime();

        if (now - lastKeyAtMs > COMBO_WINDOW_MS) {
            isVolUpPressed = false;
            isVolDownPressed = false;
        }
        lastKeyAtMs = now;

        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            isVolUpPressed = true;
        } else if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            isVolDownPressed = true;
        }

        if (isVolUpPressed && isVolDownPressed) {
            isVolUpPressed = false;
            isVolDownPressed = false;
            handleSosTrigger();
        }
    }

    private void handleSosTrigger() {
        final long now = SystemClock.elapsedRealtime();
        if (now - lastTriggerAtMs < TRIGGER_COOLDOWN_MS) {
            return;
        }
        lastTriggerAtMs = now;

        triggerSosNotification();
        startBackgroundRecording();

        new Thread(this::performBackgroundSos).start();
    }

    private void startBackgroundRecording() {
        try {
            final Intent intent = new Intent(this, ChunkAudioRecordingService.class);
            intent.setAction(ChunkAudioRecordingService.ACTION_START);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent);
            } else {
                startService(intent);
            }
        } catch (Exception ex) {
            Log.w(TAG, "Failed to start background recording", ex);
        }
    }

    private void performBackgroundSos() {
        final Location location = resolveBestLocation();
        final String locationMessage = buildLocationMessage(location);
        sendSmsToTrustedContacts(locationMessage);
        triggerSosApi(location);
    }

    private void sendSmsToTrustedContacts(String locationMessage) {
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.SEND_SMS)
                != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "SEND_SMS permission missing; skipping SMS dispatch.");
            return;
        }

        final List<String> numbers = loadTrustedContactNumbers();
        if (numbers.isEmpty()) {
            return;
        }

        final SmsManager smsManager = SmsManager.getDefault();
        final String message = "SOS Alert! I need help. " + locationMessage;
        for (final String number : numbers) {
            if (TextUtils.isEmpty(number)) {
                continue;
            }
            try {
                smsManager.sendTextMessage(number, null, message, null, null);
            } catch (Exception ex) {
                Log.w(TAG, "Failed to send SMS to " + number, ex);
            }
        }
    }

    private void triggerSosApi(@Nullable Location location) {
        final String token = loadJwtToken();
        if (TextUtils.isEmpty(token)) {
            Log.w(TAG, "JWT token missing; skipping SOS API call.");
            return;
        }
        if (location == null) {
            Log.w(TAG, "Location unavailable; skipping SOS API call.");
            return;
        }

        HttpURLConnection connection = null;
        try {
            final URL url = new URL(SOS_TRIGGER_URL);
            connection = (HttpURLConnection) url.openConnection();
            connection.setRequestMethod("POST");
            connection.setConnectTimeout(8000);
            connection.setReadTimeout(8000);
            connection.setRequestProperty("Content-Type", "application/json");
            connection.setRequestProperty("Authorization", "Bearer " + token);
            connection.setDoOutput(true);

            final JSONObject payload = new JSONObject();
            payload.put("latitude", location.getLatitude());
            payload.put("longitude", location.getLongitude());
            payload.put("accuracy", location.getAccuracy());
            payload.put("timestamp", isoTimestamp());

            try (OutputStream out = new BufferedOutputStream(connection.getOutputStream())) {
                out.write(payload.toString().getBytes());
                out.flush();
            }

            final int code = connection.getResponseCode();
            if (code < 200 || code >= 300) {
                Log.w(TAG, "SOS API response code: " + code);
            }
        } catch (Exception ex) {
            Log.w(TAG, "Failed to trigger SOS API", ex);
        } finally {
            if (connection != null) {
                connection.disconnect();
            }
        }
    }

    private String isoTimestamp() {
        final SimpleDateFormat formatter = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US);
        formatter.setTimeZone(TimeZone.getTimeZone("UTC"));
        return formatter.format(new Date());
    }

    @Nullable
    private Location resolveBestLocation() {
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION)
                != PackageManager.PERMISSION_GRANTED
                && ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_COARSE_LOCATION)
                != PackageManager.PERMISSION_GRANTED) {
            return null;
        }

        try {
            final FusedLocationProviderClient client = LocationServices.getFusedLocationProviderClient(this);
            final CancellationTokenSource tokenSource = new CancellationTokenSource();
            Location location = Tasks.await(
                    client.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, tokenSource.getToken()),
                    6,
                    TimeUnit.SECONDS
            );
            if (location != null) {
                return location;
            }

            location = Tasks.await(client.getLastLocation(), 3, TimeUnit.SECONDS);
            if (location != null) {
                return location;
            }
        } catch (Exception ex) {
            Log.w(TAG, "Fused location lookup failed", ex);
        }

        return resolveLastKnownLocation();
    }

    @Nullable
    private Location resolveLastKnownLocation() {
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION)
                != PackageManager.PERMISSION_GRANTED
                && ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_COARSE_LOCATION)
                != PackageManager.PERMISSION_GRANTED) {
            return null;
        }

        final LocationManager locationManager = (LocationManager) getSystemService(LOCATION_SERVICE);
        if (locationManager == null) {
            return null;
        }

        Location best = null;
        try {
            final List<String> providers = locationManager.getProviders(true);
            for (String provider : providers) {
                Location location = locationManager.getLastKnownLocation(provider);
                if (location == null) {
                    continue;
                }
                if (best == null || location.getTime() > best.getTime()) {
                    best = location;
                }
            }
        } catch (Exception ex) {
            Log.w(TAG, "Unable to resolve location", ex);
        }
        return best;
    }

    private String buildLocationMessage(@Nullable Location location) {
        if (location == null) {
            return "Location unavailable.";
        }
        return "My location: https://maps.google.com/?q="
                + location.getLatitude() + "," + location.getLongitude();
    }

    private List<String> loadTrustedContactNumbers() {
        final SharedPreferences prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        final Set<String> rawContacts = prefs.getStringSet(PREFS_CONTACTS_KEY, null);
        if (rawContacts == null || rawContacts.isEmpty()) {
            return new ArrayList<>();
        }

        final Set<String> numbers = new HashSet<>();
        for (String raw : rawContacts) {
            if (TextUtils.isEmpty(raw)) {
                continue;
            }
            try {
                final JSONObject json = new JSONObject(raw);
                final String phone = json.optString("phone_number");
                if (!TextUtils.isEmpty(phone)) {
                    numbers.add(phone);
                }
            } catch (Exception ex) {
                Log.w(TAG, "Skipping malformed trusted contact", ex);
            }
        }
        return new ArrayList<>(numbers);
    }

    private String loadJwtToken() {
        final SharedPreferences prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        return prefs.getString(PREFS_TOKEN_KEY, null);
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
            .setContentText("Sending SOS and starting background recording.")
                .setStyle(new NotificationCompat.BigTextStyle()
                .bigText("SOS triggered by volume button combo. Sending alerts and starting background recording."))
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
