import 'package:flutter/material.dart';
import 'package:masaren/api_client.dart';
import 'package:masaren/models.dart';
import 'package:masaren/screens/government_profile_screen.dart';
import 'package:masaren/screens/institution_profile_screen.dart';
import 'package:masaren/screens/news_media_profile_screen.dart';
import 'package:masaren/screens/organization_profile_screen.dart';
import 'package:masaren/screens/personnel_profile_screen.dart';
import 'package:masaren/screens/player_showcase_screen.dart';
import 'package:masaren/screens/profile_screen.dart';
import 'package:masaren/screens/profile_view_screen.dart';
import 'package:masaren/screens/sports_profile_screen.dart';

Future<void> openUserProfile(
  BuildContext context, {
  required String userId,
  required User currentUser,
  String? role,
  String? name,
}) async {
  if (userId.isEmpty) return;

  var resolvedRole = (role ?? '').toUpperCase();
  if (resolvedRole.isEmpty) {
    try {
      final user = await AuthApi.getUser(userId);
      resolvedRole = user.role.toUpperCase();
    } catch (_) {
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              ProfileViewScreen(userId: userId, currentUser: currentUser)));
      return;
    }
  }
  if (!context.mounted) return;

  if (userId == 'platform' || resolvedRole.contains('PLATFORM')) {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            const InstitutionProfileScreen(institutionId: 'platform')));
    return;
  }
  if (userId == currentUser.id) {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProfileScreen(
            user: currentUser, onLogout: () {}, onToggleTheme: null)));
    return;
  }
  if (resolvedRole.contains('MEDIA') ||
      resolvedRole.contains('PRESS') ||
      resolvedRole.contains('NEWS')) {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            NewsMediaProfileScreen(userId: userId, currentUser: currentUser)));
  } else if (resolvedRole.contains('SPORT') ||
      resolvedRole.contains('CLUB') ||
      resolvedRole.contains('FEDERATION')) {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            SportsProfileScreen(orgId: userId, currentUser: currentUser)));
  } else if (resolvedRole.contains('GOV')) {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            GovernmentProfileScreen(orgId: userId, currentUser: currentUser)));
  } else if (resolvedRole.contains('ATHLETE')) {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            PlayerShowcaseScreen(playerId: userId, currentUser: currentUser)));
  } else if (resolvedRole.contains('NGO') ||
      resolvedRole.contains('ORGANIZATION') ||
      resolvedRole.contains('COMPANY') ||
      resolvedRole.contains('CORPORATE') ||
      resolvedRole.contains('INSTITUTION')) {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OrganizationProfileScreen(
            orgId: userId, currentUser: currentUser)));
  } else {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            PersonnelProfileScreen(userId: userId, currentUser: currentUser)));
  }
}

Future<void> openEntityAuthor(
  BuildContext context, {
  required Author? author,
  required User currentUser,
}) {
  if (author == null || author.id.isEmpty) return Future.value();
  return openUserProfile(context,
      userId: author.id,
      currentUser: currentUser,
      role: author.role,
      name: author.name);
}
