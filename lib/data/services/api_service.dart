import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../core/config/app_config.dart';

class ApiService {
  static String get baseUrl => AppConfig.apiBaseUrl;
  static Map<String, dynamic>? _cachedUser;

  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_data');
    _cachedUser = null;
  }

  static Future<void> saveUserData(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(user));
    _cachedUser = user;
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    if (_cachedUser != null) return _cachedUser;
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('user_data');
    if (data != null) {
      _cachedUser = jsonDecode(data);
      return _cachedUser;
    }
    return null;
  }

  // Helper class for getting typed current user
  static dynamic get currentUser {
    // This is a bit of a hack since we don't have a shared model here, 
    // but it allows the UI to access .id, .name etc.
    return _UserProxy(_cachedUser);
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> get(String endpoint) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl$endpoint'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('GET $endpoint failed: ${response.statusCode}');
  }

  static Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('$baseUrl$endpoint'), headers: headers, body: jsonEncode(data));
    if (response.statusCode == 200 || response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('POST $endpoint failed: ${response.statusCode}');
  }

  static Future<dynamic> delete(String endpoint) async {
    final headers = await _getHeaders();
    final response = await http.delete(Uri.parse('$baseUrl$endpoint'), headers: headers);
    if (response.statusCode == 200 || response.statusCode == 204) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    throw Exception('DELETE $endpoint failed: ${response.statusCode}');
  }

  static Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.put(Uri.parse('$baseUrl$endpoint'), headers: headers, body: jsonEncode(data));
    if (response.statusCode == 200 || response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('PUT $endpoint failed: ${response.statusCode}');
  }

  // ─── Device ID ────────────────────────────────────────────────────────────

  /// Returns a stable unique identifier for this device/browser.
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    // Check for a previously stored ID first (covers web + any platform)
    final stored = prefs.getString('device_id');
    if (stored != null && stored.isNotEmpty) return stored;

    String deviceId;

    if (kIsWeb) {
      // Web: generate a UUID and persist it in SharedPreferences
      deviceId = _generateUuid();
    } else if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      deviceId = info.id; // stable Android hardware ID
    } else if (Platform.isIOS) {
      final info = await DeviceInfoPlugin().iosInfo;
      deviceId = info.identifierForVendor ?? _generateUuid();
    } else {
      deviceId = _generateUuid();
    }

    await prefs.setString('device_id', deviceId);
    return deviceId;
  }

  /// Simple UUID v4 generator (no external package needed).
  static String _generateUuid() {
    const chars = '0123456789abcdef';
    final buf = StringBuffer();
    for (var i = 0; i < 32; i++) {
      if (i == 8 || i == 12 || i == 16 || i == 20) buf.write('-');
      buf.write(chars[(DateTime.now().microsecondsSinceEpoch + i * 7) % 16]);
    }
    return buf.toString();
  }

  // ─── Login (with device-limit check) ──────────────────────────────────────

  /// Login result type — lets the caller distinguish a device-limit block
  /// from a wrong-password failure without parsing error strings.
  static const String kErrDeviceLimit = 'DEVICE_LIMIT_REACHED';
  static const String kErrDeviceVerificationRequired = 'DEVICE_VERIFICATION_REQUIRED';
  static const int deviceLimit = 2;

  /// Returns the response map on success, or a map with key 'error' on failure.
  /// Callers should check: if (result?['error'] == ApiService.kErrDeviceLimit)
  static Future<Map<String, dynamic>?> login(String username, String password, {String? verificationCode}) async {
    try {
      final deviceId = await getDeviceId();
      final devicePlatform = kIsWeb ? 'web' : 'mobile';

      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'deviceId': deviceId,
          'devicePlatform': devicePlatform,
          'deviceLimit': deviceLimit,
          if (verificationCode != null) 'verificationCode': verificationCode,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['token'] != null) await setToken(data['token']);
        if (data['user'] != null) await saveUserData(data['user']);
        return data;
      }

      if (response.statusCode == 403) {
        final body = jsonDecode(response.body);
        final errorText = (body['error'] ?? '').toString();
        if (errorText.contains('device_limit_reached')) {
          return {'error': kErrDeviceLimit, 'message': body['message'] ?? 'Device limit reached.'};
        }
        if (errorText.contains('verification_required')) {
          return {'error': kErrDeviceVerificationRequired, 'message': body['message'] ?? 'Device verification required.'};
        }
      }

      return null;
    } catch (e) {
      print('Login Error: $e');
      return null;
    }
  }

  /// Removes this device from the user's registered devices on the backend.
  /// Call this on logout so the slot is freed up.
  static Future<void> logoutDevice() async {
    try {
      final deviceId = await getDeviceId();
      await post('/auth/logout-device', {'deviceId': deviceId});
    } catch (_) {}
    await clearToken();
  }

  static Future<bool> updateProfile(String newName) async {
    final token = await getToken();
    if (token == null) return false;

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'name': newName}),
      );

      if (response.statusCode == 200) {
        if (_cachedUser != null) {
          _cachedUser!['name'] = newName;
          await saveUserData(_cachedUser!); // Sync cache to persistent storage
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Update Profile Error: $e');
      return false;
    }
  }

  static Future<bool> markAttendance({
    required String subject,
    required String section,
    String? studentName,
    DateTime? timestamp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/attendance/mark'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'subject': subject,
          'section': section,
          if (studentName != null) 'studentName': studentName,
          if (timestamp != null) 'timestamp': timestamp.toUtc().toIso8601String(),
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Attendance Error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> startSession({
    required String subject,
    required String section,
    bool isEvent = false,
    required int lateThresholdMinutes,
    required int absentThresholdMinutes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/attendance/start'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'subject': subject,
          'section': section,
          'isEvent': isEvent,
          'lateThresholdMinutes': lateThresholdMinutes,
          'absentThresholdMinutes': absentThresholdMinutes,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Start Session Error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getActiveSession(String subject, String section) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/attendance/active?subject=$subject&section=$section'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Get Session Error: $e');
      return null;
    }
  }

  static Future<bool> endSession({
    required String subject,
    required String section,
    required List<Map<String, dynamic>> records,
    String? reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/attendance/end'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'subject': subject,
          'section': section,
          'records': records,
          if (reason != null) 'reason': reason,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('End Session Error: $e');
      return false;
    }
  }

  /// Force-deactivates any lingering active session for the given subject+section.
  /// Used as a fallback when endSession returns false (e.g. session already ended).
  static Future<void> forceEndSession({required String subject, required String section}) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/attendance/force-end'),
        headers: await _getHeaders(),
        body: jsonEncode({'subject': subject, 'section': section}),
      );
    } catch (e) {
      print('Force End Session Error: $e');
    }
  }

  static Future<List<dynamic>> getStudentAttendanceHistory({String? name, String? id}) async {
    try {
      final query = id != null ? 'id=$id' : 'name=$name';
      final response = await http.get(
        Uri.parse('$baseUrl/student/attendance?$query'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('Get Student Attendance History Error: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getTeacherAttendanceHistory(String section) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/teacher/attendance-history?section=$section'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('Get Teacher Attendance History Error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> registerWithResult(Map<String, dynamic> userData) async {
    try {
      print('Attempting to register at: $baseUrl/auth/register');
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      ).timeout(const Duration(seconds: 10));
      
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 201,
        'message': data['message'] ?? 'Unknown error'
      };
    } catch (e) {
      print('Register Error (Full): $e');
      return {
        'success': false,
        'message': e.toString()
      };
    }
  }

  /// Attempts to send a verification email via the backend SMTP path.
  /// Returns a map with 'success' and 'message' keys so the UI can handle
  /// fallback behavior (e.g., Firebase's sendEmailVerification).
  static Future<Map<String, dynamic>> sendVerificationEmail(Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-verification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      return {
        'success': response.statusCode == 200 || response.statusCode == 201,
        'message': data is Map && data['message'] != null ? data['message'] : 'Backend email response status: ${response.statusCode}'
      };
    } catch (e) {
      print('Send Verification Email Error: $e');
      return {
        'success': false,
        'message': e.toString()
      };
    }
  }

  static Future<Map<String, dynamic>> sendDeviceVerificationCode(String email, String idNumber) async {
    try {
      final deviceId = await getDeviceId();
      final devicePlatform = kIsWeb ? 'web' : 'mobile';

      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-device-verification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'idNumber': idNumber,
          'deviceId': deviceId,
          'devicePlatform': devicePlatform,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      return {
        'success': response.statusCode == 200,
        'message': data is Map && data['message'] != null ? data['message'] : 'Unable to send device verification code.'
      };
    } catch (e) {
      print('Send Device Verification Code Error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> verifyDeviceCode({
    required String email,
    required String idNumber,
    required String code,
  }) async {
    try {
      final deviceId = await getDeviceId();
      final devicePlatform = kIsWeb ? 'web' : 'mobile';

      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-device-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'idNumber': idNumber,
          'deviceId': deviceId,
          'devicePlatform': devicePlatform,
          'verificationCode': code,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      if (response.statusCode == 200) {
        return data;
      }
      return {
        'success': false,
        'message': data is Map && data['message'] != null ? data['message'] : 'Verification failed.'
      };
    } catch (e) {
      print('Verify Device Code Error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  static Future<bool> clearStudentDevices(String userId, String idNumber, {String? reason}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/users/$userId/clear-devices'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'idNumber': idNumber,
          if (reason != null) 'reason': reason,
        }),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('Clear Student Devices Error: $e');
      return false;
    }
  }

  static Future<List<dynamic>> getAllUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/users'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('Get Users Error: $e');
      return [];
    }
  }

  static Future<bool> addUser(Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/users'),
        headers: await _getHeaders(),
        body: jsonEncode(userData),
      );
      return response.statusCode == 201;
    } catch (e) {
      print('Add User Error: $e');
      return false;
    }
  }

  static Future<bool> updateUser(String id, Map<String, dynamic> userData) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/users/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(userData),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Update User Error: $e');
      return false;
    }
  }

  static Future<bool> deleteUser(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/users/$id'),
        headers: await _getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Delete User Error: $e');
      return false;
    }
  }

  static Future<int> bulkAddUsers(List<Map<String, dynamic>> users) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/bulk-users'),
        headers: await _getHeaders(),
        body: jsonEncode(users),
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body)['count'];
      } else if (response.statusCode == 207) {
        return jsonDecode(response.body)['insertedCount'];
      }
      return 0;
    } catch (e) {
      print('Bulk Add Users Error: $e');
      return 0;
    }
  }

  static Future<List<dynamic>> getSystemLogs() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/logs'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('Get Logs Error: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getAuditLogs() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/audit-logs'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('Get Audit Logs Error: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getSections() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sections'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('Get Sections Error: $e');
      return [];
    }
  }

  /// Fetches all students whose `section` field matches the given section name.
  /// Used as a fallback when the Section document has an empty `students` array.
  static Future<List<String>> getStudentsBySection(String sectionName) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sections/students?sectionName=${Uri.encodeComponent(sectionName)}'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((s) => s['name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();
      }
      return [];
    } catch (e) {
      print('Get Students By Section Error: $e');
      return [];
    }
  }

  static Future<bool> createSection(Map<String, dynamic> sectionData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sections'),
        headers: await _getHeaders(),
        body: jsonEncode(sectionData),
      );
      return response.statusCode == 201;
    } catch (e) {
      print('Create Section Error: $e');
      return false;
    }
  }

  // --- CONCERNS ---
  static Future<Map<String, dynamic>> getAnalytics() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/teacher/analytics'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      print('Get Analytics Error: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> getStudentAnalytics(String studentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/student-analytics/$studentId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'presentPercent': '0%', 'lates': 0, 'absents': 0};
    } catch (e) {
      print('Get Student Analytics Error: $e');
      return {'presentPercent': '0%', 'lates': 0, 'absents': 0};
    }
  }

  static Future<List<dynamic>> getAcademicYears() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/academic-years'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('Get Academic Years Error: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getConcerns() async {
    try {
      final user = await getUserData();
      if (user == null) return [];
      
      String endpoint = '/concerns';

      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('Get Concerns Error: $e');
      return [];
    }
  }

  static Future<bool> createAcademicYear(String year) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/academic-years'),
        headers: await _getHeaders(),
        body: jsonEncode({'year': year}),
      );
      return response.statusCode == 201;
    } catch (e) {
      print('Create Academic Year Error: $e');
      return false;
    }
  }

  static Future<bool> deleteAcademicYear(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/academic-years/$id'),
        headers: await _getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Delete Academic Year Error: $e');
      return false;
    }
  }

  static Future<bool> changePassword(String userId, String newPassword) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/users/$userId/password'),
        headers: await _getHeaders(),
        body: jsonEncode({'password': newPassword}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Change Password Error: $e');
      return false;
    }
  }

  static Future<bool> submitConcern(Map<String, dynamic> concernData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/student/submit-concern'),
        headers: await _getHeaders(),
        body: jsonEncode(concernData),
      );
      return response.statusCode == 201;
    } catch (e) {
      print('Submit Concern Error: $e');
      return false;
    }
  }

  static Future<String?> uploadDocument(String filePath) async {
    final token = await getToken();
    if (token == null) return null;

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/student/upload-document'));
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var data = jsonDecode(responseData);
        return data['url'];
      }
      return null;
    } catch (e) {
      print('Upload Error: $e');
      return null;
    }
  }

  static Future<bool> updateConcernStatus(String id, String status) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/concerns/$id'),
        headers: await _getHeaders(),
        body: jsonEncode({'status': status}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Update Concern Status Error: $e');
      return false;
    }
  }

  // --- MESSAGING ---
  static Future<List<dynamic>> getChatHistory(String threadId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/messages/$threadId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('Get Chat History Error: $e');
      return [];
    }
  }

  static Future<bool> sendMessage(Map<String, dynamic> messageData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/messages'),
        headers: await _getHeaders(),
        body: jsonEncode(messageData),
      );
      return response.statusCode == 201;
    } catch (e) {
      print('Send Message Error: $e');
      return false;
    }
  }


  static Future<List<dynamic>> getStudentProfessors() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/student/professors'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('Get Student Professors Error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getStudentSectionInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/student/section-info'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Get Student Section Info Error: $e');
      return null;
    }
  }

  static Future<List<dynamic>> getGranularAttendance({
    String? year,
    String? strand,
    String? grade,
    String? section,
    String? term,
    String? termPhase,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (year != null) queryParams['academicYear'] = year;
      if (strand != null) queryParams['strand'] = strand;
      if (grade != null) queryParams['grade'] = grade;
      if (section != null) queryParams['section'] = section;
      if (term != null) queryParams['term'] = term;
      if (termPhase != null) queryParams['termPhase'] = termPhase;

      final uri = Uri.parse('$baseUrl/admin/attendance-history').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: await _getHeaders());
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      print('Granular Attendance Error: $e');
      return [];
    }
  }

  /// Save global/admin configuration settings on the backend.
  /// Returns `true` when the backend acknowledges the update.
  static Future<bool> saveAdminSettings(Map<String, dynamic> settings) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/settings'),
        headers: await _getHeaders(),
        body: jsonEncode(settings),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Save Admin Settings Error: $e');
      return false;
    }
  }
}

class _UserProxy {
  final Map<String, dynamic>? _data;
  _UserProxy(this._data);

  String? get id => _data?['id'];
  String? get name => _data?['name'];
  String? get role => _data?['role'];
  String? get section => _data?['section'];
}