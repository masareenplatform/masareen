import 'dart:convert';
import 'dart:typed_data';
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
    return _request(() => http.get(uri, headers: _headers));
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    return _request(() => http.post(
          Uri.parse('$_base$path'),
          headers: _headers,
          body: body == null ? null : jsonEncode(body),
        ));
  }

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) async {
    return _request(() => http.patch(
          Uri.parse('$_base$path'),
          headers: _headers,
          body: body == null ? null : jsonEncode(body),
        ));
  }

  Future<dynamic> delete(String path, [Map<String, dynamic>? body]) async {
    return _request(() => http.delete(
          Uri.parse('$_base$path'),
          headers: _headers,
          body: body == null ? null : jsonEncode(body),
        ));
  }

  Future<Uint8List> getBytes(String path, [Map<String, dynamic>? query]) async {
    final stringQuery = query?.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    final uri = Uri.parse('$_base$path').replace(queryParameters: stringQuery);
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode >= 200 && res.statusCode < 300) return res.bodyBytes;
    final raw = utf8.decode(res.bodyBytes, allowMalformed: true);
    throw ApiException(
        res.statusCode, raw.length > 200 ? raw.substring(0, 200) : raw);
  }

  Future<dynamic> multipart(String path,
      {required String field,
      required List<int> bytes,
      required String filename,
      required String contentType}) async {
    return _request(() async {
      final uri = Uri.parse('$_base$path');
      final request = http.MultipartRequest('POST', uri);
      if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
      request.files.add(http.MultipartFile.fromBytes(field, bytes,
          filename: filename, contentType: MediaType.parse(contentType)));
      final streamed = await request.send();
      return http.Response.fromStream(streamed);
    });
  }

  Future<dynamic> _request(Future<http.Response> Function() send) async {
    try {
      return _unwrap(await send());
    } on ApiException {
      rethrow;
    } on http.ClientException {
      throw ApiException(
          0, 'Network unavailable. Check your connection and try again.');
    } catch (e) {
      final text = e.toString();
      if (text.contains('SocketException') ||
          text.contains('Network is unreachable') ||
          text.contains('Failed host lookup')) {
        throw ApiException(
            0, 'Network unavailable. Check your connection and try again.');
      }
      rethrow;
    }
  }

  dynamic _unwrap(http.Response res) {
    final raw = utf8.decode(res.bodyBytes, allowMalformed: true);
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      final preview = raw.length > 200 ? raw.substring(0, 200) : raw;
      throw ApiException(
          res.statusCode,
          preview.isNotEmpty
              ? preview
              : 'Server returned non-JSON (status ${res.statusCode})');
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

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final data = await api.post('/api/v1/auth/login', {
      'email': email,
      'password': password,
    });
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> register(
      Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/users/register', body);
    return data as Map<String, dynamic>;
  }

  static Future<User> me() async {
    final data = await api.get('/api/v1/users/me');
    final user = User.fromJson(data as Map<String, dynamic>);
    api._userId = user.id;
    return user;
  }

  static Future<UserSettings> settings() async {
    final data = await api.get('/api/v1/users/me/settings');
    final Map<String, dynamic> map =
        data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final raw = map['settings'];
    final Map<String, dynamic> settings =
        raw is Map ? Map<String, dynamic>.from(raw) : map;
    return UserSettings.fromJson(settings);
  }

  static Future<UserSettings> updateSettings(Map<String, dynamic> body) async {
    final data = await api.patch('/api/v1/users/me/settings', body);
    final Map<String, dynamic> map =
        data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final raw = map['settings'];
    final Map<String, dynamic> settings =
        raw is Map ? Map<String, dynamic>.from(raw) : map;
    return UserSettings.fromJson(settings);
  }

  static Future<Map<String, dynamic>> verificationStatus() async {
    final data = await api.get('/api/v1/auth/verification-status');
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  static Future<Map<String, dynamic>> resendVerification() async {
    final data = await api.post('/api/v1/auth/resend-verification');
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    final data =
        await api.post('/api/v1/auth/forgot-password', {'email': email});
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  static Future<Map<String, dynamic>> resetPassword(
      String token, String password) async {
    final data = await api.post(
        '/api/v1/auth/reset-password', {'token': token, 'password': password});
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  static Future<void> changePassword(
      String currentPassword, String newPassword) async {
    await api.post('/api/v1/users/me/password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  static Future<void> deleteAccount(String password) async {
    await api.post('/api/v1/users/me/delete', {'password': password});
  }

  static Future<void> registerDeviceToken(String token, String platform) async {
    await api.post('/api/v1/users/me/device-token', {
      'token': token,
      'platform': platform,
    });
  }

  static Future<void> removeDeviceToken(String token) async {
    await api.delete('/api/v1/users/me/device-token', {'token': token});
  }

  // ── Feed / Posts ────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> liveInteractions(
      Iterable<String> postIds) async {
    final ids = postIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(60)
        .join(',');
    if (ids.isEmpty) {
      return const {
        'posts': [],
        'unread_messages': 0,
        'unread_notifications': 0
      };
    }
    final data = await api.get('/api/v1/live/interactions', {'post_ids': ids});
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  static Future<List<Post>> feed({
    String? authorId,
    String? kind,
    String mode = 'for_you',
    int limit = 40,
    int offset = 0,
    String? seed,
  }) async {
    final query = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      'mode': mode,
      if (seed != null && seed.isNotEmpty) 'seed': seed,
    };
    if (authorId != null) query['author_id'] = authorId;
    if (kind != null) query['kind'] = kind;
    final data = await api.get('/api/v1/posts', query);
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<Map<String, dynamic>>> entityModerators(
      String type, String id) async {
    final data = await api.get('/api/v1/entities/$type/$id/moderators');
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> assignEntityModerator(
      String type, String id, String userId,
      {List<String> permissions = const [
        'remove_comments',
        'verify_contributions',
      ]}) async {
    await api.post('/api/v1/entities/$type/$id/moderators', {
      'user_id': int.tryParse(userId) ?? userId,
      'permissions': permissions,
    });
  }

  static Future<void> removeEntityModerator(
      String type, String id, String userId) async {
    await api.delete('/api/v1/entities/$type/$id/moderators/$userId');
  }

  static Future<void> deleteEvent(String id) async {
    await api.delete('/api/v1/events/$id');
  }
  static Future<List<Map<String, dynamic>>> marketList() async {
    final data = await api.get('/api/v1/market');
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> marketDetail(String id) async {
    final data = await api.get('/api/v1/market/$id');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> marketMe() async {
    final data = await api.get('/api/v1/market/me');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> marketAdvantage() async {
    final data = await api.get('/api/v1/market/advantage');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> tradeMarket(String id,
      {required String side, required int shares}) async {
    final data = await api.post('/api/v1/market/$id/trade', {
      'side': side,
      'shares': shares,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<List<Map<String, dynamic>>> newsList({bool mine = false}) async {
    final data = await api.get('/api/v1/news', {if (mine) 'mine': 1});
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> newsDetail(String id) async {
    final data = await api.get('/api/v1/news/$id');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> newsSnapshot(
      String type, String id) async {
    final data = await api.get('/api/v1/news/data', {
      'entity_type': type,
      'entity_id': id,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> createNews(
      Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/news', body);
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> updateNews(
      String id, Map<String, dynamic> body) async {
    final data = await api.patch('/api/v1/news/$id', body);
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> fundNews(
      String id, double amount) async {
    final data = await api.post('/api/v1/news/$id/fund', {
      'amount_mrc': amount,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<void> rateNews(String id, int stars) async {
    await api.post('/api/v1/news/$id/rate', {'stars': stars});
  }
  static Future<Map<String, dynamic>> discoveryFeed({
    int limit = 12,
    int offset = 0,
    String? seed,
  }) async {
    final data = await api.get('/api/v1/discovery/feed', {
      'limit': limit,
      'offset': offset,
      if (seed != null && seed.isNotEmpty) 'seed': seed,
    });
    return Map<String, dynamic>.from(data as Map);
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
    return list
        .map((e) => Comment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Map<String, dynamic>> boostPost(
      String postId, double amount) async {
    final data = await api.post('/api/v1/posts//boost', {'amount': amount});
    return data as Map<String, dynamic>;
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

  static Future<Comment> comment(String postId, String text,
      {String? parentId}) async {
    final data = await api.post('/api/v1/posts/$postId/comment', {
      'text': text,
      if (parentId != null) 'parent_id': parentId,
    });
    return Comment.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> deleteComment(String commentId) async {
    await api.delete('/api/v1/comments/$commentId');
  }

  static Future<Map<String, dynamic>> toggleCommentLike(
      String commentId) async {
    final data = await api.post('/api/v1/comments/$commentId/like');
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> toggleBookmark(String postId) async {
    final data = await api.post('/api/v1/posts/$postId/bookmark');
    return data as Map<String, dynamic>;
  }

  static Future<List<Post>> bookmarks() async {
    final data = await api.get('/api/v1/users/me/bookmarks');
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Post> editPost(String postId, String text) async {
    final data = await api.patch('/api/v1/posts/$postId', {'text': text});
    return Post.fromJson(data as Map<String, dynamic>);
  }

  static Future<Post> editPostFull(
      String postId, Map<String, dynamic> body) async {
    final data = await api.patch('/api/v1/posts/$postId', body);
    return Post.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> deletePost(String postId) async {
    await api.delete('/api/v1/posts/$postId');
  }

  static Future<void> report(String type, String id,
      {required String reason, String? details}) async {
    final path = type == 'comment'
        ? '/api/v1/comments/$id/report'
        : '/api/v1/posts/$id/report';
    await api.post(path, {
      'reason': reason,
      if (details != null && details.trim().isNotEmpty)
        'details': details.trim(),
    });
  }

  static Future<Map<String, dynamic>> toggleBlock(String userId) async {
    final data = await api.post('/api/v1/users/$userId/block');
    return data as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> blockedUsers() async {
    final data = await api.get('/api/v1/users/me/blocked');
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<SocialSearchResult> search(String query) async {
    final data = await api.get('/api/v1/search', {'q': query});
    return SocialSearchResult.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<HashtagTrend>> trends() async {
    final data = await api.get('/api/v1/trends');
    final list = data is List ? data : <dynamic>[];
    return list
        .whereType<Map>()
        .map((e) => HashtagTrend.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<List<Conversation>> conversations() async {
    final data = await api.get('/api/v1/messages/conversations');
    final list = data is List ? data : <dynamic>[];
    return list
        .whereType<Map>()
        .map((e) => Conversation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<Conversation> openConversation(String userId) async {
    final data =
        await api.post('/api/v1/messages/conversations', {'user_id': userId});
    return Conversation.fromJson(data as Map<String, dynamic>);
  }

  static Future<ChatThread> conversation(String id) async {
    final data = await api.get('/api/v1/messages/conversations/$id');
    return ChatThread.fromJson(data as Map<String, dynamic>);
  }

  static Future<ChatMessage> sendMessage(
      String conversationId, String text) async {
    final data = await api
        .post('/api/v1/messages/conversations/$conversationId', {'text': text});
    return ChatMessage.fromJson(data as Map<String, dynamic>);
  }

  static Future<int> unreadMessages() async {
    final data = await api.get('/api/v1/messages/unread');
    final map = data is Map ? data : <String, dynamic>{};
    return map['count'] is num ? (map['count'] as num).toInt() : 0;
  }

  static Future<List<Opportunity>> opportunities() async {
    final data = await api.get('/api/v1/opportunities/');
    final list = data is List ? data : <dynamic>[];
    return list
        .map((e) => Opportunity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Program>> programs() async {
    final data = await api.get('/api/v1/programs/');
    final list = data is List ? data : <dynamic>[];
    return list
        .map((e) => Program.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Map<String, dynamic>> programDetail(String id) async {
    final data = await api.get('/api/v1/programs/$id');
    return data as Map<String, dynamic>;
  }

  static Future<Opportunity> opportunity(String id) async {
    final data = await api.get('/api/v1/opportunities/$id');
    return Opportunity.fromJson(data as Map<String, dynamic>);
  }

  static Future<Opportunity> applyOpportunity(String id, {String? note}) async {
    final data = await api.post('/api/v1/opportunities/$id/apply',
        {if (note != null && note.trim().isNotEmpty) 'note': note.trim()});
    return Opportunity.fromJson(data as Map<String, dynamic>);
  }

  static Future<Opportunity> createOpportunity(
      Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/opportunities/', body);
    return Opportunity.fromJson(data as Map<String, dynamic>);
  }

  static Future<Map<String, dynamic>> passport(String userId) async {
    final data = await api.get('/api/v1/users/$userId/passport');
    return data as Map<String, dynamic>;
  }

  // ── Profile ──────────────────────────────────────────────────────────────
  static Future<User> updateProfile(Map<String, dynamic> body) async {
    final data = await api.patch('/api/v1/users/me/profile', body);
    return User.fromJson(data as Map<String, dynamic>);
  }

  static Future<String> uploadAvatar(
      List<int> bytes, String filename, String contentType) async {
    final data = await api.multipart('/api/v1/users/me/avatar',
        field: 'file',
        bytes: bytes,
        filename: filename,
        contentType: contentType);
    return (data as Map<String, dynamic>)['avatar_url'] as String;
  }

  static Future<String> uploadCover(
      List<int> bytes, String filename, String contentType) async {
    final data = await api.multipart('/api/v1/users/me/cover',
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

  static Future<String> uploadAudio(
      List<int> bytes, String filename, String contentType) async {
    final data = await api.multipart('/api/v1/media/audio',
        field: 'file',
        bytes: bytes,
        filename: filename,
        contentType: contentType);
    final map = data as Map<String, dynamic>;
    return (map['url'] ?? '') as String;
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

  static Future<Map<String, dynamic>> uploadFile(
      List<int> bytes, String filename, String contentType) async {
    final data = await api.multipart('/api/v1/files/upload',
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
      if (data == null) {
        return Wallet(ownerId: ownerId, balance: 0, currency: 'MRC');
      }
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
      final created =
          await api.post('/api/v1/coin/wallets', {'owner_id': ownerId});
      return Wallet.fromJson(created as Map<String, dynamic>);
    } on ApiException {
      return Wallet(ownerId: ownerId, balance: 0, currency: 'MRC');
    }
  }

  static Future<List<CoinTx>> transactions(String ownerId) async {
    try {
      final data = await api.get('/api/v1/coin/transactions/$ownerId');
      final list = data is List ? data : <dynamic>[];
      return list
          .map((e) => CoinTx.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException {
      return [];
    }
  }

  // The daily reward is set by the server. No amount is sent from the app.
  static Future<Map<String, dynamic>> claimDailyReward() async {
    final data = await api.post('/api/v1/coin/transactions/earn', {});
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  static Future<Map<String, dynamic>> spend(String ownerId, double amount,
      [String? reference]) async {
    final data = await api.post('/api/v1/coin/transactions/spend', {
      'owner_id': ownerId,
      'amount': amount,
      'reference': reference ?? 'Spend'
    });
    return data as Map<String, dynamic>;
  }

  static Future<void> transferCoins(String recipientId, double amount,
      {String? reference}) async {
    await api.post('/api/v1/coin/transactions/transfer', {
      'counterparty_id': recipientId,
      'amount': amount,
      'reference': reference ?? 'User transfer',
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

  static Future<Map<String, dynamic>> setCoinRate(
      String currency, double rate) async {
    final data = await api.post('/api/v1/coin/exchange/rate',
        {'currency': currency, 'rate_to_mrc': rate});
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> coinRate(String currency) async {
    final data =
        await api.get('/api/v1/coin/exchange/rate', {'currency': currency});
    return data as Map<String, dynamic>;
  }

  // Ads Manager
  static Future<List<Campaign>> campaigns({String? status}) async {
    final path = status == null || status.isEmpty
        ? '/api/v1/ads/campaigns'
        : '/api/v1/ads/campaigns?status=$status';
    final data = await api.get(path);
    final list = data is List ? data : <dynamic>[];
    return list
        .map((e) => Campaign.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Campaign> campaign(String id) async {
    final data = await api.get('/api/v1/ads/campaigns/$id');
    return Campaign.fromJson(data as Map<String, dynamic>);
  }

  static Future<Campaign> createCampaign(Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/ads/campaigns', body);
    return Campaign.fromJson(data as Map<String, dynamic>);
  }

  static Future<Campaign> updateCampaign(
      String id, Map<String, dynamic> body) async {
    final data = await api.patch('/api/v1/ads/campaigns/$id', body);
    return Campaign.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> deleteCampaign(String id) async {
    await api.delete('/api/v1/ads/campaigns/$id');
  }

  static Future<Campaign> setCampaignStatus(String id, String status) async {
    final data =
        await api.patch('/api/v1/ads/campaigns/$id/status', {'status': status});
    return Campaign.fromJson(data as Map<String, dynamic>);
  }

  static Future<Creative> addCreative(
      String id, Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/ads/campaigns/$id/creatives', body);
    return Creative.fromJson(data as Map<String, dynamic>);
  }

  static Future<Creative> updateCreative(
      String creativeId, Map<String, dynamic> body) async {
    final data = await api.patch('/api/v1/ads/creatives/$creativeId', body);
    return Creative.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> deleteCreative(String creativeId) async {
    await api.delete('/api/v1/ads/creatives/$creativeId');
  }

  static Future<Map<String, dynamic>> campaignStats(String id,
      {int days = 30}) async {
    final data =
        await api.get('/api/v1/ads/campaigns/$id/stats', {'days': days});
    return data as Map<String, dynamic>;
  }

  static Future<List<Campaign>> feedAds(
      {String placement = 'feed', int limit = 2}) async {
    final data = await api
        .get('/api/v1/ads/feed', {'placement': placement, 'limit': limit});
    final list = data is List ? data : <dynamic>[];
    return list
        .map((e) => Campaign.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Map<String, dynamic>> recordAdEvent(String id,
      {required String type, String? creativeId}) async {
    final body = <String, dynamic>{'type': type};
    if (creativeId != null) body['creative_id'] = creativeId;
    final data = await api.post('/api/v1/ads/campaigns/$id/events', body);
    return data is Map ? Map<String, dynamic>.from(data) : {};
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

  static Future<int> unreadNotificationCount() async {
    final data = await api.get('/api/v1/notifications/unread-count');
    final map = data is Map ? data : <String, dynamic>{};
    return map['count'] is num ? (map['count'] as num).toInt() : 0;
  }

  // ── Events ────────────────────────────────────────────────────────────────
  static Future<List<Event>> events(
      {bool includePast = false, String? q, String? type}) async {
    final data = await api.get('/api/v1/events', {
      if (includePast) 'include_past': '1',
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (type != null && type.isNotEmpty) 'type': type,
    });
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

  static Future<Map<String, dynamic>> eventDetail(String id) async {
    final data = await api.get('/api/v1/events/$id');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<List<Map<String, dynamic>>> eventParticipants(String id) async {
    final data = await api.get('/api/v1/events/$id/participants');
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> addEventParticipant(
      String eventId, Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/events/$eventId/participants', body);
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<void> submitEventEvidence(
      String eventId, String participantId, Map<String, dynamic> body) async {
    await api.post(
        '/api/v1/events/$eventId/participants/$participantId/evidence', body);
  }

  static Future<void> eventParticipantVerdict(
      String eventId, String participantId,
      {required String status, String? note, bool override = false}) async {
    await api.post(
        '/api/v1/events/$eventId/participants/$participantId/verdict',
        {'status': status, if (note != null) 'note': note,
         if (override) 'override_deepfake': true});
  }

  static Future<void> confirmEventParticipant(
      String eventId, String participantId) async {
    await api
        .post('/api/v1/events/$eventId/participants/$participantId/confirm');
  }

  static Future<void> addEventMedia(
      String eventId, Map<String, dynamic> body) async {
    await api.post('/api/v1/events/$eventId/media', body);
  }

  static Future<void> createEventBooth(
      String eventId, Map<String, dynamic> body) async {
    await api.post('/api/v1/events/$eventId/booths', body);
  }

  static Future<List<Map<String, dynamic>>> eventBooths(String id) async {
    final data = await api.get('/api/v1/events/$id/booths');
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> booth(String id) async {
    final data = await api.get('/api/v1/booths/$id');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> activateBooth(String id) async {
    final data = await api.post('/api/v1/booths/$id/activate');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> submitBoothLead(
      String id, Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/booths/$id/leads', body);
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<List<Map<String, dynamic>>> boothLeads(String id) async {
    final data = await api.get('/api/v1/booths/$id/leads');
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> updateBoothLead(
      String boothId, String leadId, String status) async {
    await api.patch(
        '/api/v1/booths/$boothId/leads/$leadId/status', {'status': status});
  }

  static Future<void> rateEvent(String id,
      {required int rating, String? review}) async {
    await api.post('/api/v1/events/$id/ratings', {
      'rating': rating,
      if (review != null && review.trim().isNotEmpty) 'review': review.trim(),
    });
  }

  static Future<Map<String, dynamic>> claimEventAttendance(String id) async {
    final data = await api.post('/api/v1/events/$id/attendance');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> managedEvents() async {
    final data = await api.get('/api/v1/events/managed');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> eventDashboard(String id) async {
    final data = await api.get('/api/v1/events/$id/dashboard');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> organizerReputation(String id) async {
    final data = await api.get('/api/v1/events/organizers/$id');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<List<Map<String, dynamic>>> podcastShows({String? q}) async {
    final data = await api.get('/api/v1/podcasts', {
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
    });
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> podcastShow(String id) async {
    final data = await api.get('/api/v1/podcasts/$id');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> createPodcastShow(
      Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/podcasts', body);
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> createPodcastEpisode(
      String showId, Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/podcasts/$showId/episodes', body);
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<List<Map<String, dynamic>>> vodVideos(
      {String? q, String? eventId}) async {
    final data = await api.get('/api/v1/vod', {
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (eventId != null) 'event_id': eventId,
    });
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> vodVideo(String id) async {
    final data = await api.get('/api/v1/vod/$id');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> createVod(
      Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/vod', body);
    return Map<String, dynamic>.from(data as Map);
  }

  // ── Programs ───────────────────────────────────────────────────────────────
  static Future<Program> createProgram(Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/programs/', body);
    return Program.fromJson(data as Map<String, dynamic>);
  }

  static Future<Program> enrollProgram(String id) async {
    final data = await api.post('/api/v1/programs/$id/enroll');
    return Program.fromJson(data as Map<String, dynamic>);
  }

  static Future<Program> leaveProgram(String id) async {
    final data = await api.delete('/api/v1/programs/$id/enroll');
    return Program.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<Map<String, dynamic>>> programMembers(String id) async {
    final data = await api.get('/api/v1/programs/$id/members');
    if (data is List) return List<Map<String, dynamic>>.from(data);
    return [];
  }

  static Future<Map<String, dynamic>> taskById(String id) async {
    final data = await api.get('/api/v1/tasks/$id');
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  static Future<Map<String, dynamic>> updateTaskStatus(
      String id, String status) async {
    final data = await api.post('/api/v1/tasks/$id/status', {'status': status});
    return data is Map ? Map<String, dynamic>.from(data) : {};
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

  static Future<Course> course(String id) async {
    final data = await api.get('/api/v1/courses/$id');
    return Course.fromJson(data as Map<String, dynamic>);
  }

  static Future<Map<String, dynamic>> enrollCourse(String id) async {
    final data = await api.post('/api/v1/courses/$id/enroll');
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> unenrollCourse(String id) async {
    final data = await api.delete('/api/v1/courses/$id/enroll');
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> courseLessons(String id) async {
    final data = await api.get('/api/v1/courses/$id/lessons');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<CourseLesson> addCourseLesson(
      String courseId, Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/courses/$courseId/lessons', body);
    return CourseLesson.fromJson(Map<String, dynamic>.from(data as Map));
  }

  static Future<CourseLesson> updateCourseLesson(
      String courseId, String lessonId, Map<String, dynamic> body) async {
    final data =
        await api.patch('/api/v1/courses/$courseId/lessons/$lessonId', body);
    return CourseLesson.fromJson(Map<String, dynamic>.from(data as Map));
  }

  static Future<void> deleteCourseLesson(
      String courseId, String lessonId) async {
    await api.delete('/api/v1/courses/$courseId/lessons/$lessonId');
  }

  // ── Projects ───────────────────────────────────────────────────────────────
  static Future<List<Project>> projects() async {
    final data = await api.get('/api/v1/projects');
    final list = data is List ? data : <dynamic>[];
    return list
        .map((e) => Project.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Project> createProject(Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/projects', body);
    return Project.fromJson(data as Map<String, dynamic>);
  }

  static Future<Project> joinProject(String id) async {
    final data = await api.post('/api/v1/projects/$id/join');
    return Project.fromJson(data as Map<String, dynamic>);
  }

  static Future<Project> leaveProject(String id) async {
    final data = await api.delete('/api/v1/projects/$id/join');
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
    final data = await api.post('/api/v1/submissions/$submissionId/pipeline');
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> trackEvidence(String evidenceId) async {
    final data =
        await api.get('/api/v1/verification/pipelines/evidence/$evidenceId');
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> pipelineStatus(String pipelineId) async {
    final data = await api.get('/api/v1/verification/pipelines/$pipelineId');
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> retractSubmission(String id) async {
    final data = await api.delete('/api/v1/submissions/$id');
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  static Future<List<Map<String, dynamic>>> evidenceList() async {
    final data = await api.get('/api/v1/evidence');
    if (data is List) return List<Map<String, dynamic>>.from(data);
    return [];
  }

  static Future<Map<String, dynamic>> createEvidence(
      Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/evidence', body);
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  // ── GPS ────────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> captureGps(
      Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/gps/records', body);
    return data as Map<String, dynamic>;
  }

  static Future<List<GpsRecord>> gpsHistory() async {
    try {
      final data = await api.get('/api/v1/gps/records');
      final list = data is List ? data : <dynamic>[];
      return list
          .map((e) => GpsRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException {
      return [];
    }
  }

  // ── Media Personnel Profile ─────────────────────────────────────────────────
  static Future<Personnel> personnel(String userId) async {
    final data = await api.get('/api/v1/personnel/$userId');
    return Personnel.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<PersonnelReport>> personnelReports(String userId,
      {int limit = 40}) async {
    final data =
        await api.get('/api/v1/personnel/$userId/reports', {'limit': limit});
    final list = data is List ? data : <dynamic>[];
    return list
        .map((e) => PersonnelReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<AnalyticsPoint>> personnelAnalytics(String userId,
      {String period = 'lifetime'}) async {
    final data = await api
        .get('/api/v1/personnel/$userId/analytics', {'period': period});
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

  static Future<Personnel> updatePersonnelProfile(
      Map<String, dynamic> body) async {
    final data = await api.patch('/api/v1/personnel/me', body);
    return Personnel.fromJson(data as Map<String, dynamic>);
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
    final data =
        await api.post('/api/v1/personnel/$userId/endorse', {'skill': skill});
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
    String purpose = 'topup',
    String? plan,
  }) async {
    final body = <String, dynamic>{
      'org_id': orgId,
      'amount_egp': amountEgp,
      'method': method,
      'purpose': purpose,
    };
    if (phone != null) body['phone'] = phone;
    if (invoiceId != null) body['invoice_id'] = invoiceId;
    if (plan != null) body['plan'] = plan;
    final r = await api.post('/api/v1/payments/psp/paymob/intent', body);
    return r;
  }

  static Future<List<Map<String, dynamic>>> paymentHistory(String orgId) async {
    final r = await api.get('/api/v1/payments/$orgId/history');
    if (r is List) return List<Map<String, dynamic>>.from(r);
    if (r is Map && r.containsKey('payments')) {
      return List<Map<String, dynamic>>.from(r['payments']);
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> proPlans() async {
    final r = await api.get('/api/v1/pro/plans');
    final list = r is Map ? r['plans'] : null;
    if (list is List) return List<Map<String, dynamic>>.from(list);
    return [];
  }

  static Future<Map<String, dynamic>> proMe() async {
    final r = await api.get('/api/v1/pro/me');
    return r is Map ? Map<String, dynamic>.from(r) : {};
  }

  static Future<Map<String, dynamic>> subscribePro(String plan) async {
    final r = await api.post('/api/v1/pro/subscribe', {'plan': plan});
    return r is Map ? Map<String, dynamic>.from(r) : {};
  }

  static Future<void> cancelPro() async {
    await api.post('/api/v1/pro/cancel');
  }

  static Future<Map<String, dynamic>> submitInquiry({
    required String orgId,
    required String subject,
    required String message,
    String type = 'general',
    String? department,
  }) async {
    final body = <String, dynamic>{
      'org_id': orgId,
      'type': type,
      'subject': subject,
      'message': message,
    };
    if (department != null && department.isNotEmpty) {
      body['department'] = department;
    }
    final r = await api.post('/api/v1/inquiries', body);
    return r is Map ? Map<String, dynamic>.from(r) : {};
  }

  // ── Admin endpoints ─────────────────────────────────────────────────────

  static Future<List<Announcement>> announcements() async {
    final data = await api.get('/api/v1/announcements');
    final list = data is List ? data : <dynamic>[];
    return list
        .whereType<Map>()
        .map((e) => Announcement.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> dismissAnnouncement(String id) async {
    await api.post('/api/v1/announcements/$id/dismiss');
  }

  static Future<Conversation> supportConversation() async {
    final data = await api.post('/api/v1/support/conversation');
    return Conversation.fromJson(Map<String, dynamic>.from(data as Map));
  }

  static Future<List<Announcement>> adminAnnouncements() async {
    final data = await api.get('/api/v1/admin/announcements');
    final list = data is List ? data : <dynamic>[];
    return list
        .whereType<Map>()
        .map((e) => Announcement.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<Announcement> adminCreateAnnouncement(
      Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/admin/announcements', body);
    return Announcement.fromJson(Map<String, dynamic>.from(data as Map));
  }

  static Future<void> adminDeleteAnnouncement(String id) async {
    await api.delete('/api/v1/admin/announcements/$id');
  }

  static Future<void> testPush({String? title, String? body}) async {
    await api.post('/api/v1/notifications/test-push', {
      if (title != null) 'title': title,
      if (body != null) 'body': body,
    });
  }

  static Future<void> sendAnalytics(List<Map<String, dynamic>> events) async {
    if (events.isEmpty) return;
    await api.post('/api/v1/analytics/events', {'events': events});
  }

  static Future<Map<String, dynamic>> leaderboardOptions() async {
    final data = await api.get('/api/v1/leaderboards/options');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Post> createLeaderboard(Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/leaderboards', body);
    return Post.fromJson(Map<String, dynamic>.from(data as Map));
  }

  static Future<void> aiEmbed(String postId) async {
    await api.post('/api/v1/ai/embed/$postId');
  }

  static Future<Map<String, dynamic>> aiTranscribe(String postId) async {
    final data = await api.post('/api/v1/ai/transcribe/$postId');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<List<Map<String, dynamic>>> adminTransactions() async {
    final data = await api.get('/api/v1/admin/transactions');
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> adminAnalytics({int days = 30}) async {
    final data = await api.get('/api/v1/admin/analytics', {'days': days});
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> adminReports({int days = 30}) async {
    final data = await api.get('/api/v1/admin/impact-reports', {'days': days});
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<void> adminUserAction(String id, String action,
      {String? reason}) async {
    await api.post('/api/v1/admin/users/$id/action', {
      'action': action,
      if (reason != null) 'reason': reason,
    });
  }

  static Future<void> adminModeratePost(String id, String status,
      {String? reason}) async {
    await api.post('/api/v1/admin/posts/$id/moderate', {
      'status': status,
      if (reason != null) 'reason': reason,
    });
  }

  static Future<List<Map<String, dynamic>>> adminLeaderboards(
      {String status = 'PENDING'}) async {
    final data = await api.get('/api/v1/admin/leaderboards', {
      'status': status,
    });
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> adminLeaderboardVerdict(String id, String status) async {
    await api
        .post('/api/v1/admin/leaderboards/$id/verdict', {'status': status});
  }

  static Future<Post> postById(String id) async {
    final data = await api.get('/api/v1/posts/$id');
    return Post.fromJson(Map<String, dynamic>.from(data as Map));
  }

  static Future<Map<String, dynamic>> liveTv() async {
    final data = await api.get('/api/v1/live/tv');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<List<Map<String, dynamic>>> institutions(
      {String? q, String? type}) async {
    final data = await api.get('/api/v1/institutions', {
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (type != null && type.isNotEmpty) 'type': type,
    });
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> institution(String id) async {
    final data = await api.get('/api/v1/users/$id/institution');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<List<Map<String, dynamic>>> researchStages(
      {String? userId, String? institutionId, int limit = 50}) async {
    final data = await api.get('/api/v1/research/stages', {
      if (userId != null) 'user_id': userId,
      if (institutionId != null) 'institution_id': institutionId,
      'limit': limit,
    });
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> createResearchStage(
      Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/research/stages', body);
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<List<Map<String, dynamic>>> entityLinks(
      String sourceType, String sourceId) async {
    final data = await api.get('/api/v1/entity-links', {
      'source_type': sourceType,
      'source_id': sourceId,
    });
    final list = data is List ? data : <dynamic>[];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> createEntityLinks(
      Map<String, dynamic> body) async {
    final data = await api.post('/api/v1/entity-links', body);
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<void> deleteEntityLink(String id) async {
    await api.delete('/api/v1/entity-links/$id');
  }

  static Future<Map<String, dynamic>> fundEvent(
      String id, double amount) async {
    final data = await api.post('/api/v1/events/$id/fund', {'amount': amount});
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> adminAiStatus() async {
    final data = await api.get('/api/v1/admin/ai/status');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> adminAiBackfill({int limit = 100}) async {
    final data = await api.post('/api/v1/admin/ai/backfill', {'limit': limit});
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> adminModeration(
      {String status = 'REVIEW'}) async {
    final data = await api.get('/api/v1/admin/moderation', {'status': status});
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> adminUserBehavior(String id,
      {int days = 30}) async {
    final data =
        await api.get('/api/v1/admin/users/$id/behavior', {'days': days});
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> adminVideoJobs(
      {String status = 'all'}) async {
    final data = await api.get('/api/v1/admin/video-jobs', {'status': status});
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<void> adminRequeueVideoJob(String id) async {
    await api.post('/api/v1/admin/video-jobs/$id/requeue');
  }

  static Future<Map<String, dynamic>> adminTranscodePost(String postId) async {
    final data = await api.post('/api/v1/admin/posts/$postId/transcode');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> saveAdminSettings(
      Map<String, dynamic> settings) async {
    final data = await api.post('/api/v1/admin/settings', {
      'settings': settings,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  static String adminExportUrl(String kind) =>
      '${api.baseUrl}/api/v1/admin/exports/$kind.csv';

  static Future<Uint8List> adminExport(String kind, {int days = 30}) async {
    return api.getBytes('/api/v1/admin/exports/$kind.csv', {'days': days});
  }

  static Future<Map<String, dynamic>> adminSettings() async {
    final r = await api.get('/api/v1/admin/settings');
    return Map<String, dynamic>.from(r as Map);
  }

  static Future<Map<String, dynamic>> publishOta({
    required String platform,
    required String version,
    required int build,
    required String url,
    String notes = '',
    bool force = false,
  }) async {
    final r = await api.post('/api/v1/admin/ota', {
      'platform': platform,
      'version': version,
      'build': build,
      'url': url,
      'notes': notes,
      'force': force,
    });
    return Map<String, dynamic>.from(r as Map);
  }

  static Future<void> submitFeedback({
    required String type,
    required String message,
    int? rating,
  }) async {
    await api.post('/api/v1/feedback', {
      'type': type,
      'message': message,
      if (rating != null) 'rating': rating,
    });
  }

  static Future<List<Map<String, dynamic>>> adminFeedback(
      {String? status}) async {
    final r = await api.get(status == null || status.isEmpty
        ? '/api/v1/admin/feedback'
        : '/api/v1/admin/feedback?status=$status');
    final list = r is List ? r : <dynamic>[];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> adminFeedbackStatus(String id, String status) async {
    await api.patch('/api/v1/admin/feedback/$id', {'status': status});
  }

  static Future<List<Map<String, dynamic>>> adminEntities(
      {String status = 'PENDING'}) async {
    final r = await api.get('/api/v1/admin/entities?status=$status');
    final list = r is List ? r : <dynamic>[];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> adminEntityVerdict({
    required String type,
    required String id,
    required String status,
    String? reason,
  }) async {
    await api.post('/api/v1/admin/entities/$type/$id/verdict', {
      'status': status,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  static Future<Map<String, dynamic>> adminStats() async {
    final r = await api.get('/api/v1/admin/stats');
    if (r is Map) return Map<String, dynamic>.from(r);
    return {};
  }

  static Future<Map<String, dynamic>> paymentStatus(String id) async {
    final r = await api.get('/api/v1/payments/$id/status');
    return r is Map ? Map<String, dynamic>.from(r) : {};
  }

  static Future<List<Map<String, dynamic>>> reviewQueue(
      {String status = 'AI_REVIEW'}) async {
    final r = await api.get('/api/v1/admin/review-queue?status=$status');
    if (r is List) return List<Map<String, dynamic>>.from(r);
    if (r is Map && r.containsKey('data')) {
      return List<Map<String, dynamic>>.from(r['data']);
    }
    return [];
  }

  static Future<Map<String, dynamic>> submitVerdict(
      String reviewId, String verdict, String? comments) async {
    final body = {
      'verdict': verdict,
      if (comments != null) 'comments': comments
    };
    final r =
        await api.post('/api/v1/admin/submissions/$reviewId/verdict', body);
    if (r is Map) return Map<String, dynamic>.from(r);
    return {};
  }

  static Future<List<Map<String, dynamic>>> adminUsers([String? search]) async {
    final path = search != null
        ? '/api/v1/admin/users?search=$search'
        : '/api/v1/admin/users';
    final r = await api.get(path);
    if (r is List) return List<Map<String, dynamic>>.from(r);
    if (r is Map && r.containsKey('data')) {
      return List<Map<String, dynamic>>.from(r['data']);
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> adminSubmissions(
      {String? status}) async {
    final path = status != null
        ? '/api/v1/admin/submissions?status=$status'
        : '/api/v1/admin/submissions';
    final r = await api.get(path);
    if (r is List) return List<Map<String, dynamic>>.from(r);
    if (r is Map && r.containsKey('data')) {
      return List<Map<String, dynamic>>.from(r['data']);
    }
    return [];
  }

  static Future<Map<String, dynamic>> adminReportPage(
      {String status = 'OPEN', String? targetType, int limit = 100}) async {
    final params = <String, dynamic>{
      'status': status,
      'limit': limit,
      'with_counts': 1,
    };
    if (targetType != null && targetType.isNotEmpty) {
      params['target_type'] = targetType;
    }
    final r = await api.get('/api/v1/admin/reports', params);
    return r is Map ? Map<String, dynamic>.from(r) : {};
  }

  static Future<Map<String, dynamic>> resolveReport(String id,
      {String status = 'RESOLVED', String action = 'NONE'}) async {
    final r = await api.post('/api/v1/admin/reports/$id/resolve',
        {'status': status, 'action': action});
    return r is Map ? Map<String, dynamic>.from(r) : {};
  }

  static Future<List<Campaign>> adminAds({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    final r = await api.get('/api/v1/admin/ads', params);
    final list = r is List ? r : <dynamic>[];
    return list
        .map((e) => Campaign.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Campaign> adminSetAdStatus(String id, String status) async {
    final r =
        await api.post('/api/v1/admin/ads/$id/status', {'status': status});
    return Campaign.fromJson(r as Map<String, dynamic>);
  }

  static Future<List<Map<String, dynamic>>> adminInquiries(
      {String? status}) async {
    final params = <String, dynamic>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    final r = await api.get('/api/v1/admin/inquiries', params);
    if (r is List) return List<Map<String, dynamic>>.from(r);
    return [];
  }

  static Future<Map<String, dynamic>> adminUpdateInquiry(
      String id, String status) async {
    final r =
        await api.patch('/api/v1/admin/inquiries/$id', {'status': status});
    return r is Map ? Map<String, dynamic>.from(r) : {};
  }

  static Future<List<Map<String, dynamic>>> adminPayments(
      {String? status}) async {
    final params = <String, dynamic>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    final r = await api.get('/api/v1/admin/payments', params);
    if (r is List) return List<Map<String, dynamic>>.from(r);
    return [];
  }

  static Future<Map<String, dynamic>> adminSubmissionVerdict(
      String id, String status) async {
    final r = await api
        .post('/api/v1/admin/submissions/$id/verdict', {'status': status});
    return r is Map ? Map<String, dynamic>.from(r) : {};
  }
}
