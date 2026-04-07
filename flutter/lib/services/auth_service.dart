import 'package:grpc/grpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../proto/quiz.pbgrpc.dart';

/// Singleton auth service — handles registration, login, guest login,
/// email-based auth, and token persistence.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  late final ClientChannel _channel;
  late final AuthServiceClient _client;

  String? _token;
  String? _userId;
  String? _username;
  String? _email;
  bool _isGuest = false;
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
  String? get email => _email;
  bool get isGuest => _isGuest;
  int get rating => _rating;
  int get matchesPlayed => _matchesPlayed;
  int get wins => _wins;

  /// Load stored auth state from SharedPreferences on app start.
  Future<bool> tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _userId = prefs.getString('auth_user_id');
    _username = prefs.getString('auth_username');
    _email = prefs.getString('auth_email');
    _isGuest = prefs.getBool('auth_is_guest') ?? false;
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
      if (profile.email.isNotEmpty) _email = profile.email;
      _isGuest = profile.isGuest;
      await _saveToPrefs();
      return true;
    } catch (_) {
      // Token expired or invalid — clear and require re-login
      await logout();
      return false;
    }
  }

  Future<void> register(String username, String password, {String? email}) async {
    final req = RegisterRequest()
      ..username = username
      ..password = password;
    if (email != null && email.isNotEmpty) {
      req.email = email;
    }
    final resp = await _client.register(req);
    _token = resp.token;
    _userId = resp.userId;
    _username = resp.username;
    _rating = resp.rating;
    _matchesPlayed = resp.matchesPlayed;
    _wins = resp.wins;
    _isGuest = resp.isGuest;
    if (resp.email.isNotEmpty) _email = resp.email;
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
    _isGuest = resp.isGuest;
    if (resp.email.isNotEmpty) _email = resp.email;
    await _saveToPrefs();
  }

  Future<void> guestLogin() async {
    final resp = await _client.guestLogin(GuestLoginRequest());
    _token = resp.token;
    _userId = resp.userId;
    _username = resp.username;
    _rating = resp.rating;
    _isGuest = resp.isGuest;
    _matchesPlayed = resp.matchesPlayed;
    _wins = resp.wins;
    if (resp.email.isNotEmpty) _email = resp.email;
    await _saveToPrefs();
  }

  Future<void> sendEmailCode(String email, String purpose) async {
    await _client.sendEmailCode(
      SendEmailCodeRequest()
        ..email = email
        ..purpose = purpose,
    );
  }

  Future<VerifyEmailCodeResponse> verifyEmailCode(String email, String code) async {
    final resp = await _client.verifyEmailCode(
      VerifyEmailCodeRequest()
        ..email = email
        ..code = code,
    );
    // If a token is returned (e.g. email login flow), store auth state
    if (resp.token.isNotEmpty) {
      _token = resp.token;
      _userId = resp.userId;
      _email = email;
      await _saveToPrefs();
    }
    return resp;
  }

  Future<void> linkEmail(String email, String code) async {
    await _client.linkEmail(
      LinkEmailRequest()
        ..email = email
        ..code = code,
      options: authOptions,
    );
    _email = email;
    _isGuest = false;
    await _saveToPrefs();
  }

  Future<void> resetPassword(String email, String code, String newPassword) async {
    await _client.resetPassword(
      ResetPasswordRequest()
        ..email = email
        ..code = code
        ..newPassword = newPassword,
    );
  }

  Future<void> loginWithEmail(String email) async {
    await _client.loginWithEmail(
      EmailLoginRequest()..email = email,
    );
  }

  Future<bool> checkUsername(String username) async {
    final resp = await _client.checkUsername(
      CheckUsernameRequest()..username = username,
    );
    return resp.available;
  }

  bool get isLoggedIn => _token != null && _userId != null;

  CallOptions get authOptions =>
      CallOptions(metadata: {'authorization': 'Bearer $_token'});

  Future<void> logout() async {
    _token = null;
    _userId = null;
    _username = null;
    _email = null;
    _isGuest = false;
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
    if (_email != null) prefs.setString('auth_email', _email!);
    prefs.setBool('auth_is_guest', _isGuest);
    prefs.setInt('auth_rating', _rating);
    prefs.setInt('auth_matches_played', _matchesPlayed);
    prefs.setInt('auth_wins', _wins);
  }
}
