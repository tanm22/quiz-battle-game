import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';
import '../proto/quiz.pbgrpc.dart';

/// Backend host — use 10.0.2.2 for Android emulator, localhost for desktop/web.
/// Override via --dart-define=BACKEND_HOST=your.host.ip
const _backendHost = String.fromEnvironment('BACKEND_HOST', defaultValue: 'localhost');

/// Step 58: Singleton gRPC service that wraps all three backend services.
class QuizService {
  static final QuizService _instance = QuizService._internal();
  factory QuizService() => _instance;

  late final ClientChannel _matchmakingChannel;
  late final ClientChannel _quizChannel;
  late final ClientChannel _scoringChannel;
  late final ClientChannel _paymentChannel;

  late final MatchmakingServiceClient matchmaking;
  late final QuizServiceClient quiz;
  late final ScoringServiceClient scoring;
  late final PaymentServiceClient payment;
  CallOptions? _authOptions;

  QuizService._internal() {
    _matchmakingChannel = ClientChannel(
      _backendHost,
      port: 50051,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
    _quizChannel = ClientChannel(
      _backendHost,
      port: 50052,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
    _scoringChannel = ClientChannel(
      _backendHost,
      port: 50053,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );

    _paymentChannel = ClientChannel(
      _backendHost,
      port: 50055,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );

    matchmaking = MatchmakingServiceClient(_matchmakingChannel);
    quiz = QuizServiceClient(_quizChannel);
    scoring = ScoringServiceClient(_scoringChannel);
    payment = PaymentServiceClient(_paymentChannel);
  }

  static const _defaultTimeout = Duration(seconds: 10);

  void setAuthToken(String token) {
    _authOptions = CallOptions(metadata: {'authorization': 'Bearer $token'});
  }

  void clearAuth() {
    _authOptions = null;
  }

  /// Expose auth options for direct client access (e.g. home screen data).
  CallOptions get authCallOptions => _opts();

  /// Merges auth metadata with a per-call timeout.
  CallOptions _opts({Duration timeout = _defaultTimeout}) {
    return CallOptions(
      metadata: _authOptions?.metadata ?? {},
      timeout: timeout,
    );
  }

  Future<JoinMatchmakingResponse> joinMatchmaking(String userId, int rating) {
    return matchmaking.joinMatchmaking(
      JoinMatchmakingRequest()
        ..userId = userId
        ..rating = rating,
      options: _opts(),
    );
  }

  Future<LeaveMatchmakingResponse> leaveMatchmaking(String userId) {
    return matchmaking.leaveMatchmaking(
      LeaveMatchmakingRequest()..userId = userId,
      options: _opts(),
    );
  }

  ResponseStream<MatchEvent> subscribeToMatch(String userId,
      {int sequenceNumber = 0}) {
    return matchmaking.subscribeToMatch(
      SubscribeToMatchRequest()
        ..userId = userId
        ..sequenceNumber = Int64(sequenceNumber),
      options: _opts(timeout: const Duration(minutes: 5)),
    );
  }

  Future<GetRoomQuestionsResponse> getRoomQuestions(String roomId) {
    return quiz.getRoomQuestions(
      GetRoomQuestionsRequest()..roomId = roomId,
      options: _opts(),
    );
  }

  ResponseStream<GameEvent> streamGameEvents(String roomId, String userId,
      {int sequenceNumber = 0}) {
    return quiz.streamGameEvents(
      StreamGameEventsRequest()
        ..roomId = roomId
        ..userId = userId
        ..sequenceNumber = Int64(sequenceNumber),
      options: _opts(timeout: const Duration(minutes: 10)),
    );
  }

  Future<SubmitAnswerResponse> submitAnswer({
    required String roomId,
    required String userId,
    required int round,
    required int optionIndex,
    required int clientTimestamp,
  }) {
    return quiz.submitAnswer(
      SubmitAnswerRequest()
        ..roomId = roomId
        ..userId = userId
        ..round = round
        ..optionIndex = optionIndex
        ..clientTimestamp = Int64(clientTimestamp),
      options: _opts(timeout: const Duration(seconds: 5)),
    );
  }

  Future<GetLeaderboardResponse> getLeaderboard(String roomId) {
    return scoring.getLeaderboard(
      GetLeaderboardRequest()..roomId = roomId,
      options: _opts(),
    );
  }

  Future<GetMatchHistoryResponse> getMatchHistory({int limit = 20, int offset = 0}) {
    return scoring.getMatchHistory(
      GetMatchHistoryRequest()
        ..limit = limit
        ..offset = offset,
      options: _opts(),
    );
  }

  Future<GetGlobalLeaderboardResponse> getGlobalLeaderboard({String timeFilter = 'alltime'}) {
    return scoring.getGlobalLeaderboard(
      GetGlobalLeaderboardRequest()..timeFilter = timeFilter,
      options: _opts(),
    );
  }

  Future<GetTournamentListResponse> getTournamentList() {
    return quiz.getTournamentList(
      GetTournamentListRequest(),
      options: _opts(),
    );
  }

  Future<JoinTournamentResponse> joinTournament(String tournamentId) {
    return quiz.joinTournament(
      JoinTournamentRequest()..tournamentId = tournamentId,
      options: _opts(),
    );
  }

  Future<GetReferralDashboardResponse> getReferralDashboard() {
    return scoring.getReferralDashboard(
      GetReferralDashboardRequest(),
      options: _opts(),
    );
  }

  Future<ApplyReferralCodeResponse> applyReferralCode(String code) {
    return scoring.applyReferralCode(
      ApplyReferralCodeRequest()..code = code,
      options: _opts(),
    );
  }

  Future<void> shutdown() async {
    await _matchmakingChannel.shutdown();
    await _quizChannel.shutdown();
    await _scoringChannel.shutdown();
    await _paymentChannel.shutdown();
  }
}
