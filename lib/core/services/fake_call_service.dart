import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeCallSettings {
  final int normalDelaySeconds;
  final int angryDelaySeconds;
  final int angryRepeatCount;
  final String fakeCallerName;
  final String fakeCallerNumber;
  final String? trustedContactId;

  const FakeCallSettings({
    required this.normalDelaySeconds,
    required this.angryDelaySeconds,
    required this.angryRepeatCount,
    required this.fakeCallerName,
    required this.fakeCallerNumber,
    this.trustedContactId,
  });

  static const FakeCallSettings defaults = FakeCallSettings(
    normalDelaySeconds: 10,
    angryDelaySeconds: 20,
    angryRepeatCount: 3,
    fakeCallerName: 'Private Contact',
    fakeCallerNumber: '9999999999',
    trustedContactId: null,
  );

  FakeCallSettings copyWith({
    int? normalDelaySeconds,
    int? angryDelaySeconds,
    int? angryRepeatCount,
    String? fakeCallerName,
    String? fakeCallerNumber,
    String? trustedContactId,
  }) {
    return FakeCallSettings(
      normalDelaySeconds: normalDelaySeconds ?? this.normalDelaySeconds,
      angryDelaySeconds: angryDelaySeconds ?? this.angryDelaySeconds,
      angryRepeatCount: angryRepeatCount ?? this.angryRepeatCount,
      fakeCallerName: fakeCallerName ?? this.fakeCallerName,
      fakeCallerNumber: fakeCallerNumber ?? this.fakeCallerNumber,
      trustedContactId: trustedContactId ?? this.trustedContactId,
    );
  }
}

class FakeCallService {
  FakeCallService._();

  static const MethodChannel _channel = MethodChannel('haven/fake_call');

  static const String _keyNormalDelay = 'fake_call.normal_delay_seconds';
  static const String _keyAngryDelay = 'fake_call.angry_delay_seconds';
  static const String _keyAngryRepeat = 'fake_call.angry_repeat_count';
  static const String _keyCallerName = 'fake_call.caller_name';
  static const String _keyCallerNumber = 'fake_call.caller_number';
  static const String _keyTrustedContactId = 'fake_call.trusted_contact_id';

  static Future<FakeCallSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return FakeCallSettings(
      normalDelaySeconds: prefs.getInt(_keyNormalDelay) ?? FakeCallSettings.defaults.normalDelaySeconds,
      angryDelaySeconds: prefs.getInt(_keyAngryDelay) ?? FakeCallSettings.defaults.angryDelaySeconds,
      angryRepeatCount: prefs.getInt(_keyAngryRepeat) ?? FakeCallSettings.defaults.angryRepeatCount,
      fakeCallerName: prefs.getString(_keyCallerName) ?? FakeCallSettings.defaults.fakeCallerName,
      fakeCallerNumber: prefs.getString(_keyCallerNumber) ?? FakeCallSettings.defaults.fakeCallerNumber,
      trustedContactId: prefs.getString(_keyTrustedContactId),
    );
  }

  static Future<void> saveSettings(FakeCallSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyNormalDelay, settings.normalDelaySeconds);
    await prefs.setInt(_keyAngryDelay, settings.angryDelaySeconds);
    await prefs.setInt(_keyAngryRepeat, settings.angryRepeatCount);
    await prefs.setString(_keyCallerName, settings.fakeCallerName);
    await prefs.setString(_keyCallerNumber, settings.fakeCallerNumber);
    if (settings.trustedContactId != null) {
      await prefs.setString(_keyTrustedContactId, settings.trustedContactId!);
    } else {
      await prefs.remove(_keyTrustedContactId);
    }
  }

  static Future<bool> scheduleNormalFakeCall(FakeCallSettings settings) async {
    return await _channel.invokeMethod<bool>(
          'scheduleNormalFakeCall',
          <String, dynamic>{
            'delaySeconds': settings.normalDelaySeconds,
            'callerName': settings.fakeCallerName,
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
            'callerName': settings.fakeCallerName,
            'phoneNumber': settings.fakeCallerNumber,
          },
        ) ??
        false;
  }

  static Future<bool> stopAngryFatherMode() async {
    return await _channel.invokeMethod<bool>('stopAngryFatherMode') ?? false;
  }
}
