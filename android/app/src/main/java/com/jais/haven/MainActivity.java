package com.jais.haven;

import android.accessibilityservice.AccessibilityServiceInfo;
import android.content.ComponentName;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import android.text.TextUtils;
import android.view.accessibility.AccessibilityManager;

import java.util.List;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
	private static final String SOS_SETUP_CHANNEL = "haven/sos_setup";

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
}
