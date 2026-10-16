import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../shared/widgets/indicators/app_loader.dart';
import '../home/models/home_dashboard_model.dart';
import 'social_api.dart';
import 'social_controller.dart';
import 'widgets/friendship_actions.dart';
import 'widgets/learner_profile_content.dart';
import 'widgets/learner_activity_window.dart';
import 'widgets/social_profile_chrome.dart';

class FriendProfileScreen extends StatefulWidget {
  final String id;
  const FriendProfileScreen({super.key, required this.id});
  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  final api = SocialApi();
  Map<String, dynamic>? person;
  String? error;
  StreamSubscription? events;
  int sequence = 0;

  @override
  void initState() {
    super.initState();
    load();
    events = Get.find<SocialController>().events.stream.listen((event) {
      if (event['event'] == 'INBOX_CHANGED' ||
          event['event'] == 'RECONNECTED') {
        load();
      }
      if (event['event'] == 'PRESENCE' && person != null && mounted) {
        final row = (event['items'] as List)
            .where((r) => r['id'] == widget.id)
            .firstOrNull;
        if (row != null) {
          setState(() => person = {...person!, 'online': row['online']});
        }
      }
    });
  }

  @override
  void dispose() {
    events?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    final request = ++sequence;
    try {
      final p = await api.get('profiles/${widget.id}');
      if (!mounted || request != sequence) return;
      setState(() {
        person = p;
        error = null;
      });
      Get.find<SocialController>().watchFriends(
        p['relation'] == 'FRIEND' ? [widget.id] : [],
      );
    } catch (_) {
      if (mounted && request == sequence) {
        setState(() => error = 'Could not load this profile.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = person;
    final today =
        p?['today'] as String? ??
        DateFormat('yyyy-MM-dd').format(
          DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30)),
        );
    return Scaffold(
      appBar: const SocialPageAppBar(title: 'Learner profile', centered: true),
      body: p == null
          ? Center(
              child: error == null
                  ? const AppLoader()
                  : TextButton(onPressed: load, child: Text('$error Retry')),
            )
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (error != null)
                    TextButton(onPressed: load, child: Text('$error Retry')),
                  LearnerProfileContent(
                    person: p,
                    actions: FriendshipActions(
                      person: p,
                      allowRemove: true,
                      fullWidth: true,
                      onChanged: load,
                    ),
                    activity: LearnerActivityWindow(
                      key: ValueKey('${widget.id}:$today'),
                      id: widget.id,
                      today: today,
                      days: [
                        for (final row in p['activity'])
                          HomeActivityDay.fromJson(
                            Map<String, dynamic>.from(row),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
