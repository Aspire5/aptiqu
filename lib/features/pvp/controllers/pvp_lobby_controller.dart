import '../ranked/ranked_models.dart';
import '../ranked/ranked_repository.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../home/presentation/controllers/home_controller.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../practice/models/practice_models.dart';
import '../../practice/controllers/practice_session_controller.dart';
import '../models/pvp_history_model.dart';
import '../services/pvp_socket_service.dart';

class PvpLobbyController extends GetxController {
  final PvpSocketService _socketService;
  final RankedRepository repository;
  PvpLobbyController({
    PvpSocketService? socketService,
    RankedRepository? repository,
  }) : _socketService = socketService ?? PvpSocketService(),
       repository = repository ?? RankedRepository();
  final summary = Rxn<RankedSummary>();
  final standingError = ''.obs, standingStatus = ''.obs;
  final isLoadingStanding = false.obs,
      isPairing = false.obs,
      isPreparingQuestions = false.obs,
      searchExpanded = false.obs,
      queueUncertain = false.obs;
  final hasMoreHistory = false.obs;
  int _historyPage = 1;
  String? _account;
  Worker? _accountWorker;
  Future<void>? _summaryRequest, _refreshRequest;
  bool get _owned => !isClosed && repository.owner == _account;
  Future<void> fetchSummary() => _summaryRequest ??= _loadSummary()
      .whenComplete(() => _summaryRequest = null);
  Future<void> _loadSummary() async {
    isLoadingStanding.value = true;
    standingError.value = '';
    try {
      final value = await repository.me();
      if (!_owned) return;
      final old = summary.value;
      if (old == null ||
          value.season.id != old.season.id ||
          value.standing.version >= old.standing.version) {
        summary.value = value;
      }
      standingStatus.value = 'AVAILABLE';
      queueUncertain.value = false;
    } catch (e) {
      if (!_owned) return;
      standingStatus.value = e is RankedFailure && e.code == 'RANKED_DISABLED'
          ? 'DISABLED'
          : 'UNAVAILABLE';
      if (standingStatus.value == 'DISABLED') {
        queueUncertain.value = false;
      } else {
        standingError.value = summary.value == null
            ? 'Standing unavailable. Please retry.'
            : 'Standing may be out of date. Retry refresh.';
      }
    } finally {
      if (_owned) isLoadingStanding.value = false;
    }
  }

  Future<void> refreshRanked() => _refreshRequest ??= Future.wait([
    fetchSummary(),
    fetchHistory(),
  ]).then((_) {}).whenComplete(() => _refreshRequest = null);
  Future<void> resumeMatch() async {
    final id = summary.value?.activeMatchId;
    if (id != null && !isOpeningMatch.value) {
      await _openMatch({'matchId': id, 'resume': true});
    }
  }

  StreamSubscription? _sub;
  Worker? _presentationWorker;
  final RxBool isInQueue = false.obs,
      isCancelling = false.obs,
      isOpeningMatch = false.obs;
  final RxString statusMessage = 'Ready to play'.obs,
      queueError = ''.obs,
      historyError = ''.obs;
  final RxInt secondsInQueue = 0.obs;
  Timer? _queueTimer, _cancelTimer, _preparationReconnect;
  String? _preparationId;
  int _preparationVersion = -1;
  int _queueGeneration = 0;
  final RxList<PvpMatchHistoryItemModel> matchHistory =
      <PvpMatchHistoryItemModel>[].obs;
  final RxBool isLoadingHistory = false.obs, isReplayingMatch = false.obs;
  @override
  void onInit() {
    super.onInit();
    _account = repository.owner;
    if (Get.isRegistered<AuthController>()) {
      _accountWorker = ever(Get.find<AuthController>().currentUser, (_) {
        if (repository.owner == _account) return;
        ++_queueGeneration;
        _socketService.leaveMatchmaking();
        _socketService.disconnect();
        summary.value = null;
        matchHistory.clear();
        isInQueue.value = false;
        isPairing.value = false;
        isPreparingQuestions.value = false;
        _preparationReconnect?.cancel();
        _preparationReconnect = null;
        isCancelling.value = false;
        isOpeningMatch.value = false;
        isReplayingMatch.value = false;
        isLoadingStanding.value = false;
        isLoadingHistory.value = false;
        standingError.value = '';
        historyError.value = '';
        queueError.value = '';
        _cancelTimer?.cancel();
        _stopQueueTimer();
        // A later login receives a fresh owner-bound controller.
        if (Get.isRegistered<PvpLobbyController>() &&
            identical(Get.find<PvpLobbyController>(), this)) {
          Get.delete<PvpLobbyController>();
        }
      });
    }
    _presentationWorker = everAll([
      isInQueue,
      isCancelling,
      isOpeningMatch,
      isReplayingMatch,
    ], (_) => _syncPresentationActivity());
    _syncPresentationActivity();
    _sub = _socketService.eventStream.listen(_event);
    _socketService.connect();
    refreshRanked();
  }

  void _syncPresentationActivity() => AppRouter.overlayGate.setTask(
    this,
    isInQueue.value ||
        isCancelling.value ||
        isOpeningMatch.value ||
        isReplayingMatch.value,
  );

  void _event(Map<String, dynamic> event) {
    if (!_owned) return;
    final data = event['data'] as Map<String, dynamic>? ?? {};
    switch (event['event']) {
      case 'AUTH_SUCCESS':
        _preparationReconnect?.cancel();
        _preparationReconnect = null;
        break;
      case 'QUESTIONS_PREPARING':
        final id = data['id'] as String?;
        final version = (data['version'] as num?)?.toInt() ?? 0;
        if (id == _preparationId && version < _preparationVersion) break;
        _preparationId = id;
        _preparationVersion = version;
        isPreparingQuestions.value = true;
        isPairing.value = true;
        isInQueue.value = true;
        isCancelling.value = false;
        queueUncertain.value = false;
        queueError.value = '';
        _cancelTimer?.cancel();
        _stopQueueTimer();
        statusMessage.value = 'Finalising your questions…';
        break;
      case 'QUEUE_STATUS':
        if (data['waitedMs'] is num) {
          secondsInQueue.value = ((data['waitedMs'] as num).toInt() / 1000)
              .floor();
        }
        searchExpanded.value = data['searchExpanded'] == true;
        if (data['status'] == 'PAIRING') {
          isPairing.value = true;
          isInQueue.value = true;
          isCancelling.value = false;
          _cancelTimer?.cancel();
          statusMessage.value = 'Opponent found. Preparing match…';
          break;
        }
        if (isPairing.value) break;
        if (data['status'] == 'LEFT_QUEUE') {
          isInQueue.value = false;
          isCancelling.value = false;
          _cancelTimer?.cancel();
          _stopQueueTimer();
          statusMessage.value = 'Ready to play';
        } else if (data['status'] == 'WAITING_FOR_OPPONENT' ||
            data['status'] == 'ALREADY_IN_QUEUE') {
          isInQueue.value = true;
          statusMessage.value = 'Finding an opponent…';
          if (_queueTimer == null) {
            _startQueueTimer(reset: data['waitedMs'] is! num);
          }
          if (isCancelling.value) _socketService.leaveMatchmaking();
        }
        break;
      case 'MATCH_FOUND':
        isPreparingQuestions.value = false;
        _preparationReconnect?.cancel();
        if (isOpeningMatch.value) return;
        _stopQueueTimer();
        _cancelTimer?.cancel();
        isCancelling.value = false;
        isPairing.value = false;
        isInQueue.value = false;
        _openMatch(data);
        break;
      case 'CONNECTION_LOST':
        if (isPreparingQuestions.value) {
          statusMessage.value = 'Reconnecting to your questions…';
          _preparationReconnect ??= Timer.periodic(const Duration(seconds: 3), (
            _,
          ) {
            if (_owned) unawaited(_socketService.connect());
          });
          unawaited(_socketService.connect());
          break;
        }
        queueUncertain.value = isPairing.value || isInQueue.value;
        isPairing.value = false;
        isInQueue.value = false;
        queueError.value = 'Ranked connection interrupted. Please reconnect.';
        _stopQueueTimer();
        break;
      case 'ERROR':
        isPreparingQuestions.value = false;
        _preparationReconnect?.cancel();
        _preparationReconnect = null;
        queueUncertain.value = isPairing.value || isInQueue.value;
        isPairing.value = false;
        unawaited(fetchSummary());
        _stopQueueTimer();
        _cancelTimer?.cancel();
        isInQueue.value = false;
        isCancelling.value = false;
        queueError.value =
            data['message']?.toString() ??
            'Could not connect to Ranked. Please try again.';
        statusMessage.value = 'Ready to play';
        break;
    }
  }

  Future<void> _openMatch(Map<String, dynamic> data) async {
    isOpeningMatch.value = true;
    statusMessage.value = 'Match found. Opening…';
    queueError.value = '';
    try {
      await AppRouter.router.push(
        AppRoutes.pvpArena,
        extra: {
          'matchId': data['matchId'] as String,
          'resume': data['resume'] == true,
          'initialPlayersData': data['players'] as List<dynamic>? ?? [],
          'totalQuestions': data['totalQuestions'] as int? ?? 10,
        },
      );
      if (_owned) {
        await refreshRanked();
        if (Get.isRegistered<HomeController>()) {
          unawaited(Get.find<HomeController>().fetchDashboard());
        }
      }
    } catch (_) {
      if (_owned) {
        queueError.value = 'Could not open this match. Please try again.';
      }
    } finally {
      if (_owned) {
        isOpeningMatch.value = false;
        statusMessage.value = 'Ready to play';
      }
    }
  }

  Future<void> startMatchmaking() async {
    if (isInQueue.value ||
        isCancelling.value ||
        isOpeningMatch.value ||
        isReplayingMatch.value ||
        isPairing.value ||
        queueUncertain.value ||
        !_owned) {
      return;
    }
    final generation = ++_queueGeneration;
    // Mark busy before refreshing so repeated taps cannot race a pending read.
    isInQueue.value = true;
    if (standingStatus.value == 'AVAILABLE') {
      await fetchSummary();
    } else {
      // Read outages do not disable a healthy queue. Admission still checks
      // active seats in PostgreSQL; refresh recovery information separately.
      unawaited(fetchSummary());
    }
    if (!_owned || generation != _queueGeneration || !isInQueue.value) return;
    if (summary.value?.activeMatchId != null ||
        summary.value?.admissionPaused == true) {
      isInQueue.value = false;
      queueError.value = summary.value?.activeMatchId != null
          ? 'Resume your existing match or wait for its result.'
          : 'Match search is paused. Please retry later.';
      return;
    }
    searchExpanded.value = false;
    queueError.value = '';
    isInQueue.value = true;
    statusMessage.value = 'Connecting to Ranked…';
    _startQueueTimer();
    await _socketService.connect();
    if (isClosed || generation != _queueGeneration || !isInQueue.value) return;
    if (!_socketService.isConnected) {
      isInQueue.value = false;
      _stopQueueTimer();
      queueError.value = 'Could not connect to Ranked. Please try again.';
      return;
    }
    await _socketService.joinMatchmaking();
  }

  void cancelMatchmaking() {
    if (!_owned || isCancelling.value || isPairing.value) return;
    ++_queueGeneration;
    if (!_socketService.isConnected) {
      isInQueue.value = false;
      _stopQueueTimer();
      return;
    }
    isCancelling.value = true;
    statusMessage.value = 'Cancelling matchmaking…';
    _socketService.leaveMatchmaking();
    _cancelTimer?.cancel();
    _cancelTimer = Timer(const Duration(seconds: 10), () {
      if (isClosed || !isCancelling.value) return;
      isCancelling.value = false;
      queueError.value = 'Cancellation was not confirmed. Try Cancel again.';
    });
  }

  void _startQueueTimer({bool reset = true}) {
    if (reset) secondsInQueue.value = 0;
    _queueTimer?.cancel();
    _queueTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      secondsInQueue.value++;
    });
  }

  void _stopQueueTimer() {
    _queueTimer?.cancel();
    _queueTimer = null;
  }

  Future<void> fetchHistory({bool more = false}) async {
    if (isLoadingHistory.value || !_owned) return;
    isLoadingHistory.value = true;
    historyError.value = '';
    final page = more ? _historyPage + 1 : 1;
    try {
      final data = await repository.history(page: page);
      final list = (data['history'] as List)
          .map((item) => PvpMatchHistoryItemModel.fromJson(rankedMap(item)))
          .toList();
      if (!_owned) return;
      if (!more) matchHistory.clear();
      final known = matchHistory.map((m) => m.matchId).toSet();
      matchHistory.addAll(list.where((m) => known.add(m.matchId)));
      _historyPage = page;
      hasMoreHistory.value =
          data['pagination'] is Map &&
          page < rankedInt(rankedMap(data['pagination'])['totalPages']);
    } catch (_) {
      if (_owned) {
        historyError.value = 'Could not load match history. Please try again.';
      }
    } finally {
      if (_owned) isLoadingHistory.value = false;
    }
  }

  /// Existing solo Practice replay: untimed, no opponent, no replay rewards.
  Future<void> replayMatchInPractice(String matchId) async {
    if (isReplayingMatch.value ||
        isInQueue.value ||
        isCancelling.value ||
        isOpeningMatch.value ||
        isClosed) {
      return;
    }
    isReplayingMatch.value = true;
    queueError.value = '';
    try {
      final res = await Get.find<DioClient>().dio.post(
        '/pvp/replay/$matchId',
        options: Options(receiveTimeout: const Duration(seconds: 45)),
      );
      if (res.statusCode != 201 || res.data['success'] != true) {
        throw Exception(res.data['message'] ?? 'Failed to replay match');
      }
      final session = PracticeSessionModel.fromJson(
        res.data['data'] as Map<String, dynamic>,
      );
      if (!_owned) return;
      if (Get.isRegistered<PracticeSessionController>()) {
        Get.delete<PracticeSessionController>();
      }
      await AppRouter.router.push(AppRoutes.practiceSession, extra: session);
    } catch (_) {
      if (_owned) {
        queueError.value = 'Could not open the replay. Please try again.';
      }
    } finally {
      if (!isClosed) isReplayingMatch.value = false;
    }
  }

  @override
  void onClose() {
    _accountWorker?.dispose();
    _presentationWorker?.dispose();
    AppRouter.overlayGate.setTask(this, false);
    _sub?.cancel();
    _preparationReconnect?.cancel();
    _queueTimer?.cancel();
    _cancelTimer?.cancel();
    super.onClose();
  }
}
