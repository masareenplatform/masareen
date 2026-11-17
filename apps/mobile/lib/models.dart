const String _defaultMediaBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://masareen.com',
);

String? resolveMediaUrl(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  if (s.isEmpty) return null;
  if (s.startsWith('http://') || s.startsWith('https://')) return s;
  if (s.startsWith('/')) {
    final base = _defaultMediaBase.replaceAll(RegExp(r'/+$'), '');
    return '$base$s';
  }
  return s;
}

class User {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String role;
  final double pmsScore;
  final bool emailVerified;
  final List<String> skills;
  final String? bio;
  final String? avatarUrl;
  final String? country;
  final String? city;
  final int? followersCount;
  final String? coverUrl;
  final bool isTester;
  final bool profilePrivate;
  final bool canMessage;
  final String? handle;
  final bool isFollowing;
  final bool isAdmin;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    required this.role,
    this.pmsScore = 0,
    this.emailVerified = false,
    this.skills = const [],
    this.bio,
    this.avatarUrl,
    this.country,
    this.city,
    this.followersCount,
    this.coverUrl,
    this.isTester = false,
    this.profilePrivate = false,
    this.canMessage = true,
    this.handle,
    this.isFollowing = false,
    this.isAdmin = false,
  });

  User copyWith({
    String? fullName,
    String? bio,
    String? avatarUrl,
    String? country,
    String? city,
    List<String>? skills,
    int? followersCount,
    bool? emailVerified,
    String? coverUrl,
    bool? isTester,
    bool? profilePrivate,
    bool? canMessage,
    String? handle,
    bool? isFollowing,
    bool? isAdmin,
  }) =>
      User(
        id: id,
        email: email,
        fullName: fullName ?? this.fullName,
        phone: phone,
        role: role,
        pmsScore: pmsScore,
        emailVerified: emailVerified ?? this.emailVerified,
        skills: skills ?? this.skills,
        bio: bio ?? this.bio,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        country: country ?? this.country,
        city: city ?? this.city,
        followersCount: followersCount ?? this.followersCount,
        coverUrl: coverUrl ?? this.coverUrl,
        isTester: isTester ?? this.isTester,
        profilePrivate: profilePrivate ?? this.profilePrivate,
        canMessage: canMessage ?? this.canMessage,
        handle: handle ?? this.handle,
        isFollowing: isFollowing ?? this.isFollowing,
        isAdmin: isAdmin ?? this.isAdmin,
      );

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] ?? '',
        email: j['email'] ?? '',
        fullName: j['full_name'] ?? j['email']?.split('@').first ?? 'User',
        phone: j['phone'],
        role: j['role'] ?? 'INDIVIDUAL',
        pmsScore:
            (j['pms_score'] is num) ? (j['pms_score'] as num).toDouble() : 0,
        emailVerified: j['email_verified'] ?? false,
        skills: (j['skills'] is List)
            ? List<String>.from(j['skills'].map((s) =>
                s is Map ? (s['skill_name'] ?? s['name'] ?? '') : s.toString()))
            : const [],
        bio: j['profile']?['bio'] ?? j['bio'],
        avatarUrl:
            resolveMediaUrl(j['profile']?['avatar_url'] ?? j['avatar_url']),
        country: j['profile']?['country'] ?? j['country'],
        city: j['profile']?['city'] ?? j['city'],
        followersCount: j['profile']?['followers_count'] is num
            ? (j['profile']?['followers_count'] as num).toInt()
            : (j['followers_count'] is num
                ? (j['followers_count'] as num).toInt()
                : null),
        coverUrl: resolveMediaUrl(j['profile']?['cover_url'] ?? j['cover_url']),
        isTester: j['is_tester'] ?? false,
        profilePrivate: j['profile_private'] == true,
        canMessage: j['can_message'] != false,
        handle: j['handle']?.toString(),
        isFollowing: j['is_following'] == true,
        isAdmin: j['is_admin'] == true,
      );

  /// Classifies the account into one of the platform's profile archetypes so the
  /// UI can render a tailored profile layout (media / government / sports / org / individual).
  String get roleType {
    final r = role.toUpperCase();
    if (r.contains('MEDIA') || r.contains('PRESS') || r.contains('NEWS')) {
      return 'MEDIA';
    }
    if (r.contains('GOV') ||
        r.contains('GOVERNMENT') ||
        r.contains('MINISTRY')) {
      return 'GOVERNMENT';
    }
    if (r.contains('SPORT') || r.contains('CLUB') || r.contains('ATHLETE')) {
      return 'SPORTS';
    }
    if (r.contains('ORG') ||
        r.contains('NGO') ||
        r.contains('COMPANY') ||
        r.contains('INSTITUTION')) {
      return 'ORGANIZATION';
    }
    return 'INDIVIDUAL';
  }
}

class UserSettings {
  final bool pushEnabled;
  final bool emailEnabled;
  final bool opportunityAlerts;
  final bool socialAlerts;
  final bool messageAlerts;
  final String digestFrequency;
  final int? quietStart;
  final int? quietEnd;
  final String profileVisibility;
  final String messagePrivacy;
  final bool showEmail;

  UserSettings({
    this.pushEnabled = true,
    this.emailEnabled = true,
    this.opportunityAlerts = true,
    this.socialAlerts = true,
    this.messageAlerts = true,
    this.digestFrequency = 'instant',
    this.quietStart,
    this.quietEnd,
    this.profileVisibility = 'public',
    this.messagePrivacy = 'everyone',
    this.showEmail = false,
  });

  factory UserSettings.fromJson(Map<String, dynamic> j) => UserSettings(
        pushEnabled: j['push_enabled'] != false,
        emailEnabled: j['email_enabled'] != false,
        opportunityAlerts: j['opportunity_alerts'] != false,
        socialAlerts: j['social_alerts'] != false,
        messageAlerts: j['message_alerts'] != false,
        digestFrequency: (j['digest_frequency'] ?? 'instant').toString(),
        quietStart:
            j['quiet_start'] is num ? (j['quiet_start'] as num).toInt() : null,
        quietEnd:
            j['quiet_end'] is num ? (j['quiet_end'] as num).toInt() : null,
        profileVisibility: (j['profile_visibility'] ?? 'public').toString(),
        messagePrivacy: (j['message_privacy'] ?? 'everyone').toString(),
        showEmail: j['show_email'] == true,
      );

  UserSettings copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? opportunityAlerts,
    bool? socialAlerts,
    bool? messageAlerts,
    String? digestFrequency,
    int? quietStart,
    int? quietEnd,
    bool clearQuietHours = false,
    String? profileVisibility,
    String? messagePrivacy,
    bool? showEmail,
  }) =>
      UserSettings(
        pushEnabled: pushEnabled ?? this.pushEnabled,
        emailEnabled: emailEnabled ?? this.emailEnabled,
        opportunityAlerts: opportunityAlerts ?? this.opportunityAlerts,
        socialAlerts: socialAlerts ?? this.socialAlerts,
        messageAlerts: messageAlerts ?? this.messageAlerts,
        digestFrequency: digestFrequency ?? this.digestFrequency,
        quietStart: clearQuietHours ? null : (quietStart ?? this.quietStart),
        quietEnd: clearQuietHours ? null : (quietEnd ?? this.quietEnd),
        profileVisibility: profileVisibility ?? this.profileVisibility,
        messagePrivacy: messagePrivacy ?? this.messagePrivacy,
        showEmail: showEmail ?? this.showEmail,
      );
}

class DiscoveryItem {
  final String type;
  final String id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final int impactPercent;
  final bool verified;

  const DiscoveryItem({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle = '',
    this.imageUrl,
    this.impactPercent = 0,
    this.verified = false,
  });

  factory DiscoveryItem.fromJson(Map<String, dynamic> j) => DiscoveryItem(
        type: (j['entity_type'] ?? 'ENTITY').toString(),
        id: (j['entity_id'] ?? '').toString(),
        title: (j['title'] ?? 'Untitled').toString(),
        subtitle: (j['subtitle'] ?? '').toString(),
        imageUrl: resolveMediaUrl(j['image_url']?.toString()),
        impactPercent: j['impact_percent'] is num
            ? (j['impact_percent'] as num).round()
            : 0,
        verified: j['verified'] == true,
      );
}

class PostMedia {
  final String url;
  final String type;
  final String? caption;
  final String? hlsUrl;
  final String? posterUrl;
  final double? durationSeconds;

  PostMedia({
    required this.url,
    this.type = 'IMAGE',
    this.caption,
    this.hlsUrl,
    this.posterUrl,
    this.durationSeconds,
  });

  bool get isVideo => type.toUpperCase() == 'VIDEO';
  bool get isAudio => type.toUpperCase() == 'AUDIO';

  factory PostMedia.fromJson(Map<String, dynamic> j) => PostMedia(
        url: resolveMediaUrl(j['url'] ?? j['content_url']) ?? '',
        type: (j['type'] ?? 'IMAGE').toString().toUpperCase(),
        caption: j['caption']?.toString(),
        hlsUrl: resolveMediaUrl(j['hls_url']),
        posterUrl: resolveMediaUrl(j['poster_url']),
        durationSeconds: j['duration_seconds'] is num
            ? (j['duration_seconds'] as num).toDouble()
            : null,
      );
}

class PostFile {
  final String url;
  final String name;
  final int? size;
  final String? contentType;

  PostFile({
    required this.url,
    this.name = 'Attachment',
    this.size,
    this.contentType,
  });

  bool get isPdf =>
      (contentType ?? '').contains('pdf') || url.toLowerCase().contains('.pdf');

  String get sizeLabel {
    final bytes = size ?? 0;
    if (bytes <= 0) return '';
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).ceil()} KB';
  }

  factory PostFile.fromJson(Map<String, dynamic> j) => PostFile(
        url: resolveMediaUrl(j['url']) ?? '',
        name: (j['name'] ?? 'Attachment').toString(),
        size: j['size'] is num ? (j['size'] as num).toInt() : null,
        contentType: j['content_type']?.toString(),
      );
}

class Post {
  final String id;
  final Author author;
  final String text;
  final String? kind;
  final String? programTag;
  final int? sdg;
  final double? impactValue;
  final String? impactLabel;
  final String? type;
  final String? contentUrl;
  final String? linkUrl;
  final List<PostMedia> media;
  final List<PostFile> files;
  final String? mediaType;
  final String? videoHlsUrl;
  final String? videoPosterUrl;
  final double? latitude;
  final double? longitude;
  final bool verifiedContent;
  final double? isaScore;
  final Map<String, dynamic>? impactDomains;
  final int geoLevel;
  final String? impactMethod;
  final bool promoted;
  final String? boostedUntil;
  final double paidMrc;
  final int likes;
  final int comments;
  final int shares;
  final List<Author> sharedBy;
  final bool likedByMe;
  final bool bookmarkedByMe;
  final List<Comment> commentList;
  final List<Comment> topComments;
  final String? createdAt;
  final String? editedAt;
  final double? confidenceScore;
  final String? confidenceLabel;
  final Map<String, dynamic>? confidenceFactors;
  final double? rankingScore;
  final String? rankingReason;
  final Map<String, dynamic>? structured;
  final String moderationStatus;
  final String deepfakeVerdict;
  final double deepfakeScore;
  final String captureSource;
  final double captureTrust;

  Post({
    required this.id,
    required this.author,
    required this.text,
    this.kind,
    this.programTag,
    this.sdg,
    this.impactValue,
    this.impactLabel,
    this.type,
    this.contentUrl,
    this.linkUrl,
    this.media = const [],
    this.files = const [],
    this.mediaType,
    this.videoHlsUrl,
    this.videoPosterUrl,
    this.latitude,
    this.longitude,
    this.verifiedContent = false,
    this.isaScore,
    this.impactDomains,
    this.geoLevel = 0,
    this.impactMethod,
    this.promoted = false,
    this.boostedUntil,
    this.paidMrc = 0,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.sharedBy = const [],
    this.likedByMe = false,
    this.bookmarkedByMe = false,
    this.commentList = const [],
    this.topComments = const [],
    this.createdAt,
    this.editedAt,
    this.confidenceScore,
    this.confidenceLabel,
    this.confidenceFactors,
    this.rankingScore,
    this.rankingReason,
    this.structured,
    this.moderationStatus = 'APPROVED',
    this.deepfakeVerdict = 'UNSCANNED',
    this.deepfakeScore = 0,
    this.captureSource = 'UNKNOWN',
    this.captureTrust = 0,
  });

  factory Post.fromJson(Map<String, dynamic> j) => Post(
        id: j['id'] ?? '',
        author: Author.fromJson(j['author'] ?? {}),
        text: j['text'] ?? '',
        kind: j['kind'],
        programTag: j['programTag'],
        sdg: j['sdg'] is num ? (j['sdg'] as num).toInt() : null,
        impactValue: j['impactValue'] is num
            ? (j['impactValue'] as num).toDouble()
            : null,
        impactLabel: j['impactLabel'],
        type: j['type'],
        contentUrl: resolveMediaUrl(j['content_url'] ?? j['url']),
        linkUrl: j['link_url'] ?? j['linkUrl'],
        media: (j['media'] is List)
            ? (j['media'] as List)
                .whereType<Map>()
                .map((m) => PostMedia.fromJson(Map<String, dynamic>.from(m)))
                .where((m) => m.url.isNotEmpty)
                .toList()
            : const [],
        files: (j['files'] is List)
            ? (j['files'] as List)
                .whereType<Map>()
                .map((f) => PostFile.fromJson(Map<String, dynamic>.from(f)))
                .where((f) => f.url.isNotEmpty)
                .toList()
            : const [],
        mediaType: j['media_type'],
        videoHlsUrl: resolveMediaUrl(j['video_hls_url']),
        videoPosterUrl: resolveMediaUrl(j['video_poster_url']),
        latitude:
            j['latitude'] is num ? (j['latitude'] as num).toDouble() : null,
        longitude:
            j['longitude'] is num ? (j['longitude'] as num).toDouble() : null,
        verifiedContent: j['verified_content'] ?? false,
        isaScore:
            j['isa_score'] is num ? (j['isa_score'] as num).toDouble() : null,
        impactDomains: j['impact_domains'] is Map
            ? Map<String, dynamic>.from(j['impact_domains'] as Map)
            : null,
        geoLevel: j['geo_level'] is num ? (j['geo_level'] as num).toInt() : 0,
        impactMethod: j['impact_method'],
        promoted: j['promoted'] == true,
        boostedUntil: j['boosted_until'],
        paidMrc: j['paid_mrc'] is num ? (j['paid_mrc'] as num).toDouble() : 0,
        likes: j['likes'] is num ? (j['likes'] as num).toInt() : 0,
        comments: (j['comments'] is List)
            ? (j['comments'] as List).length
            : (j['comments'] is num ? (j['comments'] as num).toInt() : 0),
        shares: j['shares'] is num ? (j['shares'] as num).toInt() : 0,
        sharedBy: (j['shared_by'] is List)
            ? (j['shared_by'] as List)
                .whereType<Map>()
                .map((u) => Author.fromJson(Map<String, dynamic>.from(u)))
                .toList()
            : const [],
        likedByMe: j['likedByMe'] ?? false,
        bookmarkedByMe: j['bookmarkedByMe'] ?? false,
        commentList: (j['comments'] is List)
            ? (j['comments'] as List)
                .map((c) => Comment.fromJson(c as Map<String, dynamic>))
                .toList()
            : const [],
        topComments: (j['top_comments'] is List)
            ? (j['top_comments'] as List)
                .whereType<Map>()
                .map((c) => Comment.fromJson(Map<String, dynamic>.from(c)))
                .toList()
            : const [],
        createdAt: j['createdAt'] ?? j['created_at'],
        editedAt: j['edited_at'] ?? j['editedAt'],
        confidenceScore: j['confidence_score'] is num
            ? (j['confidence_score'] as num).toDouble()
            : null,
        confidenceLabel: j['confidence_label'],
        confidenceFactors: j['confidence_factors'] is Map
            ? Map<String, dynamic>.from(j['confidence_factors'] as Map)
            : null,
        rankingScore: j['ranking_score'] is num
            ? (j['ranking_score'] as num).toDouble()
            : null,
        rankingReason: j['ranking_reason'],
        structured: j['structured'] is Map
            ? Map<String, dynamic>.from(j['structured'] as Map)
            : null,
        moderationStatus: j['moderation_status']?.toString() ?? 'APPROVED',
        deepfakeVerdict: j['deepfake_verdict']?.toString() ?? 'UNSCANNED',
        deepfakeScore: j['deepfake_score'] is num
            ? (j['deepfake_score'] as num).toDouble()
            : 0,
        captureSource: j['capture_source']?.toString() ?? 'UNKNOWN',
        captureTrust: j['capture_trust'] is num
            ? (j['capture_trust'] as num).toDouble()
            : 0,
      );

  Post copyWith({
    Author? author,
    String? text,
    int? likes,
    bool? likedByMe,
    bool? bookmarkedByMe,
    int? comments,
    List<Comment>? commentList,
    int? shares,
    List<Author>? sharedBy,
    String? editedAt,
    double? confidenceScore,
    String? confidenceLabel,
    Map<String, dynamic>? confidenceFactors,
    double? rankingScore,
    String? rankingReason,
    double? impactValue,
    String? impactLabel,
    String? deepfakeVerdict,
    double? deepfakeScore,
    String? captureSource,
    double? captureTrust,
  }) =>
      Post(
        id: id,
        author: author ?? this.author,
        text: text ?? this.text,
        kind: kind,
        programTag: programTag,
        sdg: sdg,
        impactValue: impactValue ?? this.impactValue,
        impactLabel: impactLabel ?? this.impactLabel,
        type: type,
        contentUrl: contentUrl,
        linkUrl: linkUrl,
        media: media,
        files: files,
        mediaType: mediaType,
        videoHlsUrl: videoHlsUrl,
        videoPosterUrl: videoPosterUrl,
        latitude: latitude,
        longitude: longitude,
        verifiedContent: verifiedContent,
        likes: likes ?? this.likes,
        comments: comments ?? this.comments,
        shares: shares ?? this.shares,
        sharedBy: sharedBy ?? this.sharedBy,
        likedByMe: likedByMe ?? this.likedByMe,
        bookmarkedByMe: bookmarkedByMe ?? this.bookmarkedByMe,
        commentList: commentList ?? this.commentList,
        createdAt: createdAt,
        editedAt: editedAt ?? this.editedAt,
        confidenceScore: confidenceScore ?? this.confidenceScore,
        confidenceLabel: confidenceLabel ?? this.confidenceLabel,
        confidenceFactors: confidenceFactors ?? this.confidenceFactors,
        rankingScore: rankingScore ?? this.rankingScore,
        rankingReason: rankingReason ?? this.rankingReason,
        deepfakeVerdict: deepfakeVerdict ?? this.deepfakeVerdict,
        deepfakeScore: deepfakeScore ?? this.deepfakeScore,
        captureSource: captureSource ?? this.captureSource,
        captureTrust: captureTrust ?? this.captureTrust,
      );
}

class Author {
  final String id;
  final String name;
  final String? handle;
  final bool verified;
  final String? role;
  final String? avatarUrl;
  final bool isFollowing;
  Author(
      {required this.id,
      required this.name,
      this.handle,
      this.verified = false,
      this.role,
      this.avatarUrl,
      this.isFollowing = false});
  Author copyWith({
    String? name,
    String? handle,
    bool? verified,
    String? role,
    String? avatarUrl,
    bool? isFollowing,
  }) =>
      Author(
        id: id,
        name: name ?? this.name,
        handle: handle ?? this.handle,
        verified: verified ?? this.verified,
        role: role ?? this.role,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        isFollowing: isFollowing ?? this.isFollowing,
      );

  factory Author.fromJson(Map<String, dynamic> j) => Author(
        id: j['id'] ?? '',
        name: j['name'] ?? 'Unknown',
        handle: j['handle'],
        verified: j['verified'] ?? false,
        role: j['role'],
        avatarUrl: resolveMediaUrl(j['avatar_url'] ?? j['picture']),
        isFollowing: j['is_following'] == true,
      );
}

List<Author> authorsFromJson(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((e) => Author.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

class Comment {
  final String? id;
  final String text;
  final String? authorId;
  final String? authorName;
  final String? authorHandle;
  final String? authorPicture;
  final bool authorVerified;
  final String? parentId;
  final int likeCount;
  final bool likedByMe;
  final String? createdAt;
  Comment({
    this.id,
    required this.text,
    this.authorId,
    this.authorName,
    this.authorHandle,
    this.authorPicture,
    this.authorVerified = false,
    this.parentId,
    this.likeCount = 0,
    this.likedByMe = false,
    this.createdAt,
  });
  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: j['id']?.toString(),
        text: j['text'] ?? '',
        authorId: j['author_id']?.toString() ?? j['userId']?.toString(),
        authorName: j['author_name'] ?? j['authorName'] ?? 'User',
        authorHandle: j['author_handle'],
        authorPicture: j['author_picture'] ?? j['avatar_url'],
        authorVerified: j['author_verified'] ?? false,
        parentId: j['parent_id']?.toString(),
        likeCount:
            j['like_count'] is num ? (j['like_count'] as num).toInt() : 0,
        likedByMe: j['liked_by_me'] ?? false,
        createdAt: j['created_at'] ?? j['createdAt'],
      );

  Comment copyWith({int? likeCount, bool? likedByMe}) => Comment(
        id: id,
        text: text,
        authorId: authorId,
        authorName: authorName,
        authorHandle: authorHandle,
        authorPicture: authorPicture,
        authorVerified: authorVerified,
        parentId: parentId,
        likeCount: likeCount ?? this.likeCount,
        likedByMe: likedByMe ?? this.likedByMe,
        createdAt: createdAt,
      );
}

class Conversation {
  final String id;
  final Author peer;
  final String? lastMessage;
  final String? lastMessageAt;
  final String? lastSenderId;
  final int unreadCount;
  Conversation({
    required this.id,
    required this.peer,
    this.lastMessage,
    this.lastMessageAt,
    this.lastSenderId,
    this.unreadCount = 0,
  });
  factory Conversation.fromJson(Map<String, dynamic> j) {
    final p = Map<String, dynamic>.from(j['peer'] as Map? ?? {});
    return Conversation(
      id: j['id']?.toString() ?? '',
      peer: Author.fromJson(p),
      lastMessage: j['last_message'],
      lastMessageAt: j['last_message_at'],
      lastSenderId: j['last_sender_id']?.toString(),
      unreadCount:
          j['unread_count'] is num ? (j['unread_count'] as num).toInt() : 0,
    );
  }
}

class ChatMessage {
  final String id;
  final String body;
  final String senderId;
  final bool mine;
  final bool read;
  final String? createdAt;
  ChatMessage({
    required this.id,
    required this.body,
    required this.senderId,
    this.mine = false,
    this.read = false,
    this.createdAt,
  });
  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id']?.toString() ?? '',
        body: j['body'] ?? j['text'] ?? '',
        senderId: j['sender_id']?.toString() ?? '',
        mine: j['mine'] ?? false,
        read: j['read'] ?? false,
        createdAt: j['created_at'],
      );
}

class ChatThread {
  final Conversation conversation;
  final List<ChatMessage> messages;
  ChatThread({required this.conversation, required this.messages});
  factory ChatThread.fromJson(Map<String, dynamic> j) => ChatThread(
        conversation: Conversation.fromJson(
            Map<String, dynamic>.from(j['conversation'] as Map? ?? {})),
        messages: (j['messages'] is List)
            ? (j['messages'] as List)
                .whereType<Map>()
                .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
                .toList()
            : const [],
      );
}

class HashtagTrend {
  final String tag;
  final int count;
  HashtagTrend({required this.tag, this.count = 0});
  factory HashtagTrend.fromJson(Map<String, dynamic> j) => HashtagTrend(
        tag: j['tag']?.toString() ?? '',
        count: j['count'] is num ? (j['count'] as num).toInt() : 0,
      );
}

class SocialSearchResult {
  final String query;
  final List<Author> users;
  final List<Post> posts;
  final List<HashtagTrend> hashtags;
  SocialSearchResult({
    required this.query,
    this.users = const [],
    this.posts = const [],
    this.hashtags = const [],
  });
  factory SocialSearchResult.fromJson(Map<String, dynamic> j) =>
      SocialSearchResult(
        query: j['query']?.toString() ?? '',
        users: (j['users'] is List)
            ? (j['users'] as List)
                .whereType<Map>()
                .map((u) => Author.fromJson(Map<String, dynamic>.from(u)))
                .toList()
            : const [],
        posts: (j['posts'] is List)
            ? (j['posts'] as List)
                .whereType<Map>()
                .map((p) => Post.fromJson(Map<String, dynamic>.from(p)))
                .toList()
            : const [],
        hashtags: (j['hashtags'] is List)
            ? (j['hashtags'] as List)
                .whereType<Map>()
                .map((h) => HashtagTrend.fromJson(Map<String, dynamic>.from(h)))
                .toList()
            : const [],
      );
}

class Wallet {
  final String ownerId;
  final double balance;
  final String currency;
  final double dailyReward;
  final bool claimedToday;
  final String? lastClaimAt;
  Wallet({
    required this.ownerId,
    required this.balance,
    this.currency = 'MRC',
    this.dailyReward = 10,
    this.claimedToday = false,
    this.lastClaimAt,
  });
  factory Wallet.fromJson(Map<String, dynamic> j) => Wallet(
        ownerId: j['owner_id']?.toString() ?? '',
        balance: (j['balance'] is num) ? (j['balance'] as num).toDouble() : 0,
        currency: j['currency']?.toString() ?? 'MRC',
        dailyReward: (j['daily_reward'] is num)
            ? (j['daily_reward'] as num).toDouble()
            : 10,
        claimedToday: j['claimed_today'] == true,
        lastClaimAt: j['last_claim_at']?.toString(),
      );
}

class GpsRecord {
  final String id;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;
  final String? capturedAt;
  final String? createdAt;
  GpsRecord({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    this.capturedAt,
    this.createdAt,
  });
  factory GpsRecord.fromJson(Map<String, dynamic> j) => GpsRecord(
        id: j['id']?.toString() ?? '',
        latitude:
            (j['latitude'] is num) ? (j['latitude'] as num).toDouble() : 0,
        longitude:
            (j['longitude'] is num) ? (j['longitude'] as num).toDouble() : 0,
        accuracy:
            (j['accuracy'] is num) ? (j['accuracy'] as num).toDouble() : null,
        altitude:
            (j['altitude'] is num) ? (j['altitude'] as num).toDouble() : null,
        speed: (j['speed'] is num) ? (j['speed'] as num).toDouble() : null,
        heading:
            (j['heading'] is num) ? (j['heading'] as num).toDouble() : null,
        capturedAt: j['captured_at']?.toString(),
        createdAt: j['created_at']?.toString(),
      );
  String get mapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
}

class CoinTx {
  final String? id;
  final String type;
  final double amount;
  final double balanceAfter;
  final String? reference;
  final String? createdAt;
  CoinTx({
    this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.reference,
    this.createdAt,
  });
  factory CoinTx.fromJson(Map<String, dynamic> j) => CoinTx(
        id: j['id']?.toString(),
        type: j['type']?.toString() ?? '',
        amount: (j['amount'] is num) ? (j['amount'] as num).toDouble() : 0,
        balanceAfter: (j['balance_after'] is num)
            ? (j['balance_after'] as num).toDouble()
            : 0,
        reference: j['reference'],
        createdAt: j['created_at'] ?? j['createdAt'],
      );
}

class Creative {
  final String? id;
  final String? campaignId;
  final String title;
  final String? body;
  final String? mediaUrl;
  final String? ctaUrl;
  final String? ctaLabel;
  final String mediaType;
  final int sortOrder;

  Creative({
    this.id,
    this.campaignId,
    required this.title,
    this.body,
    this.mediaUrl,
    this.ctaUrl,
    this.ctaLabel,
    this.mediaType = 'image',
    this.sortOrder = 0,
  });

  bool get isVideo => mediaType == 'video';
  bool get isText => mediaType == 'text';

  factory Creative.fromJson(Map<String, dynamic> j) => Creative(
        id: j['id']?.toString(),
        campaignId: j['campaign_id']?.toString(),
        title: j['title'] ?? '',
        body: j['body'] ?? j['text'],
        mediaUrl: resolveMediaUrl(j['media_url'] ?? j['mediaUrl']),
        ctaUrl: j['cta_url'] ?? j['ctaUrl'],
        ctaLabel: j['cta_label'] ?? j['ctaLabel'],
        mediaType: (j['media_type'] ?? j['mediaType'] ?? 'image').toString(),
        sortOrder:
            (j['sort_order'] is num) ? (j['sort_order'] as num).toInt() : 0,
      );
}

class Campaign {
  final String id;
  final String userId;
  final String name;
  final String status;
  final String objective;
  final String placement;
  final double budget;
  final double funded;
  final double spent;
  final double remaining;
  final String currency;
  final List<Creative> creatives;
  final Map<String, dynamic> targeting;
  final String? startAt;
  final String? endAt;
  final String? ownerName;
  final int impressions;
  final int clicks;
  final double ctr;
  final double ctrPercent;
  final double cpc;
  final Map<String, dynamic>? stats;

  Campaign({
    required this.id,
    this.userId = '',
    required this.name,
    required this.status,
    required this.budget,
    this.funded = 0,
    this.spent = 0,
    this.remaining = 0,
    this.currency = 'MRC',
    this.objective = 'awareness',
    this.placement = 'feed',
    this.creatives = const [],
    this.targeting = const {},
    this.startAt,
    this.endAt,
    this.ownerName,
    this.impressions = 0,
    this.clicks = 0,
    this.ctr = 0,
    this.ctrPercent = 0,
    this.cpc = 0,
    this.stats,
  });

  Creative? get primaryCreative => creatives.isEmpty ? null : creatives.first;

  double get budgetProgress {
    if (budget <= 0) return 0;
    return (spent / budget).clamp(0.0, 1.0);
  }

  factory Campaign.fromJson(Map<String, dynamic> j) => Campaign(
        id: j['id']?.toString() ?? '',
        userId: j['user_id']?.toString() ?? '',
        name: j['name'] ?? 'Campaign',
        status: (j['status']?.toString() ?? 'DRAFT').toUpperCase(),
        objective: j['objective']?.toString() ?? 'awareness',
        placement: j['placement']?.toString() ?? 'feed',
        budget: (j['budget_coins'] is num)
            ? (j['budget_coins'] as num).toDouble()
            : ((j['budget'] is num) ? (j['budget'] as num).toDouble() : 0),
        funded: (j['funded_coins'] is num)
            ? (j['funded_coins'] as num).toDouble()
            : 0,
        spent: (j['spent_coins'] is num)
            ? (j['spent_coins'] as num).toDouble()
            : 0,
        remaining: (j['remaining_coins'] is num)
            ? (j['remaining_coins'] as num).toDouble()
            : 0,
        currency: j['currency']?.toString() ?? 'MRC',
        creatives: (j['creatives'] is List)
            ? (j['creatives'] as List)
                .map((c) => Creative.fromJson(c as Map<String, dynamic>))
                .toList()
            : const [],
        targeting: j['targeting'] is Map
            ? Map<String, dynamic>.from(j['targeting'] as Map)
            : const {},
        startAt: j['start_at']?.toString(),
        endAt: j['end_at']?.toString(),
        ownerName: j['owner_name']?.toString(),
        impressions:
            j['impressions'] is num ? (j['impressions'] as num).toInt() : 0,
        clicks: j['clicks'] is num ? (j['clicks'] as num).toInt() : 0,
        ctr: j['ctr'] is num ? (j['ctr'] as num).toDouble() : 0,
        ctrPercent:
            j['ctr_percent'] is num ? (j['ctr_percent'] as num).toDouble() : 0,
        cpc: j['cpc'] is num ? (j['cpc'] as num).toDouble() : 0,
        stats: j['stats'] is Map ? Map<String, dynamic>.from(j['stats']) : null,
      );

  Campaign copyWith({String? status, List<Creative>? creatives}) => Campaign(
        id: id,
        userId: userId,
        name: name,
        status: status ?? this.status,
        objective: objective,
        placement: placement,
        budget: budget,
        funded: funded,
        spent: spent,
        remaining: remaining,
        currency: currency,
        creatives: creatives ?? this.creatives,
        targeting: targeting,
        startAt: startAt,
        endAt: endAt,
        ownerName: ownerName,
        impressions: impressions,
        clicks: clicks,
        ctr: ctr,
        ctrPercent: ctrPercent,
        cpc: cpc,
        stats: stats,
      );
}

class Opportunity {
  final String id;
  final String title;
  final String? description;
  final List<dynamic> skills;
  final int? sdg;
  final double? minPms;
  final String? location;
  final String? status;
  final String? type;
  final String? deadline;
  final bool isRemote;
  final int applicationsCount;
  final bool applied;
  final Author? author;
  final String verificationStatus;
  final String? rejectionReason;
  final double creationFeeMrc;
  final String? coverUrl;

  Opportunity({
    required this.id,
    required this.title,
    this.description,
    this.skills = const [],
    this.sdg,
    this.minPms,
    this.location,
    this.status,
    this.type,
    this.deadline,
    this.isRemote = false,
    this.author,
    this.applicationsCount = 0,
    this.applied = false,
    this.verificationStatus = 'APPROVED',
    this.rejectionReason,
    this.creationFeeMrc = 0,
    this.coverUrl,
  });

  factory Opportunity.fromJson(Map<String, dynamic> j) => Opportunity(
        id: j['id']?.toString() ?? '',
        title: j['title'] ?? 'Opportunity',
        description: j['description'],
        skills:
            (j['skills'] is List) ? List<dynamic>.from(j['skills']) : const [],
        sdg: j['sdg'] is num ? (j['sdg'] as num).toInt() : null,
        minPms: j['min_pms'] is num ? (j['min_pms'] as num).toDouble() : null,
        location: j['location'] is Map
            ? j['location']['name']?.toString()
            : j['location']?.toString(),
        status: j['status'],
        type: j['type']?.toString(),
        deadline: j['deadline']?.toString(),
        isRemote: j['is_remote'] == true || j['is_remote'] == 1,
        applicationsCount: j['applications_count'] is num
            ? (j['applications_count'] as num).toInt()
            : 0,
        applied: j['applied'] == true,
        author: j['author'] is Map ? Author.fromJson(j['author']) : null,
        verificationStatus: j['verification_status'] ?? 'APPROVED',
        rejectionReason: j['rejection_reason'],
        creationFeeMrc: (j['creation_fee_mrc'] is num)
            ? (j['creation_fee_mrc'] as num).toDouble()
            : 0,
        coverUrl: j['cover_url'],
      );
}

class Program {
  final String id;
  final String title;
  final String? description;
  final String? status;
  final int? sdg;
  final int? members;
  final String? category;
  final String? organization;
  final double budget;
  final String? currency;
  final String? country;
  final String? governorate;
  final String? startDate;
  final String? endDate;
  final int targetBeneficiaries;
  final int projectsCount;
  final int tasksCount;
  final bool enrolledByMe;
  final Author? author;
  final String verificationStatus;
  final String? rejectionReason;
  final double creationFeeMrc;
  final String? coverUrl;
  final List<Author> membersPreview;

  Program({
    required this.id,
    required this.title,
    this.description,
    this.status,
    this.sdg,
    this.members,
    this.category,
    this.organization,
    this.author,
    this.budget = 0,
    this.currency,
    this.country,
    this.governorate,
    this.startDate,
    this.endDate,
    this.targetBeneficiaries = 0,
    this.projectsCount = 0,
    this.tasksCount = 0,
    this.enrolledByMe = false,
    this.verificationStatus = 'APPROVED',
    this.rejectionReason,
    this.creationFeeMrc = 0,
    this.coverUrl,
    this.membersPreview = const [],
  });

  factory Program.fromJson(Map<String, dynamic> j) => Program(
        id: j['id']?.toString() ?? '',
        title: j['title'] ?? 'Program',
        description: j['description'],
        status: j['status'],
        sdg: j['sdg'] is num ? (j['sdg'] as num).toInt() : null,
        members: j['members_count'] is num
            ? (j['members_count'] as num).toInt()
            : (j['members'] is num ? (j['members'] as num).toInt() : null),
        category: j['category']?.toString(),
        organization: j['organization']?.toString(),
        budget: (j['budget'] is num) ? (j['budget'] as num).toDouble() : 0,
        currency: j['currency']?.toString(),
        country: j['country']?.toString(),
        governorate: j['governorate']?.toString(),
        startDate: j['start_date']?.toString(),
        endDate: j['end_date']?.toString(),
        targetBeneficiaries: j['target_beneficiaries'] is num
            ? (j['target_beneficiaries'] as num).toInt()
            : 0,
        projectsCount: j['projects_count'] is num
            ? (j['projects_count'] as num).toInt()
            : 0,
        tasksCount:
            j['tasks_count'] is num ? (j['tasks_count'] as num).toInt() : 0,
        enrolledByMe: j['enrolled_by_me'] == true,
        author: j['author'] is Map ? Author.fromJson(j['author']) : null,
        verificationStatus: j['verification_status'] ?? 'APPROVED',
        rejectionReason: j['rejection_reason'],
        creationFeeMrc: (j['creation_fee_mrc'] is num)
            ? (j['creation_fee_mrc'] as num).toDouble()
            : 0,
        coverUrl: j['cover_url'],
        membersPreview: authorsFromJson(j['members_preview']),
      );
}

class AppNotification {
  final String id;
  final String? type;
  final String title;
  final String? body;
  final bool read;
  final String? createdAt;
  final String? link;
  final String? entityType;
  final String? entityId;
  AppNotification({
    required this.id,
    this.type,
    required this.title,
    this.body,
    this.read = false,
    this.createdAt,
    this.link,
    this.entityType,
    this.entityId,
  });
  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id']?.toString() ?? '',
        type: j['type'],
        title: j['title'] ?? j['data']?['title'] ?? 'Notification',
        body: j['body'] ?? j['data']?['body'],
        read: j['read'] ?? j['is_read'] ?? false,
        createdAt: j['created_at'] ?? j['createdAt'],
        link: j['link']?.toString(),
        entityType: j['entity_type']?.toString(),
        entityId: j['entity_id']?.toString(),
      );
}

class Announcement {
  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final String? linkUrl;
  final String? ctaLabel;
  final String? activeUntil;
  final String? createdAt;
  final bool dismissed;
  Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    this.linkUrl,
    this.ctaLabel,
    this.activeUntil,
    this.createdAt,
    this.dismissed = false,
  });
  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? 'MASAREEN',
        body: j['body']?.toString() ?? '',
        imageUrl: resolveMediaUrl(j['image_url']),
        linkUrl: j['link_url']?.toString(),
        ctaLabel: j['cta_label']?.toString(),
        activeUntil: j['active_until']?.toString(),
        createdAt: j['created_at']?.toString(),
        dismissed: j['dismissed'] == true,
      );
}

class Course {
  final String id;
  final String title;
  final String? description;
  final String? provider;
  final Author? author;
  final String level;
  final int? sdg;
  final int lessons;
  final int durationMin;
  final String? thumbnail;
  final String status;
  final int enrolledCount;
  final bool enrolledByMe;
  final String verificationStatus;
  final String? rejectionReason;
  final double creationFeeMrc;
  final bool isFree;
  final double priceMrc;
  final List<Author> membersPreview;
  Course({
    required this.id,
    required this.title,
    this.description,
    this.provider,
    this.author,
    this.level = 'Beginner',
    this.sdg,
    this.lessons = 0,
    this.durationMin = 0,
    this.thumbnail,
    this.status = 'PUBLISHED',
    this.enrolledCount = 0,
    this.enrolledByMe = false,
    this.verificationStatus = 'APPROVED',
    this.rejectionReason,
    this.creationFeeMrc = 0,
    this.isFree = true,
    this.priceMrc = 0,
    this.membersPreview = const [],
  });
  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: j['id'] ?? '',
        title: j['title'] ?? 'Course',
        description: j['description'],
        provider: j['provider'],
        author: j['author'] is Map ? Author.fromJson(j['author']) : null,
        level: j['level'] ?? 'Beginner',
        sdg: j['sdg'] is num ? (j['sdg'] as num).toInt() : null,
        lessons: j['lessons'] is num ? (j['lessons'] as num).toInt() : 0,
        durationMin:
            j['duration_min'] is num ? (j['duration_min'] as num).toInt() : 0,
        thumbnail: j['thumbnail'],
        status: j['status'] ?? 'PUBLISHED',
        enrolledCount: j['enrolled_count'] is num
            ? (j['enrolled_count'] as num).toInt()
            : 0,
        enrolledByMe: j['enrolled_by_me'] == true,
        verificationStatus: j['verification_status'] ?? 'APPROVED',
        rejectionReason: j['rejection_reason'],
        creationFeeMrc: (j['creation_fee_mrc'] is num)
            ? (j['creation_fee_mrc'] as num).toDouble()
            : 0,
        isFree: j['is_free'] != false,
        priceMrc:
            (j['price_mrc'] is num) ? (j['price_mrc'] as num).toDouble() : 0,
        membersPreview: authorsFromJson(j['members_preview']),
      );
}

class LessonLink {
  final String url;
  final String label;
  LessonLink({required this.url, required this.label});
  factory LessonLink.fromJson(Map<String, dynamic> j) => LessonLink(
        url: resolveMediaUrl(j['url']) ?? '',
        label: (j['label'] ?? j['url'] ?? '').toString(),
      );
}

List<PostMedia> postMediaFromJson(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((e) => PostMedia.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

List<PostFile> postFilesFromJson(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((e) => PostFile.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

class CourseLesson {
  final String id;
  final String courseId;
  final String title;
  final String? description;
  final String? content;
  final String? videoUrl;
  final int durationMin;
  final int position;
  final bool isPreview;
  final bool locked;
  final List<PostMedia> media;
  final List<PostFile> files;
  final List<LessonLink> links;
  CourseLesson({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    this.content,
    this.videoUrl,
    this.durationMin = 0,
    this.position = 0,
    this.isPreview = false,
    this.locked = false,
    this.media = const [],
    this.files = const [],
    this.links = const [],
  });
  factory CourseLesson.fromJson(Map<String, dynamic> j) => CourseLesson(
        id: j['id']?.toString() ?? '',
        courseId: j['course_id']?.toString() ?? '',
        title: j['title'] ?? 'Lesson',
        description: j['description'],
        content: j['content'],
        videoUrl: j['video_url'],
        durationMin:
            j['duration_min'] is num ? (j['duration_min'] as num).toInt() : 0,
        position: j['position'] is num ? (j['position'] as num).toInt() : 0,
        isPreview: j['is_preview'] == true,
        locked: j['locked'] == true,
        media: postMediaFromJson(j['media']),
        files: postFilesFromJson(j['files']),
        links: (j['links'] is List)
            ? (j['links'] as List)
                .whereType<Map>()
                .map((e) => LessonLink.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
      );
}

class Event {
  final String id;
  final String title;
  final String? description;
  final String startsAt;
  final String? endsAt;
  final String? location;
  final bool isOnline;
  final String? linkUrl;
  final int? sdg;
  final int? capacity;
  final double fundingGoal;
  final double fundingRaised;
  final String eventType;
  final String? programId;
  final String? sourceUrl;
  final bool activityVerified;
  final double ratingAvg;
  final int ratingCount;
  final int participantsCount;
  final int boothsCount;
  final int attendeesCount;
  final bool attending;
  final String? authorName;
  final Author? author;
  final String? createdAt;
  final String verificationStatus;
  final String? rejectionReason;
  final double creationFeeMrc;
  final String? coverUrl;
  final List<Author> membersPreview;
  Event({
    required this.id,
    required this.title,
    this.description,
    required this.startsAt,
    this.endsAt,
    this.location,
    this.isOnline = false,
    this.linkUrl,
    this.sdg,
    this.capacity,
    this.fundingGoal = 0,
    this.fundingRaised = 0,
    this.eventType = 'EVENT',
    this.programId,
    this.sourceUrl,
    this.activityVerified = false,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.participantsCount = 0,
    this.boothsCount = 0,
    this.attendeesCount = 0,
    this.attending = false,
    this.authorName,
    this.author,
    this.createdAt,
    this.verificationStatus = 'APPROVED',
    this.rejectionReason,
    this.creationFeeMrc = 0,
    this.coverUrl,
    this.membersPreview = const [],
  });
  factory Event.fromJson(Map<String, dynamic> j) => Event(
        id: j['id']?.toString() ?? '',
        title: j['title'] ?? 'Event',
        description: j['description'],
        startsAt: j['starts_at'] ?? j['startsAt'] ?? '',
        endsAt: j['ends_at'] ?? j['endsAt'],
        location: j['location'],
        isOnline: j['is_online'] == true || j['is_online'] == 1,
        linkUrl: j['link_url'],
        sdg: j['sdg'] is num ? (j['sdg'] as num).toInt() : null,
        capacity: j['capacity'] is num ? (j['capacity'] as num).toInt() : null,
        fundingGoal: j['funding_goal'] is num
            ? (j['funding_goal'] as num).toDouble()
            : 0,
        fundingRaised: j['funding_raised'] is num
            ? (j['funding_raised'] as num).toDouble()
            : 0,
        eventType: j['event_type'] ?? 'EVENT',
        programId: j['program_id']?.toString(),
        sourceUrl: j['source_url'],
        activityVerified: j['activity_verified'] == true,
        ratingAvg:
            j['rating_avg'] is num ? (j['rating_avg'] as num).toDouble() : 0,
        ratingCount:
            j['rating_count'] is num ? (j['rating_count'] as num).toInt() : 0,
        participantsCount: j['participants_count'] is num
            ? (j['participants_count'] as num).toInt()
            : 0,
        boothsCount:
            j['booths_count'] is num ? (j['booths_count'] as num).toInt() : 0,
        attendeesCount: j['attendees_count'] is num
            ? (j['attendees_count'] as num).toInt()
            : 0,
        attending: j['attending'] == true,
        authorName: j['author']?['name'],
        author: j['author'] is Map ? Author.fromJson(j['author']) : null,
        createdAt: j['created_at'],
        verificationStatus: j['verification_status'] ?? 'APPROVED',
        rejectionReason: j['rejection_reason'],
        creationFeeMrc: (j['creation_fee_mrc'] is num)
            ? (j['creation_fee_mrc'] as num).toDouble()
            : 0,
        coverUrl: j['cover_url'],
        membersPreview: authorsFromJson(j['members_preview']),
      );
}

class Project {
  final String id;
  final String title;
  final String? description;
  final String category;
  final int? sdg;
  final String? cover;
  final double goal;
  final double raised;
  final int members;
  final String projectType;
  final String? institutionId;
  final String? academicYear;
  final String? studentNames;
  final String? supervisor;
  final String status;
  final String? ownerName;
  final String? programId;
  final bool joined;
  final Author? author;
  final String verificationStatus;
  final String? rejectionReason;
  final double creationFeeMrc;
  final List<Author> membersPreview;
  Project({
    required this.id,
    required this.title,
    this.description,
    this.category = 'Community',
    this.sdg,
    this.cover,
    this.goal = 0,
    this.raised = 0,
    this.members = 0,
    this.projectType = 'COMMUNITY',
    this.institutionId,
    this.academicYear,
    this.studentNames,
    this.supervisor,
    this.status = 'ACTIVE',
    this.ownerName,
    this.programId,
    this.joined = false,
    this.author,
    this.verificationStatus = 'APPROVED',
    this.rejectionReason,
    this.creationFeeMrc = 0,
    this.membersPreview = const [],
  });
  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: j['id']?.toString() ?? '',
        title: j['title'] ?? 'Project',
        description: j['description'],
        category: j['category'] ?? 'Community',
        sdg: j['sdg'] is num ? (j['sdg'] as num).toInt() : null,
        cover: j['cover'],
        goal: (j['goal'] is num) ? (j['goal'] as num).toDouble() : 0,
        raised: (j['raised'] is num) ? (j['raised'] as num).toDouble() : 0,
        members: j['members'] is num ? (j['members'] as num).toInt() : 0,
        projectType: j['project_type'] ?? 'COMMUNITY',
        institutionId: j['institution_id']?.toString(),
        academicYear: j['academic_year'],
        studentNames: j['student_names'],
        supervisor: j['supervisor'],
        status: j['status'] ?? 'ACTIVE',
        ownerName: j['owner_name'],
        programId: j['program_id']?.toString(),
        joined: j['joined'] == true,
        author: j['author'] is Map ? Author.fromJson(j['author']) : null,
        verificationStatus: j['verification_status'] ?? 'APPROVED',
        rejectionReason: j['rejection_reason'],
        creationFeeMrc: (j['creation_fee_mrc'] is num)
            ? (j['creation_fee_mrc'] as num).toDouble()
            : 0,
        membersPreview: authorsFromJson(j['members_preview']),
      );
}

class Submission {
  final String id;
  final String? title;
  final String? claim;
  final double confidence;
  final String? evidenceId;
  final String? status;
  final String? pipelineId;
  final String? createdAt;
  Submission({
    required this.id,
    this.title,
    this.claim,
    this.confidence = 0,
    this.evidenceId,
    this.status,
    this.pipelineId,
    this.createdAt,
  });
  factory Submission.fromJson(Map<String, dynamic> j) => Submission(
        id: j['id']?.toString() ?? '',
        title: j['title'] ?? j['name'],
        claim: j['claim']?.toString(),
        confidence:
            j['confidence'] is num ? (j['confidence'] as num).toDouble() : 0,
        evidenceId: j['evidence_id']?.toString(),
        status: j['status'],
        pipelineId: j['pipeline_id']?.toString() ?? j['pipelineId']?.toString(),
        createdAt: j['created_at'] ?? j['createdAt'],
      );
}

/// Media Personnel professional impact profile (see backend /api/v1/personnel/{id}).
class Personnel {
  final String userId;
  final String name;
  final String email;
  final String role;
  final String roleType;
  final String status;
  final bool emailVerified;
  final String? avatarUrl;
  final String? coverUrl;
  final String? country;
  final String? city;
  final String? website;
  final Map<String, dynamic> socialLinks;
  final String bio;
  final String? joined;
  final String headline;
  final String summary;
  final String mission;
  final String beat;
  final List<dynamic> expertise;
  final List<dynamic> specializations;
  final List<dynamic> skills;
  final List<dynamic> languages;
  final List<dynamic> education;
  final List<dynamic> experience;
  final List<dynamic> certificates;
  final List<dynamic> awards;
  final List<dynamic> publications;
  final List<dynamic> memberships;
  final String employmentStatus;
  final String availability;
  final String verificationLevel;
  final String impactTier;
  final String professionalRank;
  final double impactScore;
  final double trustScore;
  final double verificationConfidence;
  final double communityRating;
  final double currentReach;
  final double lifetimeReach;
  final double averageReach;
  final double audienceGrowth;
  final double averageEngagement;
  final double mediaValue;
  final double contributionScore;
  final double knowledgeScore;
  final double fieldActivityScore;
  final double professionalConsistency;
  final Map<String, dynamic> kpi;
  final int completeness;
  final double pmsScore;
  final String pmsTier;
  final Map<String, dynamic> pms;
  final List<dynamic> badges;
  final List<dynamic> coverageRegions;
  final String visibility;
  final bool isFollowing;

  Personnel({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.roleType,
    required this.status,
    required this.emailVerified,
    this.avatarUrl,
    this.coverUrl,
    this.country,
    this.city,
    this.website,
    this.socialLinks = const {},
    required this.bio,
    this.joined,
    required this.headline,
    required this.summary,
    required this.mission,
    required this.beat,
    required this.expertise,
    required this.specializations,
    required this.skills,
    required this.languages,
    required this.education,
    required this.experience,
    required this.certificates,
    required this.awards,
    required this.publications,
    required this.memberships,
    required this.employmentStatus,
    required this.availability,
    required this.verificationLevel,
    required this.impactTier,
    required this.professionalRank,
    required this.impactScore,
    required this.trustScore,
    required this.verificationConfidence,
    required this.communityRating,
    required this.currentReach,
    required this.lifetimeReach,
    required this.averageReach,
    required this.audienceGrowth,
    required this.averageEngagement,
    required this.mediaValue,
    required this.contributionScore,
    required this.knowledgeScore,
    required this.fieldActivityScore,
    required this.professionalConsistency,
    required this.kpi,
    this.completeness = 0,
    this.pmsScore = 0,
    this.pmsTier = 'BRONZE',
    this.pms = const {},
    this.badges = const [],
    this.coverageRegions = const [],
    this.visibility = 'PUBLIC',
    this.isFollowing = false,
  });

  factory Personnel.fromJson(Map<String, dynamic> j) => Personnel(
        userId: j['user_id'] ?? '',
        name: j['name'] ?? '',
        email: j['email'] ?? '',
        role: j['role'] ?? 'Individual',
        roleType: j['role_type'] ?? 'INDIVIDUAL',
        status: j['status'] ?? 'ACTIVE',
        emailVerified: j['email_verified'] ?? false,
        avatarUrl: j['avatar_url'],
        coverUrl: j['cover_url'],
        country: j['country'],
        city: j['city'],
        website: j['website'],
        socialLinks: j['social_links'] is Map
            ? Map<String, dynamic>.from(j['social_links'] as Map)
            : const {},
        bio: j['bio'] ?? '',
        joined: j['joined'] ?? j['member_since'],
        headline: j['headline'] ?? '',
        summary: j['summary'] ?? '',
        mission: j['mission'] ?? '',
        beat: j['beat'] ?? '',
        expertise: j['expertise'] is List
            ? List<dynamic>.from(j['expertise'])
            : const [],
        specializations: j['specializations'] is List
            ? List<dynamic>.from(j['specializations'])
            : const [],
        skills:
            j['skills'] is List ? List<dynamic>.from(j['skills']) : const [],
        languages: j['languages'] is List
            ? List<dynamic>.from(j['languages'])
            : const [],
        education: j['education'] is List
            ? List<dynamic>.from(j['education'])
            : const [],
        experience: j['experience'] is List
            ? List<dynamic>.from(j['experience'])
            : const [],
        certificates: j['certificates'] is List
            ? List<dynamic>.from(j['certificates'])
            : const [],
        awards:
            j['awards'] is List ? List<dynamic>.from(j['awards']) : const [],
        publications: j['publications'] is List
            ? List<dynamic>.from(j['publications'])
            : const [],
        memberships: j['memberships'] is List
            ? List<dynamic>.from(j['memberships'])
            : const [],
        employmentStatus: j['employment_status'] ?? 'Independent',
        availability: j['availability'] ?? 'Open to opportunities',
        verificationLevel: j['verification_level'] ?? 'VERIFIED',
        impactTier: j['impact_tier'] ?? 'Contributor',
        professionalRank: j['professional_rank'] ?? 'Field Reporter',
        impactScore: (j['impact_score'] is num)
            ? (j['impact_score'] as num).toDouble()
            : 0,
        trustScore: (j['trust_score'] is num)
            ? (j['trust_score'] as num).toDouble()
            : 0,
        verificationConfidence: (j['verification_confidence'] is num)
            ? (j['verification_confidence'] as num).toDouble()
            : 0,
        communityRating: (j['community_rating'] is num)
            ? (j['community_rating'] as num).toDouble()
            : 0,
        currentReach: (j['current_reach'] is num)
            ? (j['current_reach'] as num).toDouble()
            : 0,
        lifetimeReach: (j['lifetime_reach'] is num)
            ? (j['lifetime_reach'] as num).toDouble()
            : 0,
        averageReach: (j['average_reach'] is num)
            ? (j['average_reach'] as num).toDouble()
            : 0,
        audienceGrowth: (j['audience_growth'] is num)
            ? (j['audience_growth'] as num).toDouble()
            : 0,
        averageEngagement: (j['average_engagement'] is num)
            ? (j['average_engagement'] as num).toDouble()
            : 0,
        mediaValue: (j['media_value'] is num)
            ? (j['media_value'] as num).toDouble()
            : 0,
        contributionScore: (j['contribution_score'] is num)
            ? (j['contribution_score'] as num).toDouble()
            : 0,
        knowledgeScore: (j['knowledge_score'] is num)
            ? (j['knowledge_score'] as num).toDouble()
            : 0,
        fieldActivityScore: (j['field_activity_score'] is num)
            ? (j['field_activity_score'] as num).toDouble()
            : 0,
        professionalConsistency: (j['professional_consistency'] is num)
            ? (j['professional_consistency'] as num).toDouble()
            : 0,
        kpi: j['kpi'] is Map
            ? Map<String, dynamic>.from(j['kpi'] as Map)
            : const {},
        completeness:
            j['completeness'] is num ? (j['completeness'] as num).toInt() : 0,
        pmsScore:
            (j['pms_score'] is num) ? (j['pms_score'] as num).toDouble() : 0,
        pmsTier: j['pms_tier'] ?? 'BRONZE',
        pms: j['pms'] is Map
            ? Map<String, dynamic>.from(j['pms'] as Map)
            : const {},
        badges:
            j['badges'] is List ? List<dynamic>.from(j['badges']) : const [],
        coverageRegions: j['coverage_regions'] is List
            ? List<dynamic>.from(j['coverage_regions'])
            : const [],
        visibility: (j['profile_visibility'] ?? 'PUBLIC').toString(),
        isFollowing: j['is_following'] == true,
      );
}

class PersonnelReport {
  final String id;
  final String headline;
  final String text;
  final String category;
  final String? programTag;
  final int sdg;
  final String status;
  final String verificationStatus;
  final String? publishedAt;
  final int reach;
  final int engagement;
  final int evidenceCount;
  final double qualityScore;
  final double impactScore;
  final String? coverImage;
  final int comments;
  final int likes;
  PersonnelReport({
    required this.id,
    required this.headline,
    required this.text,
    required this.category,
    this.programTag,
    required this.sdg,
    required this.status,
    required this.verificationStatus,
    this.publishedAt,
    required this.reach,
    required this.engagement,
    required this.evidenceCount,
    required this.qualityScore,
    required this.impactScore,
    this.coverImage,
    required this.comments,
    required this.likes,
  });
  factory PersonnelReport.fromJson(Map<String, dynamic> j) => PersonnelReport(
        id: j['id'] ?? '',
        headline: j['headline'] ?? '',
        text: j['text'] ?? '',
        category: j['category'] ?? 'story',
        programTag: j['program_tag'],
        sdg: j['sdg'] is num ? (j['sdg'] as num).toInt() : 0,
        status: j['status'] ?? 'PUBLISHED',
        verificationStatus: j['verification_status'] ?? 'REVIEW',
        publishedAt: j['published_at'],
        reach: j['reach'] is num ? (j['reach'] as num).toInt() : 0,
        engagement:
            j['engagement'] is num ? (j['engagement'] as num).toInt() : 0,
        evidenceCount: j['evidence_count'] is num
            ? (j['evidence_count'] as num).toInt()
            : 0,
        qualityScore: (j['quality_score'] is num)
            ? (j['quality_score'] as num).toDouble()
            : 0,
        impactScore: (j['impact_score'] is num)
            ? (j['impact_score'] as num).toDouble()
            : 0,
        coverImage: resolveMediaUrl(j['cover_image']),
        comments: j['comments'] is num ? (j['comments'] as num).toInt() : 0,
        likes: j['likes'] is num ? (j['likes'] as num).toInt() : 0,
      );
}

class AnalyticsPoint {
  final String bucket;
  final double impactScore;
  final double reach;
  final double engagement;
  final int verifiedReports;
  final int evidence;
  final double trustScore;
  final double knowledge;
  final double influence;
  AnalyticsPoint({
    required this.bucket,
    required this.impactScore,
    required this.reach,
    required this.engagement,
    required this.verifiedReports,
    required this.evidence,
    required this.trustScore,
    required this.knowledge,
    required this.influence,
  });
  factory AnalyticsPoint.fromJson(Map<String, dynamic> j) => AnalyticsPoint(
        bucket: j['bucket'] ?? '',
        impactScore: (j['impact_score'] is num)
            ? (j['impact_score'] as num).toDouble()
            : 0,
        reach: (j['reach'] is num) ? (j['reach'] as num).toDouble() : 0,
        engagement:
            (j['engagement'] is num) ? (j['engagement'] as num).toDouble() : 0,
        verifiedReports: j['verified_reports'] is num
            ? (j['verified_reports'] as num).toInt()
            : 0,
        evidence: j['evidence'] is num ? (j['evidence'] as num).toInt() : 0,
        trustScore: (j['trust_score'] is num)
            ? (j['trust_score'] as num).toDouble()
            : 0,
        knowledge:
            (j['knowledge'] is num) ? (j['knowledge'] as num).toDouble() : 0,
        influence:
            (j['influence'] is num) ? (j['influence'] as num).toDouble() : 0,
      );
}
