import 'package:flutter/material.dart';
import 'package:masaren/l10n.dart';
import 'package:masaren/theme.dart';

/// Small badge that tells the owner an entity is waiting for review or needs
/// changes. Approved entities show nothing.
class EntityStatusChip extends StatelessWidget {
  final String status;
  final String? reason;

  const EntityStatusChip({super.key, required this.status, this.reason});

  @override
  Widget build(BuildContext context) {
    final value = status.toUpperCase();
    if (value == 'APPROVED') return const SizedBox.shrink();
    final rejected = value == 'REJECTED';
    final color = rejected ? AppColors.warm : AppColors.amber;
    final key = rejected ? 'entity.rejected' : 'entity.pending';
    final label = MasarenLocalizations.of(context, key);
    return Tooltip(
      message: reason ?? '',
      child: Container(
        margin: const EdgeInsetsDirectional.only(start: 6),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(rejected ? Icons.error_outline : Icons.hourglass_top,
                size: 11, color: color),
            const SizedBox(width: 3),
            Text(label == key ? (rejected ? 'Needs changes' : 'Pending review') : label,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
