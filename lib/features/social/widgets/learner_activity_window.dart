import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/indicators/app_loader.dart';
import '../../home/models/home_dashboard_model.dart';
import '../../home/presentation/widgets/home_dashboard_view.dart';
import '../social_api.dart';

/// Uses Home's month window and caches only the months the learner visits.
class LearnerActivityWindow extends StatefulWidget {
  final String id, today;
  final List<HomeActivityDay> days;
  const LearnerActivityWindow({
    super.key,
    required this.id,
    required this.today,
    required this.days,
  });
  @override
  State<LearnerActivityWindow> createState() => _LearnerActivityWindowState();
}

class _LearnerActivityWindowState extends State<LearnerActivityWindow> {
  final months = <String, Future<List<HomeActivityDay>>>{};

  Future<List<HomeActivityDay>> load(String month) async {
    final data = await SocialApi().get('profiles/${widget.id}/activity', {
      'month': month,
    });
    return [
      for (final row in data['activity'])
        HomeActivityDay.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  @override
  Widget build(BuildContext context) => YearActivityCalendar(
    days: widget.days,
    today: widget.today,
    monthBuilder: (context, month, fallback) {
      final key = DateFormat(
        'yyyy-MM',
      ).format(DateTime(DateTime.parse(widget.today).year, month));
      if (key == widget.today.substring(0, 7)) {
        return ActivityCalendar(days: fallback, today: widget.today);
      }
      return FutureBuilder<List<HomeActivityDay>>(
        future: months.putIfAbsent(key, () => load(key)),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: TextButton.icon(
                onPressed: () => setState(() => months.remove(key)),
                icon: const Icon(Icons.refresh),
                label: const Text('Could not load this month. Retry'),
              ),
            );
          }
          if (!snapshot.hasData) return const Center(child: AppLoader());
          return ActivityCalendar(days: snapshot.data!, today: widget.today);
        },
      );
    },
  );
}
