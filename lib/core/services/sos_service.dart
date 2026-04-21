import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

import '../network/api_constants.dart';
import 'auth_service.dart';

class SosService {
  static final SosService instance = SosService._internal();

  SosService._internal();

  String? currentSosId;

  Future<Map<String, dynamic>> triggerSos() async {
    final token = await AuthService.instance.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated. Cannot trigger SOS.');
    }

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (e) {
      debugPrint('Failed to get location for SOS: $e');
    }

    final uri = Uri.parse(ApiConstants.sosTrigger);
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'latitude': position?.latitude ?? 0.0,
        'longitude': position?.longitude ?? 0.0,
        'accuracy': position?.accuracy ?? 0.0,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      currentSosId = decoded['sos_id'];
      final prefs = await SharedPreferences.getInstance();
      if (currentSosId != null) {
        await prefs.setString('active_sos_id', currentSosId!);
      }
      return decoded;
    } else {
      throw Exception('Failed to trigger SOS: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> uploadAudioChunk(int chunkIndex, String filePath) async {
    final token = await AuthService.instance.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated. Cannot upload audio chunk.');
    }

    if (currentSosId == null) {
      final prefs = await SharedPreferences.getInstance();
      currentSosId = prefs.getString('active_sos_id');
    }

    if (currentSosId == null) {
      throw Exception('No active SOS session to upload chunks.');
    }

    final uri = Uri.parse(ApiConstants.sosAudioChunk(currentSosId!));
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['chunk_index'] = chunkIndex.toString()
      ..files.add(
        await http.MultipartFile.fromPath('audio_file', filePath),
      );

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      return jsonDecode(body);
    } else {
      throw Exception('Failed to upload chunk: $body');
    }
  }

  Future<List<dynamic>> getActiveSosAlerts() async {
    final token = await AuthService.instance.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated as authority.');
    }

    final uri = Uri.parse(ApiConstants.authoritySosAlerts);
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      return decoded['alerts'] ?? [];
    } else {
      throw Exception('Failed to get SOS alerts: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getSosDetails(String sosId) async {
    final token = await AuthService.instance.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated as authority.');
    }

    final uri = Uri.parse(ApiConstants.authoritySosAlertDetails(sosId));
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get SOS details: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateSosStatus(
    String sosId, {
    required String status,
    String? assignedUnitId,
    String? comment,
  }) async {
    final token = await AuthService.instance.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated as authority.');
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'status': status,
    };

    if (assignedUnitId != null && assignedUnitId.trim().isNotEmpty) {
      payload['assigned_unit_id'] = assignedUnitId.trim();
    }

    if (comment != null && comment.trim().isNotEmpty) {
      payload['comment'] = comment.trim();
    }

    final uri = Uri.parse(ApiConstants.authoritySosAlertStatus(sosId));
    final response = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update SOS status: ${response.body}');
    }
  }
}
