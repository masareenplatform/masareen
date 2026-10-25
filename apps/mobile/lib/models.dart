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
      );

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] ?? '',
        email: j['email'] ?? '',
        fullName: j['full_name'] ?? j['email']?.split('@').first ?? 'User',
        phone: j['phone'],
        role: j['role'] ?? 'INDIVIDUAL',
        pmsScore: (j['pms_score'] is num) ? (j['pms_score'] as num).toDouble() : 0,
        emailVerified: j['email_verified'] ?? false,
        skills: (j['skills'] is List)
            ? List<String>.from(j['skills'].map((s) =>
                s is Map ? (s['skill_name'] ?? s['name'] ?? '') : s.toString()))
            : const [],
        bio: j['profile']?['bio'],
        avatarUrl: j['profile']?['avatar_url'],
        country: j['profile']?['country'],
        city: j['profile']?['city'],
        followersCount: j['profile']?['followers_count'] is num
            ? (j['profile']?['followers_count'] as num).toInt()
            : null,
        coverUrl: j['profile']?['cover_url'],
        isTester: j['is_tester'] ?? false,
      );

  /// Classifies the account into one of the platform's profile archetypes so the
  /// UI can render a tailored profile layout (media / government / sports / org / individual).
  String get roleType {
    final r = role.toUpperCase();
    if (r.contains('MEDIA') || r.contains('PRESS') || r.contains('NEWS')) {
      return 'MEDIA';
    }
    if (r.contains('GOV') || r.contains('GOVERNMENT') || r.contains('MINISTRY')) {
      return 'GOVERNMENT';
    }
    if (r.contains('SPORT') || r.contains('CLUB') || r.contains('ATHLETE')) {
      return 'SPORTS';
    }
    if (r.contains('ORG') || r.contains('NGO') || r.contains('COMPANY') ||
        r.contains('INSTITUTION')) {
      return 'ORGANIZATION';
    }
    return 'INDIVIDUAL';
  }
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
  final int likes;
  final int comments;
  final int shares;
  final bool likedByMe;
  final List<Comment> commentList;
  final String? createdAt;
  final double? confidenceScore;
  final String? confidenceLabel;
  final Map<String, dynamic>? confidenceFactors;
  final double? rankingScore;
  final String? rankingReason;

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
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.likedByMe = false,
    this.commentList = const [],
    this.createdAt,
    this.confidenceScore,
    this.confidenceLabel,
    this.confidenceFactors,
    this.rankingScore,
    this.rankingReason,
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
        contentUrl: j['content_url'] ?? j['url'],
        likes: j['likes'] is num ? (j['likes'] as num).toInt() : 0,
        comments: (j['comments'] is List)
            ? (j['comments'] as List).length
            : (j['comments'] is num ? (j['comments'] as num).toInt() : 0),
        shares: j['shares'] is num ? (j['shares'] as num).toInt() : 0,
        likedByMe: j['likedByMe'] ?? false,
        commentList: (j['comments'] is List)
            ? (j['comments'] as List)
                .map((c) => Comment.fromJson(c as Map<String, dynamic>))
                .toList()
            : const [],
        createdAt: j['createdAt'] ?? j['created_at'],
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
      );

  Post copyWith({
    int? likes,
    bool? likedByMe,
    int? comments,
    List<Comment>? commentList,
    int? shares,
    double? confidenceScore,
    String? confidenceLabel,
    Map<String, dynamic>? confidenceFactors,
    double? rankingScore,
    String? rankingReason,
    double? impactValue,
    String? impactLabel,
  }) =>
      Post(
        id: id,
        author: author,
        text: text,
        kind: kind,
        programTag: programTag,
        sdg: sdg,
        impactValue: impactValue ?? this.impactValue,
        impactLabel: impactLabel ?? this.impactLabel,
        type: type,
        contentUrl: contentUrl,
        likes: likes ?? this.likes,
        comments: comments ?? this.comments,
        shares: shares ?? this.shares,
        likedByMe: likedByMe ?? this.likedByMe,
        commentList: commentList ?? this.commentList,
        createdAt: createdAt,
        confidenceScore: confidenceScore ?? this.confidenceScore,
        confidenceLabel: confidenceLabel ?? this.confidenceLabel,
        confidenceFactors: confidenceFactors ?? this.confidenceFactors,
        rankingScore: rankingScore ?? this.rankingScore,
        rankingReason: rankingReason ?? this.rankingReason,
      );
}

class Author {
  final String id;
  final String name;
  final String? handle;
  final bool verified;
  final String? role;
  Author({required this.id, required this.name, this.handle, this.verified = false, this.role});
  factory Author.fromJson(Map<String, dynamic> j) => Author(
        id: j['id'] ?? '',
        name: j['name'] ?? 'Unknown',
        handle: j['handle'],
        verified: j['verified'] ?? false,
        role: j['role'],
      );
}

class Comment {
  final String? id;
  final String text;
  final String? authorId;
  final String? authorName;
  final String? authorHandle;
  final String? createdAt;
  Comment({
    this.id,
    required this.text,
    this.authorId,
    this.authorName,
    this.authorHandle,
    this.createdAt,
  });
  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: j['id']?.toString(),
        text: j['text'] ?? '',
        authorId: j['author_id']?.toString() ?? j['userId']?.toString(),
        authorName: j['author_name'] ?? j['authorName'] ?? 'User',
        authorHandle: j['author_handle'],
        createdAt: j['created_at'] ?? j['createdAt'],
      );
}

class Wallet {
  final String ownerId;
  final double balance;
  final String currency;
  Wallet({
    required this.ownerId,
    required this.balance,
    this.currency = 'MRC',
  });
  factory Wallet.fromJson(Map<String, dynamic> j) => Wallet(
        ownerId: j['owner_id']?.toString() ?? '',
        balance: (j['balance'] is num) ? (j['balance'] as num).toDouble() : 0,
        currency: j['currency']?.toString() ?? 'MRC',
      );
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
  final String title;
  final String? body;
  final String? mediaUrl;
  final String? ctaUrl;
  Creative({
    this.id,
    required this.title,
    this.body,
    this.mediaUrl,
    this.ctaUrl,
  });
  factory Creative.fromJson(Map<String, dynamic> j) => Creative(
        id: j['id']?.toString(),
        title: j['title'] ?? '',
        body: j['body'] ?? j['text'],
        mediaUrl: j['media_url'] ?? j['mediaUrl'],
        ctaUrl: j['cta_url'] ?? j['ctaUrl'],
      );
}

class Campaign {
  final String id;
  final String name;
  final String status;
  final double budget;
  final String currency;
  final List<Creative> creatives;
  final Map<String, dynamic>? stats;
  Campaign({
    required this.id,
    required this.name,
    required this.status,
    required this.budget,
    this.currency = 'MRC',
    this.creatives = const [],
    this.stats,
  });
  factory Campaign.fromJson(Map<String, dynamic> j) => Campaign(
        id: j['id']?.toString() ?? '',
        name: j['name'] ?? 'Campaign',
        status: j['status']?.toString() ?? 'DRAFT',
        budget: (j['budget_coins'] is num)
            ? (j['budget_coins'] as num).toDouble()
            : ((j['budget'] is num) ? (j['budget'] as num).toDouble() : 0),
        currency: j['currency']?.toString() ?? 'MRC',
        creatives: (j['creatives'] is List)
            ? (j['creatives'] as List)
                .map((c) => Creative.fromJson(c as Map<String, dynamic>))
                .toList()
            : const [],
        stats: j['stats'] is Map ? j['stats'] as Map<String, dynamic> : null,
      );
  Campaign copyWith({String? status, List<Creative>? creatives}) => Campaign(
        id: id,
        name: name,
        status: status ?? this.status,
        budget: budget,
        currency: currency,
        creatives: creatives ?? this.creatives,
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
    this.applicationsCount = 0,
    this.applied = false,
  });

  factory Opportunity.fromJson(Map<String, dynamic> j) => Opportunity(
        id: j['id']?.toString() ?? '',
        title: j['title'] ?? 'Opportunity',
        description: j['description'],
        skills: (j['skills'] is List) ? List<dynamic>.from(j['skills']) : const [],
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
  final int projectsCount;
  final int tasksCount;
  final bool enrolledByMe;

  Program({
    required this.id,
    required this.title,
    this.description,
    this.status,
    this.sdg,
    this.members,
    this.category,
    this.organization,
    this.budget = 0,
    this.projectsCount = 0,
    this.tasksCount = 0,
    this.enrolledByMe = false,
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
        projectsCount:
            j['projects_count'] is num ? (j['projects_count'] as num).toInt() : 0,
        tasksCount: j['tasks_count'] is num ? (j['tasks_count'] as num).toInt() : 0,
        enrolledByMe: j['enrolled_by_me'] == true,
      );
}

class AppNotification {
  final String id;
  final String? type;
  final String title;
  final String? body;
  final bool read;
  final String? createdAt;
  AppNotification({
    required this.id,
    this.type,
    required this.title,
    this.body,
    this.read = false,
    this.createdAt,
  });
  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id']?.toString() ?? '',
        type: j['type'],
        title: j['title'] ?? j['data']?['title'] ?? 'Notification',
        body: j['body'] ?? j['data']?['body'],
        read: j['read'] ?? j['is_read'] ?? false,
        createdAt: j['created_at'] ?? j['createdAt'],
      );
}

class Course {
  final String id;
  final String title;
  final String? description;
  final String? provider;
  final String level;
  final int? sdg;
  final int lessons;
  final int durationMin;
  final String? thumbnail;
  final String status;
  final int enrolledCount;
  final bool enrolledByMe;
  Course({
    required this.id,
    required this.title,
    this.description,
    this.provider,
    this.level = 'Beginner',
    this.sdg,
    this.lessons = 0,
    this.durationMin = 0,
    this.thumbnail,
    this.status = 'PUBLISHED',
    this.enrolledCount = 0,
    this.enrolledByMe = false,
  });
  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: j['id'] ?? '',
        title: j['title'] ?? 'Course',
        description: j['description'],
        provider: j['provider'],
        level: j['level'] ?? 'Beginner',
        sdg: j['sdg'] is num ? (j['sdg'] as num).toInt() : null,
        lessons: j['lessons'] is num ? (j['lessons'] as num).toInt() : 0,
        durationMin:
            j['duration_min'] is num ? (j['duration_min'] as num).toInt() : 0,
        thumbnail: j['thumbnail'],
        status: j['status'] ?? 'PUBLISHED',
        enrolledCount: j['enrolled_count'] is num ? (j['enrolled_count'] as num).toInt() : 0,
        enrolledByMe: j['enrolled_by_me'] == true,
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
  final int attendeesCount;
  final bool attending;
  final String? authorName;
  final String? createdAt;
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
    this.attendeesCount = 0,
    this.attending = false,
    this.authorName,
    this.createdAt,
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
        attendeesCount: j['attendees_count'] is num ? (j['attendees_count'] as num).toInt() : 0,
        attending: j['attending'] == true,
        authorName: j['author']?['name'],
        createdAt: j['created_at'],
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
  final String status;
  final String? ownerName;
  final String? programId;
  final bool joined;
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
    this.status = 'ACTIVE',
    this.ownerName,
    this.programId,
    this.joined = false,
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
        status: j['status'] ?? 'ACTIVE',
        ownerName: j['owner_name'],
        programId: j['program_id']?.toString(),
        joined: j['joined'] == true,
      );
}

class Submission {
  final String id;
  final String? title;
  final String? status;
  final String? pipelineId;
  final String? createdAt;
  Submission({
    required this.id,
    this.title,
    this.status,
    this.pipelineId,
    this.createdAt,
  });
  factory Submission.fromJson(Map<String, dynamic> j) => Submission(
        id: j['id']?.toString() ?? '',
        title: j['title'] ?? j['name'],
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
        expertise: j['expertise'] is List ? List<dynamic>.from(j['expertise']) : const [],
        specializations:
            j['specializations'] is List ? List<dynamic>.from(j['specializations']) : const [],
        skills: j['skills'] is List ? List<dynamic>.from(j['skills']) : const [],
        languages: j['languages'] is List ? List<dynamic>.from(j['languages']) : const [],
        education: j['education'] is List ? List<dynamic>.from(j['education']) : const [],
        experience: j['experience'] is List ? List<dynamic>.from(j['experience']) : const [],
        certificates:
            j['certificates'] is List ? List<dynamic>.from(j['certificates']) : const [],
        awards: j['awards'] is List ? List<dynamic>.from(j['awards']) : const [],
        publications:
            j['publications'] is List ? List<dynamic>.from(j['publications']) : const [],
        memberships:
            j['memberships'] is List ? List<dynamic>.from(j['memberships']) : const [],
        employmentStatus: j['employment_status'] ?? 'Independent',
        availability: j['availability'] ?? 'Open to opportunities',
        verificationLevel: j['verification_level'] ?? 'VERIFIED',
        impactTier: j['impact_tier'] ?? 'Contributor',
        professionalRank: j['professional_rank'] ?? 'Field Reporter',
        impactScore: (j['impact_score'] is num) ? (j['impact_score'] as num).toDouble() : 0,
        trustScore: (j['trust_score'] is num) ? (j['trust_score'] as num).toDouble() : 0,
        verificationConfidence: (j['verification_confidence'] is num)
            ? (j['verification_confidence'] as num).toDouble()
            : 0,
        communityRating: (j['community_rating'] is num)
            ? (j['community_rating'] as num).toDouble()
            : 0,
        currentReach: (j['current_reach'] is num) ? (j['current_reach'] as num).toDouble() : 0,
        lifetimeReach:
            (j['lifetime_reach'] is num) ? (j['lifetime_reach'] as num).toDouble() : 0,
        averageReach: (j['average_reach'] is num) ? (j['average_reach'] as num).toDouble() : 0,
        audienceGrowth:
            (j['audience_growth'] is num) ? (j['audience_growth'] as num).toDouble() : 0,
        averageEngagement: (j['average_engagement'] is num)
            ? (j['average_engagement'] as num).toDouble()
            : 0,
        mediaValue: (j['media_value'] is num) ? (j['media_value'] as num).toDouble() : 0,
        contributionScore: (j['contribution_score'] is num)
            ? (j['contribution_score'] as num).toDouble()
            : 0,
        knowledgeScore:
            (j['knowledge_score'] is num) ? (j['knowledge_score'] as num).toDouble() : 0,
        fieldActivityScore: (j['field_activity_score'] is num)
            ? (j['field_activity_score'] as num).toDouble()
            : 0,
        professionalConsistency: (j['professional_consistency'] is num)
            ? (j['professional_consistency'] as num).toDouble()
            : 0,
        kpi: j['kpi'] is Map ? Map<String, dynamic>.from(j['kpi'] as Map) : const {},
        completeness: j['completeness'] is num ? (j['completeness'] as num).toInt() : 0,
        pmsScore: (j['pms_score'] is num) ? (j['pms_score'] as num).toDouble() : 0,
        pmsTier: j['pms_tier'] ?? 'BRONZE',
        pms: j['pms'] is Map ? Map<String, dynamic>.from(j['pms'] as Map) : const {},
        badges: j['badges'] is List ? List<dynamic>.from(j['badges']) : const [],
        coverageRegions: j['coverage_regions'] is List
            ? List<dynamic>.from(j['coverage_regions'])
            : const [],
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
        engagement: j['engagement'] is num ? (j['engagement'] as num).toInt() : 0,
        evidenceCount: j['evidence_count'] is num ? (j['evidence_count'] as num).toInt() : 0,
        qualityScore: (j['quality_score'] is num) ? (j['quality_score'] as num).toDouble() : 0,
        impactScore: (j['impact_score'] is num) ? (j['impact_score'] as num).toDouble() : 0,
        coverImage: j['cover_image'],
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
        impactScore: (j['impact_score'] is num) ? (j['impact_score'] as num).toDouble() : 0,
        reach: (j['reach'] is num) ? (j['reach'] as num).toDouble() : 0,
        engagement: (j['engagement'] is num) ? (j['engagement'] as num).toDouble() : 0,
        verifiedReports:
            j['verified_reports'] is num ? (j['verified_reports'] as num).toInt() : 0,
        evidence: j['evidence'] is num ? (j['evidence'] as num).toInt() : 0,
        trustScore: (j['trust_score'] is num) ? (j['trust_score'] as num).toDouble() : 0,
        knowledge: (j['knowledge'] is num) ? (j['knowledge'] as num).toDouble() : 0,
        influence: (j['influence'] is num) ? (j['influence'] as num).toDouble() : 0,
      );
}
