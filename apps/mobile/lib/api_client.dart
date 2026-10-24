import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:masaren/models.dart';

class ApiClient {
  /// Backend base URL. Override at build time with
  /// `--dart-define=API_BASE_URL=https://your.server`.
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://masareen.com',
  );

  ApiClient({String baseUrl = defaultBaseUrl}) : _base = _clean(baseUrl);

  static String _clean(String v) => v.trim().replaceAll(RegExp(r'/+$'), '');

  String _base;
  String get baseUrl => _base;
  set baseUrl(String v) => _base = _clean(v);

  String? _token;
  void setToken(String? token) => _token = token;
  String? get token => _token;

  String? _userId;
  String? get userId => _userId;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<dynamic> get(String path, [Map<String, dynamic>? query]) async {
    final stringQuery = query?.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    final uri = Uri.parse('$_base$path').replace(queryParameters: stringQuery);
    final res = await http.get(uri, headers: _headers);
    return _unwrap(res);
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final res = await http.post(
      Uri.parse('$_base$path'),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _unwrap(res);
  }

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) async {
    final res = await http.patch(
      Uri.parse('$_base$path'),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _unwrap(res);
  }

  Future<dynamic> multipart(String path,
      {required String field,
      required List<int> bytes,
      required String filename,
      required String contentType}) async {
    final uri = Uri.parse('$_base$path');
    final request = http.MultipartRequest('POST', uri);
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    request.files.add(http.MultipartFile.fromBytes(field, bytes,
        filename: filename, contentType: MediaType.parse(contentType)));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _unwrap(res);
  }

  dynamic _unwrap(http.Response res) {
    final raw = utf8.decode(res.bodyBytes, allowMalformed: true);
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      final preview = raw.length > 200 ? raw.substring(0, 200) : raw;
      throw ApiException(res.statusCode, preview.isNotEmpty ? preview : 'Server returned non-JSON (status ${res.statusCode})');
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (decoded is Map && decoded.containsKey('data')) return decoded['data'];
      return decoded;
    }
    final msg = decoded is Map ? decoded['message'] ?? decoded['detail'] : null;
    throw ApiException(res.statusCode, msg?.toString() ?? 'Request failed');
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String? message;
  @override
  String toString() => message ?? 'ApiException($statusCode)';
}

final api = ApiClient();

class AuthApi {
  static String? get userId => api.userId;

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await api.post('/api/v1/auth/login', {
      'email': email,
      'password': password,
    });
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> register(Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/users/register', body);
    return data as Map<String, dynamic>;
  }

  static Future<User> me() async {
    final data = await api.get('/api/v1/users/me');
    final user = User.fromJson(data as Map<String, dynamic>);
    api._userId = user.id;
    return user;
  }

  // ── Feed / Posts ────────────────────────────────────────────────────────
  static Future<List<Post>> feed({
    String? authorId,
    String? kind,
    String mode = 'for_you',
    int limit = 40,
    int offset = 0,
  }) async {
    final query = <String, dynamic>{'limit': limit, 'offset': offset, 'mode': mode};
    if (authorId != null) query['author_id'] = authorId;
    if (kind != null) query['kind'] = kind;
    final data = await api.get('/api/v1/posts', query);
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Map<String, dynamic>> rateImpact(
    String postId, {
    required int stars,
    List<String> categories = const [],
    String? note,
  }) async {
    final data = await api.post('/api/v1/posts/$postId/impact', {
      'stars': stars,
      'categories': categories,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    return data as Map<String, dynamic>;
  }

  static Future<List<Comment>> comments(String postId) async {
    final data = await api.get('/api/v1/posts/$postId/comments');
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => Comment.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Map<String, dynamic>> share(String postId) async {
    final data = await api.post('/api/v1/posts/$postId/share');
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> toggleFollow(String userId) async {
    final data = await api.post('/api/v1/users/$userId/follow');
    return data as Map<String, dynamic>;
  }

  static Future<Post> createPost(Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/posts', body);
    return Post.fromJson(data as Map<String, dynamic>);
  }

  static Future<Map<String, dynamic>> toggleLike(String postId) async {
    final data = await api.post('/api/v1/posts/$postId/like');
    return data as Map<String, dynamic>;
  }

  static Future<Comment> comment(String postId, String text) async {
    final data = await api.post('/api/v1/posts/$postId/comment', {'text': text});
    return Comment.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<Opportunity>> opportunities() async {
    final data = await api.get('/api/v1/opportunities/');
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => Opportunity.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<Program>> programs() async {
    final data = await api.get('/api/v1/programs/');
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => Program.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Profile ──────────────────────────────────────────────────────────────
  static Future<User> updateProfile(Map<String, dynamic> body) async {
    final data = await api.patch('/api/v1/users/me/profile', body);
    return User.fromJson(data as Map<String, dynamic>);
  }

  static Future<String> uploadAvatar(
      List<int> bytes, String filename, String contentType) async {
    final data =
        await api.multipart('/api/v1/users/me/avatar',
            field: 'file',
            bytes: bytes,
            filename: filename,
            contentType: contentType);
    return (data as Map<String, dynamic>)['avatar_url'] as String;
  }

  static Future<String> uploadCover(
      List<int> bytes, String filename, String contentType) async {
    final data =
        await api.multipart('/api/v1/users/me/cover',
            field: 'file',
            bytes: bytes,
            filename: filename,
            contentType: contentType);
    return (data as Map<String, dynamic>)['cover_url'] as String;
  }

  static Future<String> uploadMedia(
      List<int> bytes, String filename, String contentType) async {
    final data = await api.multipart('/api/v1/media/upload',
        field: 'file',
        bytes: bytes,
        filename: filename,
        contentType: contentType);
    final map = data as Map<String, dynamic>;
    return (map['url'] ?? map['avatar_url'] ?? '') as String;
  }

  static Future<Map<String, dynamic>> uploadVideo(
      List<int> bytes, String filename, String contentType) async {
    final data = await api.multipart('/api/v1/videos/upload',
        field: 'file',
        bytes: bytes,
        filename: filename,
        contentType: contentType);
    return data as Map<String, dynamic>;
  }

  static Future<User> getUser(String userId) async {
    final data = await api.get('/api/v1/users/$userId');
    return User.fromJson(data as Map<String, dynamic>);
  }

  // ── Coins / Wallet ────────────────────────────────────────────────────────
  static Future<Wallet> wallet(String ownerId) async {
    try {
      final data = await api.get('/api/v1/coin/wallets/$ownerId');
      if (data == null) return Wallet(ownerId: ownerId, balance: 0, currency: 'MRC');
      return Wallet.fromJson(data as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return _createWallet(ownerId);
      }
      rethrow;
    }
  }

  static Future<Wallet> _createWallet(String ownerId) async {
    try {
      final created = await api.post('/api/v1/coin/wallets', {'owner_id': ownerId});
      return Wallet.fromJson(created as Map<String, dynamic>);
    } on ApiException {
      return Wallet(ownerId: ownerId, balance: 0, currency: 'MRC');
    }
  }

  static Future<List<CoinTx>> transactions(String ownerId) async {
    try {
      final data = await api.get('/api/v1/coin/transactions/$ownerId');
      final list = data is List ? data : <dynamic>[];
      return list.map((e) => CoinTx.fromJson(e as Map<String, dynamic>)).toList();
    } on ApiException {
      return [];
    }
  }

  static Future<Map<String, dynamic>> earn(String ownerId, double amount,
      [String? reference]) async {
    final data = await api.post('/api/v1/coin/transactions/earn',
        {'owner_id': ownerId, 'amount': amount, 'reference': reference ?? 'Reward'});
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> spend(String ownerId, double amount,
      [String? reference]) async {
    final data = await api.post('/api/v1/coin/transactions/spend',
        {'owner_id': ownerId, 'amount': amount, 'reference': reference ?? 'Spend'});
    return data as Map<String, dynamic>;
  }

  static Future<void> transferCoins(String recipientId, double amount) async {
    await api.post('/api/v1/coin/transactions/transfer', {
      'counterparty_id': recipientId,
      'amount': amount,
      'reference': 'User transfer',
    });
  }

  static Future<Map<String, dynamic>> getExchangeRate() async {
    final r = await api.get('/api/v1/coin/exchange/rate');
    return r is Map ? Map<String, dynamic>.from(r) : {};
  }

  static Future<void> convertCoins(double amount, String toCurrency) async {
    await api.post('/api/v1/coin/exchange/convert', {
      'amount': amount,
      'to_currency': toCurrency,
    });
  }

  static Future<Map<String, dynamic>> setCoinRate(String currency, double rate) async {
    final data = await api.post('/api/v1/coin/exchange/rate',
        {'currency': currency, 'rate_to_mrc': rate});
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> coinRate(String currency) async {
    final data = await api.get('/api/v1/coin/exchange/rate',
        {'currency': currency});
    return data as Map<String, dynamic>;
  }

  // ── Ads Manager ────────────────────────────────────────────────────────────
  static Future<List<Campaign>> campaigns() async {
    final data = await api.get('/api/v1/ads/campaigns');
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => Campaign.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Campaign> createCampaign(Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/ads/campaigns', body);
    return Campaign.fromJson(data as Map<String, dynamic>);
  }

  static Future<Campaign> setCampaignStatus(String id, String status) async {
    final data = await api.patch('/api/v1/ads/campaigns/$id/status',
        {'status': status});
    return Campaign.fromJson(data as Map<String, dynamic>);
  }

  static Future<Map<String, dynamic>> addCreative(
      String id, Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/ads/campaigns/$id/creatives', body);
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> campaignStats(String id) async {
    final data = await api.get('/api/v1/ads/campaigns/$id/stats');
    return data as Map<String, dynamic>;
  }

  // ── Notifications ────────────────────────────────────────────────────────
  static Future<List<AppNotification>> notifications(String userId) async {
    final data = await api.get('/api/v1/notifications/$userId');
    final list = data is List ? data : <dynamic>[];
    return list
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> markNotificationsRead() async {
    await api.post('/api/v1/notifications/read-all');
  }

  static Future<void> markNotificationRead(String id) async {
    await api.post('/api/v1/notifications/$id/read');
  }

  // ── Events ────────────────────────────────────────────────────────────────
  static Future<List<Event>> events() async {
    final data = await api.get('/api/v1/events');
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => Event.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Event> createEvent(Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/events', body);
    return Event.fromJson(data as Map<String, dynamic>);
  }

  static Future<Map<String, dynamic>> joinEvent(String id) async {
    final data = await api.post('/api/v1/events/$id/join');
    return data as Map<String, dynamic>;
  }

  // ── Programs ───────────────────────────────────────────────────────────────
  static Future<Program> createProgram(Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/programs/', body);
    return Program.fromJson(data as Map<String, dynamic>);
  }

  static Future<Program> enrollProgram(String id, {String? userId}) async {
    final data = await api.get('/api/v1/programs/$id/enroll',
        {'user_id': userId ?? api._userId});
    return Program.fromJson(data as Map<String, dynamic>);
  }

  // ── Courses ────────────────────────────────────────────────────────────────
  static Future<List<Course>> courses() async {
    final data = await api.get('/api/v1/courses');
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => Course.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Course> createCourse(Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/courses', body);
    return Course.fromJson(data as Map<String, dynamic>);
  }

  static Future<Map<String, dynamic>> enrollCourse(String id) async {
    final data = await api.post('/api/v1/courses/$id/enroll');
    return data as Map<String, dynamic>;
  }

  // ── Projects ───────────────────────────────────────────────────────────────
  static Future<List<Project>> projects() async {
    final data = await api.get('/api/v1/projects');
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => Project.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Project> createProject(Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/projects', body);
    return Project.fromJson(data as Map<String, dynamic>);
  }

  static Future<Project> joinProject(String id) async {
    final data = await api.post('/api/v1/projects/$id/join');
    return Project.fromJson(data as Map<String, dynamic>);
  }

  // ── Verification pipeline ──────────────────────────────────────────────────
  static Future<List<Submission>> mySubmissions(String userId) async {
    final data = await api.get('/api/v1/submissions/users/$userId');
    final list = data is List ? data : <dynamic>[];
    return list
        .map((e) => Submission.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Submission> createSubmission(Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/submissions', body);
    return Submission.fromJson(data as Map<String, dynamic>);
  }

  static Future<Map<String, dynamic>> startPipeline(String submissionId) async {
    final data =
        await api.post('/api/v1/submissions/$submissionId/pipeline');
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> trackEvidence(String evidenceId) async {
    final data = await api.get('/api/v1/verification/pipelines/evidence/$evidenceId');
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> pipelineStatus(String pipelineId) async {
    final data =
        await api.get('/api/v1/verification/pipelines/$pipelineId');
    return data as Map<String, dynamic>;
  }

  // ── GPS ────────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> captureGps(Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/gps/records', body);
    return data as Map<String, dynamic>;
  }

  // ── Media Personnel Profile ─────────────────────────────────────────────────
  static Future<Personnel> personnel(String userId) async {
    final data = await api.get('/api/v1/personnel/$userId');
    return Personnel.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<PersonnelReport>> personnelReports(String userId,
      {int limit = 40}) async {
    final data = await api.get('/api/v1/personnel/$userId/reports',
        {'limit': limit});
    final list = data is List ? data : <dynamic>[];
    return list
        .map((e) => PersonnelReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<AnalyticsPoint>> personnelAnalytics(String userId,
      {String period = 'lifetime'}) async {
    final data = await api.get('/api/v1/personnel/$userId/analytics',
        {'period': period});
    final series = (data is Map && data['series'] is List)
        ? data['series'] as List
        : <dynamic>[];
    return series
        .map((e) => AnalyticsPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<dynamic>> personnelTimeline(String userId) async {
    final data = await api.get('/api/v1/personnel/$userId/timeline');
    return data is List ? List<dynamic>.from(data) : <dynamic>[];
  }

  static Future<List<dynamic>> personnelAchievements(String userId) async {
    final data = await api.get('/api/v1/personnel/$userId/achievements');
    return data is List ? List<dynamic>.from(data) : <dynamic>[];
  }

  static Future<List<dynamic>> personnelOrganizations(String userId) async {
    final data = await api.get('/api/v1/personnel/$userId/organizations');
    return data is List ? List<dynamic>.from(data) : <dynamic>[];
  }

  static Future<List<dynamic>> personnelRecommendations(String userId) async {
    final data = await api.get('/api/v1/personnel/$userId/recommendations');
    return data is List ? List<dynamic>.from(data) : <dynamic>[];
  }

  static Future<Map<String, dynamic>> follow(String userId) async {
    final data = await api.post('/api/v1/users/$userId/follow');
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> followPersonnel(String userId) async {
    final data = await api.post('/api/v1/personnel/$userId/follow');
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> endorsePersonnel(
      String userId, String skill) async {
    final data = await api.post('/api/v1/personnel/$userId/endorse',
        {'skill': skill});
    return data as Map<String, dynamic>;
  }

  // ── Payments / Paymob ──
  static Future<Map<String, dynamic>> pspStatus() async {
    final r = await api.get('/api/v1/payments/psp/status');
    return r;
  }

  static Future<Map<String, dynamic>> paymobIntent({
    required String orgId,
    required double amountEgp,
    String method = 'card',
    String? phone,
    String? invoiceId,
  }) async {
    final body = <String, dynamic>{
      'org_id': orgId,
      'amount_egp': amountEgp,
      'method': method,
    };
    if (phone != null) body['phone'] = phone;
    if (invoiceId != null) body['invoice_id'] = invoiceId;
    final r = await api.post('/api/v1/payments/psp/paymob/intent', body);
    return r;
  }

  static Future<List<Map<String, dynamic>>> paymentHistory(String orgId) async {
    final r = await api.get('/api/v1/payments/$orgId/history');
    if (r is List) return List<Map<String, dynamic>>.from(r);
    if (r is Map && r.containsKey('payments'))
      return List<Map<String, dynamic>>.from(r['payments']);
    return [];
  }

  // ── Admin endpoints ─────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> adminStats() async {
    final r = await api.get('/api/v1/admin/stats');
    if (r is Map) return Map<String, dynamic>.from(r);
    return {};
  }

  static Future<List<Map<String, dynamic>>> reviewQueue({String status = 'PENDING'}) async {
    final r = await api.get('/api/v1/admin/review-queue?status=$status');
    if (r is List) return List<Map<String, dynamic>>.from(r);
    if (r is Map && r.containsKey('data'))
      return List<Map<String, dynamic>>.from(r['data']);
    return [];
  }

  static Future<Map<String, dynamic>> submitVerdict(
    String reviewId, String verdict, String? comments) async {
    final body = {'verdict': verdict, if (comments != null) 'comments': comments};
    final r = await api.post('/api/v1/admin/review/$reviewId/verdict', body);
    if (r is Map) return Map<String, dynamic>.from(r);
    return {};
  }

  static Future<List<Map<String, dynamic>>> adminUsers([String? search]) async {
    final path = search != null ? '/api/v1/admin/users?search=$search' : '/api/v1/admin/users';
    final r = await api.get(path);
    if (r is List) return List<Map<String, dynamic>>.from(r);
    if (r is Map && r.containsKey('data'))
      return List<Map<String, dynamic>>.from(r['data']);
    return [];
  }

  static Future<List<Map<String, dynamic>>> adminSubmissions({String? status}) async {
    final path = status != null
        ? '/api/v1/admin/submissions?status=$status'
        : '/api/v1/admin/submissions';
    final r = await api.get(path);
    if (r is List) return List<Map<String, dynamic>>.from(r);
    if (r is Map && r.containsKey('data'))
      return List<Map<String, dynamic>>.from(r['data']);
    return [];
  }
}
