import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/admin_announcements_screen.dart';
import 'package:masaren/screens/admin_entity_review_screen.dart';
import 'package:masaren/screens/admin_feedback_screen.dart';
import 'package:masaren/screens/admin_insights_screen.dart';
import 'package:masaren/screens/admin_operations_screen.dart';
import 'package:masaren/screens/admin_screen.dart';
import 'package:masaren/screens/booth_screen.dart';
import 'package:masaren/screens/event_hub_screen.dart';
import 'package:masaren/screens/messages_screen.dart';
import 'package:masaren/screens/notifications_screen.dart';
import 'package:masaren/screens/opportunities_screen.dart';
import 'package:masaren/screens/post_detail_screen.dart';
import 'package:masaren/screens/profile_view_screen.dart';
import 'package:masaren/shell/shell_navigation.dart';

/// Single place that understands notification and deep-link payloads, so a
/// tap always lands on the screen where the action happened.
class AppLinkRouter {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Future<void> _push(Widget screen) async {
    final push = shellPush;
    if (push != null) {
      await push(screen);
      return;
    }
    final navigator = navigatorKey.currentState;
    navigator?.push(MaterialPageRoute(builder: (_) => screen));
  }

  static Future<void> handle(String? payload) async {
    if (payload == null || payload.isEmpty) return;
    if (payload.startsWith('conversation:')) {
      try {
        final id = payload.substring('conversation:'.length);
        final results = await Future.wait([AuthApi.me(), AuthApi.conversation(id)]);
        final me = results[0] as User;
        final thread = results[1] as ChatThread;
        await _push(ChatScreen(conversation: thread.conversation, user: me));
      } catch (_) {}
      return;
    }
    if (payload.startsWith('post:')) {
      try {
        final id = payload.substring('post:'.length);
        final results = await Future.wait([AuthApi.me(), AuthApi.postById(id)]);
        final me = results[0] as User;
        final post = results[1] as Post;
        await _push(PostDetailScreen(
            post: post, currentUser: me, onChanged: (_) {}));
      } catch (_) {}
      return;
    }
    if (payload.startsWith('user:')) {
      try {
        final id = payload.substring('user:'.length);
        final me = await AuthApi.me();
        await _push(ProfileViewScreen(userId: id, currentUser: me));
      } catch (_) {}
      return;
    }
    if (payload.startsWith('event:')) {
      try {
        final id = payload.substring('event:'.length);
        final me = await AuthApi.me();
        await _push(EventHubScreen(eventId: id, user: me));
      } catch (_) {}
      return;
    }
    if (payload.startsWith('booth:')) {
      try {
        final id = payload.substring('booth:'.length);
        final me = await AuthApi.me();
        await _push(BoothScreen(boothId: id, user: me));
      } catch (_) {}
      return;
    }
    if (payload.startsWith('admin:')) {
      await _handleAdmin(payload.substring('admin:'.length));
      return;
    }
    if (payload == 'messages') {
      try {
        final me = await AuthApi.me();
        await _push(MessagesScreen(user: me));
      } catch (_) {}
      return;
    }
    if (payload == 'opportunities') {
      try {
        final me = await AuthApi.me();
        await _push(OpportunitiesScreen(user: me));
      } catch (_) {}
      return;
    }
    final userId = api.userId;
    if (userId != null && userId.isNotEmpty) {
      await _push(NotificationsScreen(userId: userId));
    }
  }

  static Future<void> _handleAdmin(String tool) async {
    try {
      final me = await AuthApi.me();
      switch (tool) {
        case 'feedback':
          await _push(AdminFeedbackScreen(user: me));
          break;
        case 'announcements':
          await _push(AdminAnnouncementsScreen(user: me));
          break;
        case 'entities':
          await _push(AdminEntityReviewScreen(user: me));
          break;
        case 'inbox':
          await _push(NotificationsScreen(userId: me.id));
          break;
        case 'moderation':
          await _push(
              AdminOperationsScreen(user: me, initialTab: 0));
          break;
        case 'ai':
          await _push(
              AdminOperationsScreen(user: me, initialTab: 1));
          break;
        case 'behavior':
          await _push(
              AdminOperationsScreen(user: me, initialTab: 2));
          break;
        case 'live':
          await _push(
              AdminOperationsScreen(user: me, initialTab: 3));
          break;
        case 'payments':
          await _push(AdminScreen(user: me, initialTab: 6));
          break;
        case 'inquiries':
          await _push(AdminScreen(user: me, initialTab: 3));
          break;
        case 'transactions':
          await _push(AdminInsightsScreen(user: me, initialTab: 2));
          break;
        case 'leaderboards':
          await _push(AdminInsightsScreen(user: me, initialTab: 3));
          break;
        case 'reports':
          await _push(AdminInsightsScreen(user: me));
          break;
        default:
          await _push(AdminScreen(user: me));
      }
    } catch (_) {}
  }
}
