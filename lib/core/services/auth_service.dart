import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_constants.dart';

class AuthService {
  static const String _authProviderKey = 'auth_provider';

  static final AuthService instance = AuthService._internal();

  AuthService._internal();

  Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    String? role,
  }) async {
    final uri = Uri.parse(ApiConstants.signup);
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    );

    return _handleJsonResponse(
      method: 'POST',
      uri: uri,
      response: response,
      onSuccess: (decoded) async {
        final token = decoded['token']?.toString();
        if (token != null && token.isNotEmpty) {
          await saveToken(token, role: role);
        }
        await _saveAuthProvider('local');
      },
    );
  }

  Future<Map<String, dynamic>> login(
    String email,
    String password, {
    String? role,
  }) async {
    final uri = Uri.parse(ApiConstants.login);
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    );

    return _handleJsonResponse(
      method: 'POST',
      uri: uri,
      response: response,
      onSuccess: (decoded) async {
        final token = decoded['token']?.toString();
        if (token != null && token.isNotEmpty) {
          await saveToken(token, role: role);
        }
        final provider = decoded['user'] is Map<String, dynamic>
            ? (decoded['user']['auth_provider']?.toString() ?? 'local')
            : 'local';
        await _saveAuthProvider(provider);
      },
    );
  }

  Future<Map<String, dynamic>> googleAuth({
    required String email,
    required String fullName,
    String? profilePhotoUrl,
    String? role,
  }) async {
    final uri = Uri.parse(ApiConstants.googleAuth);
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'full_name': fullName.trim(),
        'profile_photo_url': (profilePhotoUrl ?? '').trim(),
      }),
    );

    return _handleJsonResponse(
      method: 'POST',
      uri: uri,
      response: response,
      onSuccess: (decoded) async {
        final token = decoded['token']?.toString();
        if (token != null && token.isNotEmpty) {
          await saveToken(token, role: role);
        }
        await _saveAuthProvider('google');
      },
    );
  }

  Future<Map<String, dynamic>> getProfile() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No token found');
    }

    final uri = Uri.parse(ApiConstants.profile);
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final decoded = await _handleJsonResponse(
      method: 'GET',
      uri: uri,
      response: response,
    );
    return (decoded['profile'] is Map<String, dynamic>)
        ? decoded['profile'] as Map<String, dynamic>
        : decoded;
  }

  Future<Map<String, dynamic>> updateProfile({
    String? aadharNumber,
    String? fullName,
    String? phoneNumber,
    String? addressLine,
    String? pincode,
    String? state,
    String? district,
    File? profilePhoto,
  }) async {
    final updates = <Future<void>>[];

    if ((fullName ?? '').trim().isNotEmpty) {
      updates.add(updateFullName(fullName!.trim()));
    }
    if ((aadharNumber ?? '').trim().isNotEmpty) {
      updates.add(updateAadharNumber(aadharNumber!.trim()));
    }
    if ((phoneNumber ?? '').trim().isNotEmpty) {
      updates.add(updatePhoneNumber(phoneNumber!.trim()));
    }
    if ((addressLine ?? '').trim().isNotEmpty) {
      updates.add(updateAddressLine(addressLine!.trim()));
    }
    if ((pincode ?? '').trim().isNotEmpty) {
      updates.add(updatePincode(pincode!.trim()));
    }
    if ((state ?? '').trim().isNotEmpty) {
      updates.add(updateState(state!.trim()));
    }
    if ((district ?? '').trim().isNotEmpty) {
      updates.add(updateDistrict(district!.trim()));
    }
    if (profilePhoto != null) {
      updates.add(updateProfilePhoto(profilePhoto));
    }

    if (updates.isEmpty) {
      throw Exception('No changes to save.');
    }

    for (final update in updates) {
      await update;
    }

    final refreshed = await getProfile();
    return {'message': 'Profile updated successfully', 'user': refreshed};
  }

  Future<Map<String, dynamic>> updateFullName(String fullName) {
    return _patchJson(
      endpoint: ApiConstants.profileFullName,
      field: 'full_name',
      value: fullName,
    );
  }

  Future<Map<String, dynamic>> updateAadharNumber(String aadharNumber) {
    return _patchJson(
      endpoint: ApiConstants.profileAadharNumber,
      field: 'aadhar_number',
      value: aadharNumber,
    );
  }

  Future<Map<String, dynamic>> updatePhoneNumber(String phoneNumber) {
    return _patchJson(
      endpoint: ApiConstants.profilePhoneNumber,
      field: 'phone_number',
      value: phoneNumber,
    );
  }

  Future<Map<String, dynamic>> updateAddressLine(String addressLine) {
    return _patchJson(
      endpoint: ApiConstants.profileAddressLine,
      field: 'address_line',
      value: addressLine,
    );
  }

  Future<Map<String, dynamic>> updatePincode(String pincode) {
    return _patchJson(
      endpoint: ApiConstants.profilePincode,
      field: 'pincode',
      value: pincode,
    );
  }

  Future<Map<String, dynamic>> updateState(String stateName) {
    return _patchJson(
      endpoint: ApiConstants.profileState,
      field: 'state',
      value: stateName,
    );
  }

  Future<Map<String, dynamic>> updateDistrict(String district) {
    return _patchJson(
      endpoint: ApiConstants.profileDistrict,
      field: 'district',
      value: district,
    );
  }

  Future<Map<String, dynamic>> updateProfilePhoto(File profilePhoto) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No token found');
    }

    final uri = Uri.parse(ApiConstants.profilePhoto);
    final request = http.MultipartRequest('PATCH', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(
        await http.MultipartFile.fromPath('profile_photo', profilePhoto.path),
      );

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();

    _debugLog(
      method: 'PATCH',
      uri: uri,
      statusCode: streamed.statusCode,
      responseBody: body,
    );

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception(_extractErrorMessage(body, streamed.statusCode));
    }

    final dynamic decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {'message': body};
  }

  bool isProfileComplete(Map<String, dynamic> profile) {
    const requiredKeys = <String>[
      'aadhar_number',
      'full_name',
      'phone_number',
      'address_line',
      'pincode',
      'state',
      'district',
    ];

    for (final key in requiredKeys) {
      final value = profile[key];
      if (value == null || value.toString().trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  Future<void> saveToken(String token, {String? role}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    if (role != null) {
      await prefs.setString('user_role', role);
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }

  Future<String?> getAuthProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authProviderKey);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_role');
    await prefs.remove(_authProviderKey);
  }

  Future<Map<String, dynamic>> _patchJson({
    required String endpoint,
    required String field,
    required String value,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No token found');
    }

    final uri = Uri.parse(endpoint);
    final response = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({field: value}),
    );

    return _handleJsonResponse(method: 'PATCH', uri: uri, response: response);
  }

  Future<void> _saveAuthProvider(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authProviderKey, provider);
  }

  Future<Map<String, dynamic>> _handleJsonResponse({
    required String method,
    required Uri uri,
    required http.Response response,
    Future<void> Function(Map<String, dynamic> decoded)? onSuccess,
  }) async {
    _debugLog(
      method: method,
      uri: uri,
      statusCode: response.statusCode,
      responseBody: response.body,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response.body, response.statusCode));
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected server response.');
    }

    if (onSuccess != null) {
      await onSuccess(decoded);
    }

    return decoded;
  }

  String _extractErrorMessage(String responseBody, int statusCode) {
    if (responseBody.isEmpty) {
      return 'HTTP Error $statusCode';
    }

    try {
      final dynamic decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'] ?? decoded['error'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }
      }
    } catch (_) {
      // Keep fallback below for non-JSON responses.
    }

    return responseBody.length > 500
        ? '${responseBody.substring(0, 500)}...'
        : responseBody;
  }

  void _debugLog({
    required String method,
    required Uri uri,
    required int statusCode,
    required String responseBody,
  }) {
    debugPrint('--- AUTH SERVICE $method ${uri.toString()} ---');
    debugPrint('Status Code: $statusCode');
    debugPrint('Response Body: $responseBody');
    debugPrint('-------------------------------------------');
  }
}
