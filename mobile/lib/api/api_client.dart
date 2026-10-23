import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// One place that talks to the FastAPI server.
class Api {
  Api._();
  static final Api instance = Api._();

  static const _kBaseUrl = 'base_url';
  static const _kToken = 'token';
  static const _kUser = 'user';

  late SharedPreferences _prefs;
  String baseUrl = '';
  String? token;
  AppUser? user;

  /// Called whenever the server says our login expired.
  VoidCallback? onUnauthorized;

  /// Sensible default per platform. A real phone must use the PC's Wi-Fi IP.
  /// Server address baked in at build time: flutter build apk --dart-define=API_URL=https://...
  static const _builtInUrl = String.fromEnvironment('API_URL');

  static String get defaultBaseUrl {
    if (_builtInUrl.isNotEmpty) return _builtInUrl;
    if (kIsWeb) {
      // Served by the API server itself at /app/ — same address, also through a public link.
      if (Uri.base.path.startsWith('/app')) return Uri.base.origin;
      return 'http://${Uri.base.host}:8000';
    }
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000'; // Android emulator → PC
    return 'http://localhost:8000'; // iOS simulator
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    baseUrl = _prefs.getString(_kBaseUrl) ?? defaultBaseUrl;
    token = _prefs.getString(_kToken);
    final u = _prefs.getString(_kUser);
    if (u != null) user = AppUser.fromJson(jsonDecode(u));
  }

  bool get isLoggedIn => token != null;

  Future<void> setBaseUrl(String url) async {
    var u = url.trim();
    if (!u.startsWith('http')) u = 'http://$u';
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    baseUrl = u;
    await _prefs.setString(_kBaseUrl, u);
  }

  String imageUrl(String? path) => path == null ? '' : '$baseUrl$path';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    http.Response res;
    try {
      // Long timeout: a free online server can take up to a minute to wake up.
      res = await call().timeout(const Duration(seconds: 75));
    } catch (_) {
      throw ApiException('Cannot reach the server at $baseUrl.\nCheck the server is running and the address in Settings.');
    }
    final body = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    if (res.statusCode == 401 && token != null) {
      await logout();
      onUnauthorized?.call();
    }
    throw ApiException(_errorText(body), res.statusCode);
  }

  String _errorText(dynamic body) {
    final d = body is Map ? body['detail'] : null;
    if (d is String) return d;
    if (d is List && d.isNotEmpty) {
      final msg = (d.first['msg'] ?? 'Invalid input').toString().replaceFirst('Value error, ', '');
      final field = (d.first['loc'] as List?)?.last;
      return field is String && !msg.toLowerCase().contains(field) ? '$field: $msg' : msg;
    }
    return 'Something went wrong';
  }

  Future<dynamic> get(String path, [Map<String, String>? q]) => _send(() => http.get(_uri(path, q), headers: _headers));
  Future<dynamic> post(String path, [Object? body]) =>
      _send(() => http.post(_uri(path), headers: _headers, body: body == null ? null : jsonEncode(body)));
  Future<dynamic> put(String path, Object body) =>
      _send(() => http.put(_uri(path), headers: _headers, body: jsonEncode(body)));
  Future<dynamic> patch(String path, Object body) =>
      _send(() => http.patch(_uri(path), headers: _headers, body: jsonEncode(body)));
  Future<dynamic> delete(String path) => _send(() => http.delete(_uri(path), headers: _headers));

  Future<dynamic> multipart(String method, String path, Map<String, String> fields,
      {Uint8List? imageBytes, String? imageName}) {
    return _send(() async {
      final req = http.MultipartRequest(method, _uri(path))..fields.addAll(fields);
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      if (imageBytes != null) {
        req.files.add(http.MultipartFile.fromBytes('image', imageBytes, filename: imageName ?? 'photo.jpg'));
      }
      return http.Response.fromStream(await req.send());
    });
  }

  // ---------------- Auth ----------------
  Future<void> _saveSession(Map<String, dynamic> j) async {
    token = j['access_token'];
    user = AppUser.fromJson(j['user']);
    await _prefs.setString(_kToken, token!);
    await _prefs.setString(_kUser, jsonEncode(j['user']));
  }

  Future<void> login(String username, String password) async =>
      _saveSession(await post('/auth/login', {'username': username, 'password': password}));

  Future<void> register(String username, String password, String boutique, String? phone) async =>
      _saveSession(await post('/auth/register', {
        'username': username,
        'password': password,
        'boutique_name': boutique,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      }));

  Future<void> logout() async {
    token = null;
    user = null;
    await _prefs.remove(_kToken);
    await _prefs.remove(_kUser);
  }

  Future<bool> ping() async {
    try {
      await get('/');
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------- Cloths ----------------
  Future<List<Cloth>> cloths({String? q, String? status}) async {
    final list = await get('/cloths', {
      if (q != null && q.isNotEmpty) 'q': q,
      'status': ?status,
    }) as List;
    return list.map((e) => Cloth.fromJson(e)).toList();
  }

  Future<Cloth> clothByCode(String code) async => Cloth.fromJson(await get('/cloths/code/${Uri.encodeComponent(code)}'));
  Future<Cloth> cloth(int id) async => Cloth.fromJson(await get('/cloths/$id'));

  Future<Cloth> saveCloth({
    int? id,
    required Map<String, String> fields,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    final j = await multipart(id == null ? 'POST' : 'PUT', id == null ? '/cloths' : '/cloths/$id', fields,
        imageBytes: imageBytes, imageName: imageName);
    return Cloth.fromJson(j);
  }

  Future<void> deleteCloth(int id) => delete('/cloths/$id');

  // ---------------- Rentals ----------------
  Future<Rental> createRental(int clothId, Map<String, dynamic> body) async =>
      Rental.fromJson(await post('/cloths/$clothId/rentals', body));
  Future<Rental> updateRental(int id, Map<String, dynamic> body) async => Rental.fromJson(await put('/rentals/$id', body));
  /// [depositReturned] null = decide about the deposit later.
  Future<Rental> markReturned(int id, {bool collectBalance = true, double? depositReturned, String? depositNote}) async =>
      Rental.fromJson(await post('/rentals/$id/return', {
        'collect_balance': collectBalance,
        'deposit_returned': depositReturned,
        'deposit_note': depositNote,
      }));
  /// Private invoice page link for a booking: (full url, invoice number).
  Future<(String, String)> invoiceLink(int rentalId) async {
    final j = await post('/rentals/$rentalId/invoice-link');
    return ('$baseUrl${j['path']}', j['number'] as String);
  }
  Future<Rental> settleDeposit(int id, double returned, String? note) async =>
      Rental.fromJson(await post('/rentals/$id/deposit', {'deposit_returned': returned, 'deposit_note': note}));
  Future<List<CustomerSummary>> customers(String q) async =>
      ((await get('/customers', {'q': q})) as List).map((e) => CustomerSummary.fromJson(e)).toList();
  Future<CustomerDetail> customer(String key) async => CustomerDetail.fromJson(await get('/customers/detail', {'key': key}));
  Future<Earnings> earnings(DateTime start, DateTime end) async =>
      Earnings.fromJson(await get('/earnings', {'start': apiDate(start), 'end': apiDate(end)}));
  Future<void> deleteRental(int id) => delete('/rentals/$id');

  Future<List<Rental>> rentals(DateTime start, DateTime end) async {
    final list = await get('/rentals', {'start': apiDate(start), 'end': apiDate(end)}) as List;
    return list.map((e) => Rental.fromJson(e)).toList();
  }

  Future<Dashboard> dashboard() async => Dashboard.fromJson(await get('/dashboard'));

  // ---------------- Inquiries (waitlist) ----------------
  List<Inquiry> _inquiries(dynamic list) => (list as List).map((e) => Inquiry.fromJson(e)).toList();

  Future<List<Inquiry>> inquiries(int clothId) async => _inquiries(await get('/cloths/$clothId/inquiries'));
  Future<Inquiry> createInquiry(int clothId, Map<String, dynamic> body) async =>
      Inquiry.fromJson(await post('/cloths/$clothId/inquiries', body));
  Future<Inquiry> updateInquiry(int id, Map<String, dynamic> body) async =>
      Inquiry.fromJson(await put('/inquiries/$id', body));
  Future<Inquiry> setInquiryStatus(int id, String status) async =>
      Inquiry.fromJson(await patch('/inquiries/$id/status', {'status': status}));
  Future<void> deleteInquiry(int id) => delete('/inquiries/$id');

  /// People who want [clothId] for (part of) start..end — after a cancellation or early return.
  Future<List<Inquiry>> matchingInquiries(int clothId, DateTime start, DateTime end) async =>
      _inquiries(await get('/inquiries/matching', {'cloth_id': '$clothId', 'start': apiDate(start), 'end': apiDate(end)}));

  Future<List<Inquiry>> readyInquiries() async => _inquiries(await get('/inquiries/ready'));

  // ---------------- Customer (no login) ----------------
  Future<String> publicNotifyMe(String boutique, String code, Map<String, dynamic> body) async {
    final j = await post(
        '/public/${Uri.encodeComponent(boutique.trim())}/cloths/${Uri.encodeComponent(code.trim())}/inquiries', body);
    return j['message'] as String;
  }

  Future<PublicCloth> publicCloth(String boutique, String code) async => PublicCloth.fromJson(
      await get('/public/${Uri.encodeComponent(boutique.trim())}/cloths/${Uri.encodeComponent(code.trim())}'));
}

/// The server stores the boutique's local time without a timezone.
String apiDate(DateTime d) => d.toIso8601String().split('.').first;
