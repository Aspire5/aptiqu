import '../../../shared/widgets/layout/text_fit.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/appearance_theme.dart';
import '../../../core/theme/aptiqu_tokens.dart';
import '../../../shared/widgets/feedback/app_state_view.dart';
import '../../../shared/widgets/questions/question_presentation.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../social/widgets/social_widgets.dart';
import 'ranked_models.dart';
import 'ranked_repository.dart';
import 'ranked_widgets.dart';

class RankedBrowserScreen extends StatefulWidget {
  final bool seasons;
  final String? initialSeason;
  final RankedRepository? repository;
  const RankedBrowserScreen({
    super.key,
    this.seasons = false,
    this.initialSeason,
    this.repository,
  });
  @override
  State<RankedBrowserScreen> createState() => _RankedBrowserScreenState();
}

class _RankedBrowserScreenState extends State<RankedBrowserScreen> {
  late final RankedRepository _repo = widget.repository ?? RankedRepository();
  late final String? _owner = _repo.owner;
  Worker? _accountWorker;
  final _entries = <RankedEntry>[];
  final _seasons = <Map<String, dynamic>>[];
  final _months = <String>{};
  String? _season, _cursor, _before, _error, _asOf;
  String _pagination = '';
  RankedSummary? _own;
  RankedSeason? _context;
  bool _loading = true, _failedMore = false;
  int _generation = 0;
  bool _valid(int g) => mounted && _repo.owner == _owner && g == _generation;
  @override
  void initState() {
    super.initState();
    _season = widget.initialSeason;
    if (Get.isRegistered<AuthController>()) {
      _accountWorker = ever(Get.find<AuthController>().currentUser, (_) {
        if (!mounted || _repo.owner == _owner) return;
        ++_generation;
        setState(() {
          _entries.clear();
          _seasons.clear();
          _own = null;
          _context = null;
          _months.clear();
          _loading = false;
          _error = 'Sign in again to view Ranked.';
        });
      });
    }
    _load(reset: true);
  }

  Future<RankedSummary?> _loadOwn() async {
    try {
      return await _repo.me(seasonId: _season);
    } catch (_) {
      return null;
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_repo.owner != _owner || (!reset && _loading)) return;
    final g = ++_generation;
    setState(() {
      _loading = true;
      _failedMore = !reset;
      _error = null;
      if (reset) {
        _cursor = null;
        _before = null;
      }
    });
    try {
      final ownFuture = reset && !widget.seasons
          ? _loadOwn()
          : Future.value(_own);
      final data = widget.seasons
          ? await _repo.seasons(before: reset ? null : _before)
          : await _repo.board(
              seasonId: _season,
              cursor: reset ? null : _cursor,
            );
      final own = await ownFuture;
      if (!_valid(g)) return;
      if (widget.seasons) {
        final values = (data['entries'] as List).map(rankedMap).toList();
        final current = RankedSeason.fromJson(rankedMap(data['currentSeason']));
        setState(() {
          if (reset) _seasons.clear();
          final ids = _seasons.map((v) => rankedMap(v['season'])['id']).toSet();
          _seasons.addAll(
            values.where((v) => ids.add(rankedMap(v['season'])['id'])),
          );
          _context = current;
          _before = data['nextBefore'] as String?;
        });
      } else {
        final rows = (data['entries'] as List)
            .map((e) => RankedEntry.fromJson(rankedMap(e)))
            .toList();
        final season = RankedSeason.fromJson(rankedMap(data['season']));
        setState(() {
          if (reset) _entries.clear();
          final ids = _entries.map((e) => e.userId).toSet();
          _entries.addAll(rows.where((e) => ids.add(e.userId)));
          _own = own;
          _context = season;
          _cursor = data['nextCursor'] as String?;
          _asOf = data['asOf'] as String?;
          _pagination = data['pagination'] as String? ?? '';
          _months.add(season.id);
          if (own != null) _months.add(own.currentSeasonId);
        });
        if (reset) {
          try {
            final history = await _repo.seasons();
            if (_valid(g)) {
              setState(() {
                _months.add(
                  rankedMap(history['currentSeason'])['id'] as String,
                );
                _months.addAll(
                  (history['entries'] as List).map(
                    (e) => rankedMap(rankedMap(e)['season'])['id'] as String,
                  ),
                );
              });
            }
          } catch (_) {
            /* Viewing this board does not depend on history. */
          }
        }
      }
    } catch (e) {
      if (!_valid(g)) return;
      setState(() {
        if (e is RankedFailure && e.code == 'CURSOR_RESET') {
          _entries.clear();
          _cursor = null;
          _failedMore = false;
          _error =
              'Leaderboard changed or page expired. Refresh to start again.';
        } else {
          _error = e is RankedFailure && e.retryAfter != null
              ? 'Please wait ${e.retryAfter} seconds before retrying.'
              : e is RankedFailure && e.code == 'RANKED_DISABLED'
              ? 'Leagues are not available yet.'
              : e is RankedFailure && e.code == 'RATE_LIMITED'
              ? 'Too many requests. Wait a moment, then retry.'
              : 'Could not load Ranked. Please retry.';
        }
      });
    } finally {
      if (_valid(g)) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    ++_generation;
    _accountWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppearanceTheme(
    builder: (context) => Scaffold(
      appBar: AppBar(
        title: Text(widget.seasons ? 'Season history' : 'Leaderboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh Ranked',
            onPressed: _loading ? null : () => _load(reset: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _load(reset: true),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.seasons
                      ? _seasons.length + 2
                      : _entries.length + 2,
                  itemBuilder: (context, index) {
                    if (index == 0) return _header(context);
                    final length = widget.seasons
                        ? _seasons.length
                        : _entries.length;
                    if (index == length + 1) return _footer(context, length);
                    return widget.seasons
                        ? _seasonRow(context, _seasons[index - 1])
                        : _entryRow(context, _entries[index - 1]);
                  },
                ),
              ),
            ),
            if (!widget.seasons)
              Material(
                color: context.colors.surfaceContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _own == null
                      ? Text(
                          'Your standing is unavailable',
                          style: context.type.bodyMedium,
                        )
                      : Row(
                          children: [
                            RankedBadge(
                              league: _own!.standing.league,
                              decorative: true,
                              size: 40,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You · ${_own!.standing.qualified ? '${_own!.standing.rating} Elo · ${_own!.standing.positionLabel}' : _own!.standing.placementLabel}',
                                style: context.type.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
  Widget _header(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (!widget.seasons && _context != null) ...[
        DropdownButtonFormField<String>(
          initialValue: _context!.id,
          key: ValueKey(_context!.id),
          decoration: const InputDecoration(labelText: 'Season · IST'),
          isExpanded: true,
          items: (_months.toList()..sort((a, b) => b.compareTo(a)))
              .map(
                (id) =>
                    DropdownMenuItem(value: id, child: Text(seasonLabel(id))),
              )
              .toList(),
          onChanged: _loading
              ? null
              : (id) {
                  _season = id;
                  _own = null;
                  _entries.clear();
                  _context = null;
                  _load(reset: true);
                },
        ),
        const SizedBox(height: 12),
        Text(_context!.context, style: context.type.bodyMedium),
        Text(
          'Rating high to low. Equal ratings use learner ID order.',
          style: context.type.bodySmall,
        ),
        if (_asOf != null)
          Text(
            'Updated ${istInstant(DateTime.parse(_asOf!))}',
            style: context.type.bodySmall,
          ),
        if (_pagination == 'LIVE_MAY_MOVE')
          Text(
            'Live positions can change between pages. Refresh for the latest order.',
            style: context.type.bodySmall,
          ),
        TextButton(
          onPressed: () => context.push(AppRoutes.rankedSeasons),
          child: const Text('Your season history'),
        ),
      ],
      if (widget.seasons)
        Text(
          'Played seasons only · monthly calendar in IST',
          style: context.type.bodyMedium,
        ),
      if (_error != null)
        SessionNotice(
          message: _error!,
          onRetry: () => _load(reset: !_failedMore),
        ),
      if (_loading) const LinearProgressIndicator(),
      const SizedBox(height: 16),
    ],
  );
  Widget _footer(BuildContext context, int length) => Column(
    children: [
      if (!_loading && length == 0 && _error == null)
        AppStateView(
          title: widget.seasons
              ? 'No played seasons yet'
              : 'No qualified players yet',
          message: widget.seasons
              ? 'Your rated seasons will appear here.'
              : 'Complete placements to join the board.',
        ),
      if ((widget.seasons ? _before : _cursor) != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: OutlinedButton(
            onPressed: _loading ? null : () => _load(),
            child: Text(_loading ? 'Loading…' : 'Load more'),
          ),
        ),
    ],
  );
  Widget _entryRow(BuildContext context, RankedEntry row) => LayoutBuilder(
    builder: (context, constraints) {
      final position = TextPainter(
        text: TextSpan(
          text: '#${row.position}',
          style: context.type.titleSmall,
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final nameWidth = constraints.maxWidth - position.width - 96;
      position.dispose();
      final large = !textFits(
        context,
        row.name,
        context.type.titleSmall!,
        nameWidth,
        maxLines: 3,
      );
      final identity = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.name, style: context.type.titleSmall),
          Text(
            '${row.league.label} · ${row.rating} Elo',
            style: context.type.bodyMedium,
          ),
        ],
      );
      final avatar = LearnerAvatar(
        person: {'name': row.name, 'avatarUrl': row.avatarUrl},
        radius: 18,
      );
      final badge = RankedBadge(league: row.league, decorative: true, size: 36);
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: large
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '#${row.position}',
                            style: context.type.titleSmall,
                          ),
                          avatar,
                          badge,
                        ],
                      ),
                      const SizedBox(height: 8),
                      identity,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#${row.position}', style: context.type.titleSmall),
                      const SizedBox(width: 12),
                      avatar,
                      const SizedBox(width: 12),
                      Expanded(child: identity),
                      badge,
                    ],
                  ),
          ),
          const Divider(height: 1),
        ],
      );
    },
  );
  Widget _seasonRow(BuildContext context, Map<String, dynamic> row) {
    final season = RankedSeason.fromJson(rankedMap(row['season'])),
        s = RankedStanding.fromJson(rankedMap(row['standing']));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RankedBadge(league: s.league, decorative: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(season.label, style: context.type.titleMedium),
                  Text(
                    '${s.league.label} · ${s.rating} Elo',
                    style: context.type.bodyLarge,
                  ),
                  Text(
                    season.finalized
                        ? s.positionLabel
                        : row['resultsFinalizing'] == true
                        ? 'Results finalizing'
                        : s.qualified
                        ? 'Season in progress'
                        : 'Qualification incomplete',
                    style: context.type.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SessionMetrics(
          items: [
            (label: 'W / L / D', value: '${s.wins} / ${s.losses} / ${s.draws}'),
            (
              label: 'Qualified peak',
              value: s.peakRating == null
                  ? 'Not available'
                  : '${s.peakRating} Elo',
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => context.push(
              '${AppRoutes.rankedLeaderboard}?seasonId=${season.id}',
            ),
            child: const Text('View season leaderboard'),
          ),
        ),
      ],
    );
  }
}
