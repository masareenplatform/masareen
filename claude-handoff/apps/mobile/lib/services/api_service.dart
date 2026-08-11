import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:masaren/di/injection.dart';
import '../core/models/user_model.dart';
import '../core/models/task_model.dart';
import '../core/models/profile_model.dart';
import '../core/models/evidence_model.dart';
import '../core/models/opportunity_model.dart';

/// Thin client over the MASAREEN API gateway (/api/v1).
///
/// The gateway returns an envelope `{ success, data, message }`. A response
/// interceptor unwraps `data` so every method receives the real payload
/// (object or list) rather than the wrapper.
class ApiService {
  final Dio _dio = getIt<Dio>();
  final FlutterSecureStorage _storage = getIt<FlutterSecureStorage>();

  ApiService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));

    // Unwrap the gateway envelope so callers get the inner payload directly.
    _dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) {
        final body = response.data;
        if (body is Map<String, dynamic> && body.containsKey('data')) {
          response.data = body['data'];
        }
        return handler.next(response);
      },
    ));
  }

  // --- AUTH ---
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    final data = response.data as Map<String, dynamic>;
    if (data['access_token'] != null) {
      await _storage.write(key: 'access_token', value: data['access_token'].toString());
    }
    if (data['user_id'] != null) {
      await _storage.write(key: 'user_id', value: data['user_id'].toString());
    }
    return data;
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    final response = await _dio.post('/users/register', data: userData);
    return response.data as Map<String, dynamic>;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'user_id');
  }

  // --- USER & PROFILE ---
  Future<UserModel> getCurrentUser() async {
    final response = await _dio.get('/users/me');
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ProfileModel> getProfile(String userId) async {
    final response = await _dio.get('/users/$userId');
    return ProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  // --- SOCIAL GRAPH (follow) ---
  Future<Map<String, dynamic>> followUser(String userId) async {
    final response = await _dio.post('/users/$userId/follow', data: <String, dynamic>{});
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> isFollowing(String userId) async {
    final response = await _dio.get('/users/$userId/is-following');
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  Future<List<dynamic>> suggestedUsers() async {
    final response = await _dio.get('/users/suggested');
    final data = response.data;
    if (data is Map<String, dynamic> && data['items'] is List) return data['items'] as List;
    if (data is List) return data;
    return [];
  }

  Future<Map<String, dynamic>> getNotifications() async {
    try {
      final response = await _dio.get('/notifications');
      final data = response.data;
      if (data is Map<String, dynamic> && data['items'] is List) return {'items': data['items']};
      if (data is List) return {'items': data};
    } catch (_) {}
    return {'items': []};
  }


  // --- DASHBOARD (BFF) ---
  Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await _dio.get('/bff/dashboard');
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  // --- TASKS ---
  Future<List<TaskModel>> getTasks() async {
    final response = await _dio.get('/tasks');
    final list = response.data;
    if (list is List) {
      return list.map((e) => TaskModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  // --- EVIDENCE ---
  Future<List<EvidenceModel>> getEvidence() async {
    final response = await _dio.get('/evidence');
    final list = response.data;
    if (list is List) {
      return list.map((e) => EvidenceModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> uploadEvidence(Map<String, dynamic> payload) async {
    final response = await _dio.post('/evidence', data: payload);
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  Future<void> syncEvidence(String evidenceId) async {
    await _dio.post('/evidence/$evidenceId/sync');
  }

  // --- OPPORTUNITIES ---
  Future<List<OpportunityModel>> getOpportunities() async {
    final response = await _dio.get('/opportunities');
    final list = response.data;
    if (list is List) {
      return list.map((e) => OpportunityModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<void> applyToOpportunity(String oppId, String userId) async {
    await _dio.post('/opportunities/$oppId/apply', data: {'user_id': userId});
  }

  // --- FEED ---
  Future<List<dynamic>> getFeed({required String userId, int limit = 20, int offset = 0}) async {
    final response = await _dio.get('/matching/feed', queryParameters: {
      'user_id': userId,
      'limit': limit,
      'offset': offset,
    });
    final data = response.data;
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['items'] is List) return data['items'] as List<dynamic>;
    return [];
  }

  // --- ADMIN (HITL verification review) ---
  Future<List<String>> getPendingApprovals() async {
    final response = await _dio.get('/audit/review/pending');
    final list = response.data;
    if (list is List) {
      return list
          .map((e) => (e is Map<String, dynamic> ? e['review_id'] : e)?.toString())
          .where((e) => e != null)
          .cast<String>()
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> approveVerification(
    String reviewId,
    String verdict,
    String comments, {
    String adminId = 'mobile-admin',
  }) async {
    final response = await _dio.patch('/audit/review/$reviewId/resolve', data: {
      'verdict': verdict,
      'comments': comments,
      'admin_id': adminId,
    });
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  // --- PARTNER / COLLABORATION HOSTING (companies & startups) ---
  Future<Map<String, dynamic>> submitCollaboration(Map<String, dynamic> payload) async {
    final response = await _dio.post('/partners', data: payload);
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  Future<List<dynamic>> listCollaborations({String? status}) async {
    final response = await _dio.get('/partners', queryParameters: status != null ? {'status': status} : null);
    final data = response.data;
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['items'] is List) return data['items'] as List;
    return [];
  }

  Future<Map<String, dynamic>> reviewCollaboration(
    String id,
    String verdict,
    String notes, {
    String reviewerId = 'mobile-admin',
  }) async {
    final response = await _dio.patch('/partners/$id/review', data: {
      'verdict': verdict,
      'notes': notes,
      'reviewer_id': reviewerId,
    });
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> provisionCollaboration(String id, {String provisionedBy = 'mobile-admin'}) async {
    final response = await _dio.patch('/partners/$id/provision', data: {
      'provisioned_by': provisionedBy,
    });
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  /// Convenience accessor for the locally cached user id.
  Future<String> currentUserId() async {
    return (await _storage.read(key: 'user_id')) ?? '';
  }

  // --- MASAREEN COIN (in-app wallet) ---
  Future<Map<String, dynamic>> getWallet(String ownerId) async {
    final response = await _dio.get('/coin/wallets/$ownerId');
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> createWallet(String ownerId) async {
    final response = await _dio.post('/coin/wallets', data: {'owner_id': ownerId});
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> transfer(String from, String to, num amount, String? reference) async {
    final response = await _dio.post('/coin/transactions/transfer', data: {
      'from_owner': from,
      'to_owner': to,
      'amount': amount,
      if (reference != null) 'reference': reference,
    });
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> earn(String ownerId, num amount, String? reference) async {
    final response = await _dio.post('/coin/transactions/earn', data: {
      'owner_id': ownerId,
      'amount': amount,
      if (reference != null) 'reference': reference,
    });
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> spend(String ownerId, num amount, String? reference) async {
    final response = await _dio.post('/coin/transactions/spend', data: {
      'owner_id': ownerId,
      'amount': amount,
      if (reference != null) 'reference': reference,
    });
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  Future<List<dynamic>> history(String ownerId, {int limit = 50}) async {
    final response = await _dio.get('/coin/transactions/$ownerId', queryParameters: {'limit': limit});
    final data = response.data;
    if (data is List) return data;
    return [];
  }

  Future<Map<String, dynamic>> getRate({String currency = 'EGP'}) async {
    final response = await _dio.get('/coin/exchange/rate', queryParameters: {'currency': currency});
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> setRate(String currency, num rateToMrc) async {
    final response = await _dio.post('/coin/exchange/rate', data: {'currency': currency, 'rate_to_mrc': rateToMrc});
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> convert(String ownerId, String currency, num fiatAmount, String direction) async {
    final response = await _dio.post('/coin/exchange/convert', data: {
      'owner_id': ownerId,
      'currency': currency,
      'fiat_amount': fiatAmount,
      'direction': direction,
    });
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  // --- ADS MANAGER ---
  Future<List<dynamic>> listCampaigns({String? status}) async {
    final response = await _dio.get('/ads/campaigns', queryParameters: status != null ? {'status': status} : null);
    final data = response.data;
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['items'] is List) return data['items'] as List;
    return [];
  }

  Future<Map<String, dynamic>> getCampaign(String id) async {
    final response = await _dio.get('/ads/campaigns/$id');
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> createCampaign(
    String name,
    num budgetCoins, {
    Map<String, dynamic>? targeting,
    String? startDate,
    String? endDate,
  }) async {
    final response = await _dio.post('/ads/campaigns', data: {
      'name': name,
      'budget_coins': budgetCoins,
      'currency': 'MRC',
      if (targeting != null) 'targeting': targeting,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
    });
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> setCampaignStatus(String id, String status) async {
    final response = await _dio.patch('/ads/campaigns/$id/status', data: {'status': status});
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> addCreative(String id, String title, String body, {String? mediaUrl, String? ctaUrl}) async {
    final response = await _dio.post('/ads/campaigns/$id/creatives', data: {
      'title': title,
      'body': body,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (ctaUrl != null) 'cta_url': ctaUrl,
    });
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> recordImpression(String id) async {
    final response = await _dio.post('/ads/campaigns/$id/impression');
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> recordClick(String id) async {
    final response = await _dio.post('/ads/campaigns/$id/click');
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> campaignStats(String id) async {
    final response = await _dio.get('/ads/campaigns/$id/stats');
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  // --- PAYMENTS (Paymob / PSP) ---
  Future<List<dynamic>> paymentHistory(String orgId, {int limit = 20}) async {
    final response = await _dio.get('/payments/$orgId/history', queryParameters: {'limit': limit});
    final data = response.data;
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['items'] is List) return data['items'] as List;
    return [];
  }

  Future<Map<String, dynamic>> pspStatus() async {
    final response = await _dio.get('/payments/psp/status');
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> paymobIntent({
    required String orgId,
    required num amountEgp,
    String? phone,
    String? invoiceId,
    String? method,
  }) async {
    final response = await _dio.post('/payments/psp/paymob/intent', data: {
      'org_id': orgId,
      'amount_egp': amountEgp,
      if (phone != null) 'phone': phone,
      if (invoiceId != null) 'invoice_id': invoiceId,
      if (method != null) 'method': method,
    });
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  // --- PLATFORM (brokerage + profit) ---
  Future<Map<String, dynamic>> getFee() async {
    final response = await _dio.get('/platform/config/fee');
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> setFee(num rate) async {
    final response = await _dio.post('/platform/config/fee', data: {'rate': rate});
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> revenueSummary() async {
    final response = await _dio.get('/platform/revenue/summary');
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  Future<List<dynamic>> revenueEvents({int limit = 50}) async {
    final response = await _dio.get('/platform/revenue/events', queryParameters: {'limit': limit});
    final data = response.data;
    if (data is List) return data;
    if (data is Map<String, dynamic> && data['items'] is List) return data['items'] as List;
    return [];
  }
}




