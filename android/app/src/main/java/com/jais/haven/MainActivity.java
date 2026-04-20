package com.jais.haven;

import android.accessibilityservice.AccessibilityServiceInfo;
import android.content.ComponentName;
import android.content.Intent;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import android.text.TextUtils;
import android.view.accessibility.AccessibilityManager;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
	private static final String SOS_SETUP_CHANNEL = "haven/sos_setup";
	private static final String AUDIO_CHUNK_CHANNEL = "haven/audio_chunks";
	private static final String FAKE_CALL_CHANNEL = "haven/fake_call";

	private MediaPlayer chunkPlayer;
	private boolean angryFatherRunning = false;

	@Override
	public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
		super.configureFlutterEngine(flutterEngine);

		new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), SOS_SETUP_CHANNEL)
				.setMethodCallHandler((call, result) -> {
					switch (call.method) {
						case "isSosAccessibilityEnabled":
							result.success(isSosAccessibilityEnabled());
							break;
						case "openAccessibilitySettings":
							result.success(openAccessibilitySettings());
							break;
						default:
							result.notImplemented();
							break;
					}
				});

		new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), AUDIO_CHUNK_CHANNEL)
				.setMethodCallHandler((call, result) -> {
					switch (call.method) {
						case "startChunkRecording":
							result.success(startChunkRecording());
							break;
						case "stopChunkRecording":
							result.success(stopChunkRecording());
							break;
						case "isChunkRecording":
							result.success(ChunkAudioRecordingService.isRecordingActive());
							break;
						case "getChunkRecordingStatus":
							result.success(getChunkRecordingStatus());
							break;
						case "playChunkAudio": {
							final String path = call.argument("path");
							result.success(playChunkAudio(path));
							break;
						}
						case "stopChunkAudio":
							result.success(stopChunkAudio());
							break;
						default:
							result.notImplemented();
							break;
					}
				});

		new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), FAKE_CALL_CHANNEL)
				.setMethodCallHandler((call, result) -> {
					switch (call.method) {
						case "scheduleNormalFakeCall": {
							Integer delay = call.argument("delaySeconds");
							String phoneNumber = call.argument("phoneNumber");
							result.success(scheduleNormalFakeCall(delay, phoneNumber));
							break;
						}
						case "startAngryFatherMode": {
							Integer delay = call.argument("delaySeconds");
							Integer repeatCount = call.argument("repeatCount");
							String phoneNumber = call.argument("phoneNumber");
							result.success(startAngryFatherMode(delay, repeatCount, phoneNumber));
							break;
						}
						case "stopAngryFatherMode":
							result.success(stopAngryFatherMode());
							break;
						case "isAngryFatherModeRunning":
							result.success(angryFatherRunning);
							break;
						default:
							result.notImplemented();
							break;
					}
				});
	}

	@Override
	protected void onDestroy() {
		stopChunkAudio();
		super.onDestroy();
	}

	private Map<String, Object> getChunkRecordingStatus() {
		final Map<String, Object> status = new HashMap<>();
		final boolean isRecording = ChunkAudioRecordingService.isRecordingActive();
		final long startedAtMs = ChunkAudioRecordingService.getRecordingStartedAtMs();
		final long now = System.currentTimeMillis();
		final long elapsedMs = isRecording && startedAtMs > 0
				? Math.max(0, now - startedAtMs)
				: 0;

		status.put("isRecording", isRecording);
		status.put("startedAtMs", startedAtMs);
		status.put("elapsedMs", elapsedMs);
		status.put("chunkDurationMs", ChunkAudioRecordingService.getChunkDurationMs());
		status.put("saveDirectory", ChunkAudioRecordingService.getRecordingDirectoryPath());
		status.put("currentChunkPath", ChunkAudioRecordingService.getCurrentChunkPath());
		return status;
	}

	private boolean startChunkRecording() {
		try {
			final Intent intent = new Intent(this, ChunkAudioRecordingService.class);
			intent.setAction(ChunkAudioRecordingService.ACTION_START);
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
				startForegroundService(intent);
			} else {
				startService(intent);
			}
			return true;
		} catch (Exception ignored) {
			return false;
		}
	}

	private boolean stopChunkRecording() {
		try {
			final Intent intent = new Intent(this, ChunkAudioRecordingService.class);
			intent.setAction(ChunkAudioRecordingService.ACTION_STOP);
			startService(intent);
			return true;
		} catch (Exception ignored) {
			return false;
		}
	}

	private synchronized boolean playChunkAudio(String path) {
		if (TextUtils.isEmpty(path)) {
			return false;
		}

		stopChunkAudio();
		try {
			chunkPlayer = new MediaPlayer();
			chunkPlayer.setDataSource(path);
			chunkPlayer.setOnCompletionListener(mp -> releaseChunkPlayer());
			chunkPlayer.prepare();
			chunkPlayer.start();
			return true;
		} catch (Exception ignored) {
			releaseChunkPlayer();
			return false;
		}
	}

	private synchronized boolean stopChunkAudio() {
		if (chunkPlayer == null) {
			return true;
		}

		try {
			if (chunkPlayer.isPlaying()) {
				chunkPlayer.stop();
			}
		} catch (Exception ignored) {
		}

		releaseChunkPlayer();
		return true;
	}

	private synchronized void releaseChunkPlayer() {
		if (chunkPlayer == null) {
			return;
		}

		try {
			chunkPlayer.reset();
		} catch (Exception ignored) {
		}

		chunkPlayer.release();
		chunkPlayer = null;
	}

	private boolean isSosAccessibilityEnabled() {
		final String expectedPackage = getPackageName();
		final String expectedClass = SosAccessibilityService.class.getName();

		final AccessibilityManager accessibilityManager =
				(AccessibilityManager) getSystemService(ACCESSIBILITY_SERVICE);
		if (accessibilityManager != null && accessibilityManager.isEnabled()) {
			final List<AccessibilityServiceInfo> enabledServices =
					accessibilityManager.getEnabledAccessibilityServiceList(
							AccessibilityServiceInfo.FEEDBACK_ALL_MASK
					);
			for (AccessibilityServiceInfo info : enabledServices) {
				final String serviceId = info.getId();
				if (matchesServiceComponent(serviceId, expectedPackage, expectedClass)) {
					return true;
				}
			}
		}

		// Fallback for devices where manager APIs are inconsistent.
		final String enabledServices = Settings.Secure.getString(
				getContentResolver(),
				Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
		);
		if (TextUtils.isEmpty(enabledServices)) {
			return false;
		}

		final TextUtils.SimpleStringSplitter splitter = new TextUtils.SimpleStringSplitter(':');
		splitter.setString(enabledServices);
		while (splitter.hasNext()) {
			final String service = splitter.next();
			if (matchesServiceComponent(service, expectedPackage, expectedClass)) {
				return true;
			}
		}
		return false;
	}

	private boolean matchesServiceComponent(
			String flattenedComponent,
			String expectedPackage,
			String expectedClass
	) {
		if (TextUtils.isEmpty(flattenedComponent)) {
			return false;
		}

		final ComponentName component = ComponentName.unflattenFromString(flattenedComponent);
		if (component == null) {
			return false;
		}

		String className = component.getClassName();
		if (className.startsWith(".")) {
			className = component.getPackageName() + className;
		}

		return expectedPackage.equals(component.getPackageName())
				&& expectedClass.equals(className);
	}

	private boolean openAccessibilitySettings() {
		if (tryStartIntent(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))) {
			return true;
		}

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
			final Intent detailsIntent =
					new Intent("android.settings.ACCESSIBILITY_DETAILS_SETTINGS");
			detailsIntent.setData(Uri.parse("package:" + getPackageName()));
			if (tryStartIntent(detailsIntent)) {
				return true;
			}
		}

		final Intent appDetailsIntent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
		appDetailsIntent.setData(Uri.parse("package:" + getPackageName()));
		if (tryStartIntent(appDetailsIntent)) {
			return true;
		}

		return tryStartIntent(new Intent(Settings.ACTION_SETTINGS));
	}

	private boolean tryStartIntent(Intent intent) {
		try {
			intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
			if (intent.resolveActivity(getPackageManager()) == null) {
				return false;
			}
			startActivity(intent);
			return true;
		} catch (Exception ignored) {
			return false;
		}
	}

	private boolean scheduleNormalFakeCall(Integer delaySeconds, String phoneNumber) {
		try {
			return FakeCallScheduler.scheduleNormalCall(
					this,
					delaySeconds == null ? 10 : Math.max(1, delaySeconds),
					phoneNumber
			);
		} catch (Exception ignored) {
			return false;
		}
	}

	private boolean startAngryFatherMode(Integer delaySeconds, Integer repeatCount, String phoneNumber) {
		try {
			final boolean started = FakeCallScheduler.startAngryFatherMode(
					this,
					delaySeconds == null ? 20 : Math.max(1, delaySeconds),
					repeatCount == null ? 3 : Math.max(1, repeatCount),
					phoneNumber
			);
			angryFatherRunning = started;
			return started;
		} catch (Exception ignored) {
			return false;
		}
	}

	private boolean stopAngryFatherMode() {
		try {
			FakeCallScheduler.cancelAngryFatherMode(this);
			angryFatherRunning = false;
			return true;
		} catch (Exception ignored) {
			return false;
		}
	}
}
