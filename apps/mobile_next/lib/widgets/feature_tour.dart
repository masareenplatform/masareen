import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TourStep {
  final IconData icon;
  final String title;
  final String body;
  const TourStep({required this.icon, required this.title, required this.body});
}

Future<void> showFeatureTourIfNeeded(
  BuildContext context,
  String key, {
  required String title,
  required String subtitle,
  required List<TourStep> steps,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('next_tour_$key') == true) return;
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TourSheet(
        title: title,
        subtitle: subtitle,
        steps: steps,
        onDone: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('next_tour_$key', true);
        },
      ),
    );
  } catch (_) {}
}

class _TourSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<TourStep> steps;
  final Future<void> Function() onDone;
  const _TourSheet({
    required this.title,
    required this.subtitle,
    required this.steps,
    required this.onDone,
  });

  @override
  State<_TourSheet> createState() => _TourSheetState();
}

class _TourSheetState extends State<_TourSheet> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == widget.steps.length - 1) {
      Navigator.pop(context);
      widget.onDone();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.secondary.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      'QUICK TOUR',
                      style: TextStyle(
                        color: cs.secondary,
                        fontSize: 9,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onDone();
                    },
                    child: const Text('Skip'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 250,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: widget.steps.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) {
                    final step = widget.steps[i];
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Column(
                        key: ValueKey(i),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.primary.withValues(alpha: .12),
                              border: Border.all(
                                color: cs.primary.withValues(alpha: .35),
                              ),
                            ),
                            child: Icon(step.icon, color: cs.primary, size: 38),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            step.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            step.body,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < widget.steps.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsetsDirectional.only(end: 6),
                      width: i == _index ? 22 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _index ? cs.primary : cs.outlineVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    '${_index + 1} / ${widget.steps.length}',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _next,
                    icon: Icon(
                      _index == widget.steps.length - 1
                          ? Icons.check
                          : Icons.arrow_forward,
                    ),
                    label: Text(
                      _index == widget.steps.length - 1 ? 'Start' : 'Next',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
