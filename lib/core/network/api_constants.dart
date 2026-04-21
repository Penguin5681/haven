class ApiConstants {
  static const String hostUrl = 'https://haven-backend-671108073568.asia-south2.run.app/api';
  static const String baseUrl = '$hostUrl/auth';
  
  // Women Auth
  static const String signup = '$baseUrl/signup';
  static const String login = '$baseUrl/login';
  static const String googleAuth = '$baseUrl/google';
  static const String profile = '$baseUrl/profile';
  static const String profileFullName = '$baseUrl/profile/full-name';
  static const String profileAadharNumber = '$baseUrl/profile/aadhar-number';
  static const String profilePhoneNumber = '$baseUrl/profile/phone-number';
  static const String profileAddressLine = '$baseUrl/profile/address-line';
  static const String profilePincode = '$baseUrl/profile/pincode';
  static const String profileState = '$baseUrl/profile/state';
  static const String profileDistrict = '$baseUrl/profile/district';
  static const String profilePhoto = '$baseUrl/profile/profile-photo';

  // Authority Auth
  static const String authoritySignup = '$baseUrl/authority/signup';
  static const String authorityLogin = '$baseUrl/authority/login';

  // SOS (Women App)
  static const String sosTrigger = '$hostUrl/sos/trigger';
  static const String sosState = '$hostUrl/sos/state';
  static String sosAudioChunk(String sosId) => '$hostUrl/sos/$sosId/audio-chunk';

  // Authority Dashboard
  static const String authoritySosAlerts = '$hostUrl/authority/sos-alerts';
  static String authoritySosAlertDetails(String sosId) => '$hostUrl/authority/sos-alerts/$sosId';
  static String authoritySosAlertStatus(String sosId) => '$hostUrl/authority/sos-alerts/$sosId/status';
}
