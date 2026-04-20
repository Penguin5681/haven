class ApiConstants {
  static const String baseUrl = 'http://192.168.18.107:8080/api/auth';
  
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
}
