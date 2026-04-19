import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_constants.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  Future<Map<String, dynamic>> signup({
    required String aadharNumber,
    required String fullName,
    required String email,
    required String phoneNumber,
    required File profilePhoto,
    required String addressLine,
    required String pincode,
    required String state,
    required String district,
    required String password,
  }) async {
    final uri = Uri.parse(ApiConstants.signup);
    var request = http.MultipartRequest('POST', uri);

    request.fields['aadhar_number'] = aadharNumber;
    request.fields['full_name'] = fullName;
    request.fields['email'] = email;
    request.fields['phone_number'] = phoneNumber;
    request.fields['address_line'] = addressLine;
    request.fields['pincode'] = pincode;
    request.fields['state'] = state;
    request.fields['district'] = district;
    request.fields['password'] = password;

    var multipartFile = await http.MultipartFile.fromPath(
      'profile_photo',
      profilePhoto.path,
    );
    request.files.add(multipartFile);

    var response = await request.send();
    var responseBody = await response.stream.bytesToString();
    
    debugPrint('--- AUTH SERVICE POST ${uri.toString()} ---');
    debugPrint('Status Code: ${response.statusCode}');
    debugPrint('Response Body: $responseBody');
    debugPrint('-------------------------------------------');
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(responseBody);
    } else {
      String errorMessage = 'Unknown error occurred';
      try {
        final dynamic decoded = json.decode(responseBody);
        if (decoded is Map<String, dynamic>) {
          errorMessage = decoded['message'] ?? decoded['error'] ?? responseBody;
        } else {
          errorMessage = responseBody;
        }
      } catch (_) {
        // If response is not JSON (e.g., 502 HTML from reverse proxy)
        if (responseBody.isNotEmpty) {
          // Truncate if it's a huge HTML page
          errorMessage = responseBody.length > 500 
              ? '${responseBody.substring(0, 500)}...' 
              : responseBody;
        } else {
          errorMessage = 'HTTP Error ${response.statusCode}';
        }
      }
      
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> login(String email, String password, {String? role}) async {
    final uri = Uri.parse(ApiConstants.login);
    
    var response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'password': password,
      }),
    );

    var responseBody = response.body;

    debugPrint('--- AUTH SERVICE POST ${uri.toString()} ---');
    debugPrint('Status Code: ${response.statusCode}');
    debugPrint('Response Body: $responseBody');
    debugPrint('-------------------------------------------');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = json.decode(responseBody);
      if (decoded['token'] != null) {
        await saveToken(decoded['token'], role: role);
      }
      return decoded;
    } else {
      String errorMessage = 'Unknown error occurred';
      try {
        final dynamic decoded = json.decode(responseBody);
        if (decoded is Map<String, dynamic>) {
          errorMessage = decoded['message'] ?? decoded['error'] ?? responseBody;
        } else {
          errorMessage = responseBody;
        }
      } catch (_) {
        if (responseBody.isNotEmpty) {
          errorMessage = responseBody.length > 500
              ? '${responseBody.substring(0, 500)}...'
              : responseBody;
        } else {
          errorMessage = 'HTTP Error ${response.statusCode}';
        }
      }
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    final token = await getToken();
    if (token == null) throw Exception('No token found');

    final uri = Uri.parse(ApiConstants.profile);
    
    var response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    var responseBody = response.body;

    debugPrint('--- AUTH SERVICE GET ${uri.toString()} ---');
    debugPrint('Status Code: ${response.statusCode}');
    debugPrint('Response Body: $responseBody');
    debugPrint('-------------------------------------------');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = json.decode(responseBody);
      return decoded['profile'] ?? decoded;
    } else {
      String errorMessage = 'Unknown error occurred';
      try {
        final dynamic decoded = json.decode(responseBody);
        if (decoded is Map<String, dynamic>) {
          errorMessage = decoded['message'] ?? decoded['error'] ?? responseBody;
        } else {
          errorMessage = responseBody;
        }
      } catch (_) {
        if (responseBody.isNotEmpty) {
          errorMessage = responseBody.length > 500
              ? '${responseBody.substring(0, 500)}...'
              : responseBody;
        } else {
          errorMessage = 'HTTP Error ${response.statusCode}';
        }
      }
      throw Exception(errorMessage);
    }
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

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_role');
  }
}
