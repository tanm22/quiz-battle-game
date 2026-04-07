import 'package:grpc/grpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../proto/quiz.pbgrpc.dart';

/// Singleton auth service — handles registration, login, and token persistence.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  late final ClientChannel _channel;
  late final AuthServiceClient _client;

  String? _token;
  String? _userId;
  String? _username;
  int _rating = 1200;
  int _matchesPlayed = 0;
  int _wins = 0;

  AuthService._internal() {
    _channel = ClientChannel(
      'localhost',
      port: 50054,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
    _client = AuthServiceClient(_channel);
  }

  String? get token => _token;
  String? get userId => _userId;
  String? get username => _username;
  int get rating => _rating;
  int get matchesPlayed => _matchesPlayed;
  int get wins => _wins;

  /// Load stored auth state from SharedPreferences on app start.
  Future<bool> tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _userId = prefs.getString('auth_user_id');
    _username = prefs.getString('auth_username');
    _rating = prefs.getInt('auth_rating') ?? 1200;
    _matchesPlayed = prefs.getInt('auth_matches_played') ?? 0;
    _wins = prefs.getInt('auth_wins') ?? 0;

    if (_token == null || _userId == null) return false;

    // Verify token is still valid by fetching profile
    try {
      final profile = await _client.getProfile(
        GetProfileRequest(),
        options: CallOptions(metadata: {'authorization': 'Bearer $_token'}),
      );
      _rating = profile.rating;
      _matchesPlayed = profile.matchesPlayed;
      _wins = profile.wins;
      await _saveToPrefs();
      return true;
    } catch (_) {
      // Token expired or invalid — clear and require re-login
      await logout();
      return false;
    }
  }

  Future<void> register(String username, String password) async {
    final resp = await _client.register(
      RegisterRequest()
        ..username = username
        ..password = password,
    );
    _token = resp.token;
    _userId = resp.userId;
    _username = resp.username;
    _rating = resp.rating;
    _matchesPlayed = resp.matchesPlayed;
    _wins = resp.wins;
    await _saveToPrefs();
  }

  Future<void> login(String username, String password) async {
    final resp = await _client.login(
      LoginRequest()
        ..username = username
        ..password = password,
    );
    _token = resp.token;
    _userId = resp.userId;
    _username = resp.username;
    _rating = resp.rating;
    _matchesPlayed = resp.matchesPlayed;
    _wins = resp.wins;
    await _saveToPrefs();
  }

  bool get isLoggedIn => _token != null && _userId != null;

  CallOptions get authOptions =>
      CallOptions(metadata: {'authorization': 'Bearer $_token'});

  Future<void> logout() async {
    _token = null;
    _userId = null;
    _username = null;
    _rating = 1200;
    _matchesPlayed = 0;
    _wins = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) prefs.setString('auth_token', _token!);
    if (_userId != null) prefs.setString('auth_user_id', _userId!);
    if (_username != null) prefs.setString('auth_username', _username!);
    prefs.setInt('auth_rating', _rating);
    prefs.setInt('auth_matches_played', _matchesPlayed);
    prefs.setInt('auth_wins', _wins);
  }
}
