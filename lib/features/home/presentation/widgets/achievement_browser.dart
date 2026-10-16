import 'package:aptiqu/shared/widgets/indicators/app_loader.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/aptiqu_colors.dart';
import '../../models/home_dashboard_model.dart';

/// Paginated, server-authored catalog. No achievement definitions live here.
class AchievementBrowser extends StatefulWidget {
  final Future<Map<String, dynamic>> Function(int page) fetchPage;
  final Widget Function(HomeBadge) badgeBuilder;
  const AchievementBrowser({
    super.key,
    required this.fetchPage,
    required this.badgeBuilder,
  });
  @override
  State<AchievementBrowser> createState() => _AchievementBrowserState();
}

class _AchievementBrowserState extends State<AchievementBrowser> {
  List<HomeBadge> items = [];
  int page = 0;
  bool hasMore = false;
  bool loading = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool refresh = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final next = refresh ? 1 : page + 1;
      final result = await widget.fetchPage(next);
      if (!mounted) return;
      setState(() {
        final batch = [
          for (final json in result['items'])
            HomeBadge.fromJson(Map<String, dynamic>.from(json)),
        ];
        final latest = <String, HomeBadge>{};
        final unkeyed = <HomeBadge>[];
        for (final item in (refresh ? batch : [...items, ...batch])) {
          if (item.id.isEmpty) {
            unkeyed.add(item);
          } else {
            latest[item.id] = item;
          }
        }
        items = [...latest.values, ...unkeyed];
        page = next;
        hasMore = result['hasMore'] == true;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not load achievements. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: [
        ListTile(
          title: const Text('Achievements'),
          trailing: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => load(refresh: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                for (final item in items) ...[
                  widget.badgeBuilder(item),
                  const SizedBox(height: 12),
                ],
                if (!loading && error == null && items.isEmpty)
                  const Text('No achievements are available yet.'),
                if (error != null) ...[
                  Text(
                    error!,
                    style: const TextStyle(color: AptiquColors.error),
                  ),
                  TextButton(onPressed: load, child: const Text('Retry')),
                ],
                if (loading) const Center(child: AppLoader()),
                if (!loading && error == null && hasMore)
                  TextButton(onPressed: load, child: const Text('Load more')),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
