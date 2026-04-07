import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';
import '../proto/quiz.pbgrpc.dart';

/// Step 58: Singleton gRPC service that wraps all three backend services.
class QuizService {
  static final QuizService _instance = QuizService._internal();
  factory QuizService() => _instance;

  late final ClientChannel _matchmakingChannel;
  late final ClientChannel _quizChannel;
  late final ClientChannel _scoringChannel;

  late final MatchmakingServiceClient matchmaking;
  late final QuizServiceClient quiz;
  late final ScoringServiceClient scoring;
  CallOptions? _authOptions;

  QuizService._internal() {
    _matchmakingChannel = ClientChannel(
      'localhost',
      port: 50051,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
    _quizChannel = ClientChannel(
      'localhost',
      port: 50052,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
    _scoringChannel = ClientChannel(
      'localhost',
      port: 50053,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );

    matchmaking = MatchmakingServiceClient(_matchmakingChannel);
    quiz = QuizServiceClient(_quizChannel);
    scoring = ScoringServiceClient(_scoringChannel);
  }

  void setAuthToken(String token) {
    _authOptions = CallOptions(metadata: {'authorization': 'Bearer $token'});
  }

  void clearAuth() {
    _authOptions = null;
  }

  Future<JoinMatchmakingResponse> joinMatchmaking(String userId, int rating) {
    return matchmaking.joinMatchmaking(
      JoinMatchmakingRequest()
        ..userId = userId
        ..rating = rating,
      options: _authOptions,
    );
  }

  Future<LeaveMatchmakingResponse> leaveMatchmaking(String userId) {
    return matchmaking.leaveMatchmaking(
      LeaveMatchmakingRequest()..userId = userId,
      options: _authOptions,
    );
  }

  ResponseStream<MatchEvent> subscribeToMatch(String userId,
      {int sequenceNumber = 0}) {
    return matchmaking.subscribeToMatch(
      SubscribeToMatchRequest()
        ..userId = userId
        ..sequenceNumber = Int64(sequenceNumber),
      options: _authOptions,
    );
  }

  Future<GetRoomQuestionsResponse> getRoomQuestions(String roomId) {
    return quiz.getRoomQuestions(
      GetRoomQuestionsRequest()..roomId = roomId,
      options: _authOptions,
    );
  }

  ResponseStream<GameEvent> streamGameEvents(String roomId, String userId,
      {int sequenceNumber = 0}) {
    return quiz.streamGameEvents(
      StreamGameEventsRequest()
        ..roomId = roomId
        ..userId = userId
        ..sequenceNumber = Int64(sequenceNumber),
      options: _authOptions,
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
      options: _authOptions,
    );
  }

  Future<GetLeaderboardResponse> getLeaderboard(String roomId) {
    return scoring.getLeaderboard(
      GetLeaderboardRequest()..roomId = roomId,
      options: _authOptions,
    );
  }

  Future<void> shutdown() async {
    await _matchmakingChannel.shutdown();
    await _quizChannel.shutdown();
    await _scoringChannel.shutdown();
  }
}
