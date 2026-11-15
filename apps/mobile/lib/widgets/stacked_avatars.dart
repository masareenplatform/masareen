import 'package:flutter/material.dart';
import 'package:masaren/models.dart';
import 'package:masaren/widgets.dart';

/// Overlapping member avatars used on entities, so a course/event/program
/// immediately shows who else is participating.
class StackedAvatars extends StatelessWidget {
  final List<Author> people;
  final int total;
  final double size;
  final int max;

  const StackedAvatars({
    super.key,
    required this.people,
    this.total = 0,
    this.size = 24,
    this.max = 4,
  });

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty && total <= 0) return const SizedBox.shrink();
    final shown = people.take(max).toList();
    final extra = total > shown.length ? total - shown.length : 0;
    final step = size * 0.68;
    final width = shown.isEmpty
        ? size
        : step * (shown.length - 1) + size + (extra > 0 ? step : 0);
    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < shown.length; i++)
            PositionedDirectional(
              start: i * step,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Theme.of(context).colorScheme.surface, width: 1.6),
                ),
                child: AppAvatar(
                  name: shown[i].name,
                  url: shown[i].avatarUrl,
                  size: size - 3,
                ),
              ),
            ),
          if (extra > 0)
            PositionedDirectional(
              start: shown.length * step,
              child: Container(
                width: size - 3,
                height: size - 3,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Theme.of(context).colorScheme.surface, width: 1.6),
                ),
                child: Text('+$extra',
                    style: TextStyle(
                        fontSize: size * 0.32,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onPrimaryContainer)),
              ),
            ),
        ],
      ),
    );
  }
}
