import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeCallSettings {
  final int normalDelaySeconds;
  final int angryDelaySeconds;
  final int angryRepeatCount;
  final String fakeCallerNumber;

  const FakeCallSettings({
    required this.normalDelaySeconds,
    required this.angryDelaySeconds,
    required this.angryRepeatCount,
    required this.fakeCallerNumber,
  });

  static const FakeCallSettings defaults = FakeCallSettings(
    normalDelaySeconds: 10,
    angryDelaySeconds: 20,
    angryRepeatCount: 3,
    fakeCallerNumber: '9999999999',
  );

  FakeCallSettings copyWith({
    int? normalDelaySeconds,
    int? angryDelaySeconds,
    int? angryRepeatCount,
    String? fakeCallerNumber,
  }) {
    return FakeCallSettings(
      normalDelaySeconds: normalDelaySeconds ?? this.normalDelaySeconds,
      angryDelaySeconds: angryDelaySeconds ?? this.angryDelaySeconds,
      angryRepeatCount: angryRepeatCount ?? this.angryRepeatCount,
      fakeCallerNumber: fakeCallerNumber ?? this.fakeCallerNumber,
    );
  }
}

class FakeCallService {
  FakeCallService._();

  static const MethodChannel _channel = MethodChannel('haven/fake_call');

  static const String _keyNormalDelay = 'fake_call.normal_delay_seconds';
  static const String _keyAngryDelay = 'fake_call.angry_delay_seconds';
  static const String _keyAngryRepeat = 'fake_call.angry_repeat_count';
  static const String _keyCallerNumber = 'fake_call.caller_number';

  static Future<FakeCallSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return FakeCallSettings(
      normalDelaySeconds: prefs.getInt(_keyNormalDelay) ?? FakeCallSettings.defaults.normalDelaySeconds,
      angryDelaySeconds: prefs.getInt(_keyAngryDelay) ?? FakeCallSettings.defaults.angryDelaySeconds,
      angryRepeatCount: prefs.getInt(_keyAngryRepeat) ?? FakeCallSettings.defaults.angryRepeatCount,
      fakeCallerNumber: prefs.getString(_keyCallerNumber) ?? FakeCallSettings.defaults.fakeCallerNumber,
    );
  }

  static Future<void> saveSettings(FakeCallSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyNormalDelay, settings.normalDelaySeconds);
    await prefs.setInt(_keyAngryDelay, settings.angryDelaySeconds);
    await prefs.setInt(_keyAngryRepeat, settings.angryRepeatCount);
    await prefs.setString(_keyCallerNumber, settings.fakeCallerNumber);
  }

  static Future<bool> scheduleNormalFakeCall(FakeCallSettings settings) async {
    return await _channel.invokeMethod<bool>(
          'scheduleNormalFakeCall',
          <String, dynamic>{
            'delaySeconds': settings.normalDelaySeconds,
            'phoneNumber': settings.fakeCallerNumber,
          },
        ) ??
        false;
  }

  static Future<bool> startAngryFatherMode(FakeCallSettings settings) async {
    return await _channel.invokeMethod<bool>(
          'startAngryFatherMode',
          <String, dynamic>{
            'delaySeconds': settings.angryDelaySeconds,
            'repeatCount': settings.angryRepeatCount,
            'phoneNumber': settings.fakeCallerNumber,
          },
        ) ??
        false;
  }

  static Future<bool> stopAngryFatherMode() async {
    return await _channel.invokeMethod<bool>('stopAngryFatherMode') ?? false;
  }
}
