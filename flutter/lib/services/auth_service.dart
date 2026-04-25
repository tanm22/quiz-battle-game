import 'package:google_sign_in/google_sign_in.dart';
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
  bool _onboardingCompleted = false;
  List<String> _preferredTopics = const [];
  String? _avatarUrl;

  static const _backendHost = String.fromEnvironment('BACKEND_HOST', defaultValue: 'localhost');
  // Web (server) client ID — used on Android to request an idToken, and by the backend to verify it.
  // Pass via --dart-define=GOOGLE_SERVER_CLIENT_ID=...
  static const _googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  // iOS client ID — pass via --dart-define=GOOGLE_IOS_CLIENT_ID=...
  static const _googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  AuthService._internal() {
    _channel = ClientChannel(
      _backendHost,
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
  bool get onboardingCompleted => _onboardingCompleted;
  List<String> get preferredTopics => _preferredTopics;
  String? get avatarUrl => _avatarUrl;

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
    _onboardingCompleted = prefs.getBool('auth_onboarding_completed') ?? false;

    if (_token == null || _userId == null) return false;

    // Verify token is still valid by fetching profile (short timeout to avoid blocking startup)
    try {
      final profile = await _client.getProfile(
        GetProfileRequest(),
        options: _opts(timeout: const Duration(seconds: 5)),
      );
      _rating = profile.rating;
      _matchesPlayed = profile.matchesPlayed;
      _wins = profile.wins;
      if (profile.email.isNotEmpty) _email = profile.email;
      _isGuest = profile.isGuest;
      _onboardingCompleted = profile.onboardingCompleted;
      _preferredTopics = List<String>.from(profile.preferredTopics);
      if (profile.avatarUrl.isNotEmpty) _avatarUrl = profile.avatarUrl;
      await _saveToPrefs();
      return true;
    } catch (_) {
      // Token expired or invalid — clear and require re-login
      await logout();
      return false;
    }
  }

  Future<void> register(String username, String password, {String? email, String? referralCode}) async {
    final req = RegisterRequest()
      ..username = username
      ..password = password;
    if (email != null && email.isNotEmpty) {
      req.email = email;
    }
    if (referralCode != null && referralCode.isNotEmpty) {
      req.referralCode = referralCode;
    }
    final resp = await _client.register(req, options: _opts());
    _token = resp.token;
    _userId = resp.userId;
    _username = resp.username;
    _rating = resp.rating;
    _matchesPlayed = resp.matchesPlayed;
    _wins = resp.wins;
    _isGuest = resp.isGuest;
    _onboardingCompleted = resp.onboardingCompleted;
    if (resp.email.isNotEmpty) _email = resp.email;
    await _saveToPrefs();
  }

  Future<void> login(String username, String password) async {
    final resp = await _client.login(
      LoginRequest()
        ..username = username
        ..password = password,
      options: _opts(),
    );
    _token = resp.token;
    _userId = resp.userId;
    _username = resp.username;
    _rating = resp.rating;
    _matchesPlayed = resp.matchesPlayed;
    _wins = resp.wins;
    _isGuest = resp.isGuest;
    _onboardingCompleted = resp.onboardingCompleted;
    if (resp.email.isNotEmpty) _email = resp.email;
    await _saveToPrefs();
  }

  Future<void> guestLogin() async {
    final resp = await _client.guestLogin(GuestLoginRequest(), options: _opts());
    _token = resp.token;
    _userId = resp.userId;
    _username = resp.username;
    _rating = resp.rating;
    _isGuest = resp.isGuest;
    _matchesPlayed = resp.matchesPlayed;
    _wins = resp.wins;
    _onboardingCompleted = resp.onboardingCompleted;
    if (resp.email.isNotEmpty) _email = resp.email;
    await _saveToPrefs();
  }

  Future<GoogleSignInResponse> signInWithGoogle({String? referralCode}) async {
    final googleSignIn = GoogleSignIn(
      serverClientId: _googleServerClientId.isNotEmpty ? _googleServerClientId : null,
      clientId: _googleIosClientId.isNotEmpty ? _googleIosClientId : null,
      scopes: ['email'],
    );

    final account = await googleSignIn.signIn();
    if (account == null) {
      throw Exception('Google sign-in was cancelled');
    }

    final authentication = await account.authentication;
    final idToken = authentication.idToken;
    if (idToken == null) {
      throw Exception('Failed to obtain Google ID token');
    }

    final req = GoogleSignInRequest()..idToken = idToken;
    if (referralCode != null && referralCode.isNotEmpty) {
      req.referralCode = referralCode;
    }

    final resp = await _client.googleSignIn(req, options: _opts());
    final profile = resp.userProfile;
    _token = resp.token;
    _userId = profile.userId;
    _username = profile.username;
    _email = profile.email;
    _isGuest = false;
    _rating = profile.rating;
    _matchesPlayed = profile.matchesPlayed;
    _wins = profile.wins;
    _onboardingCompleted = profile.onboardingCompleted;
    _preferredTopics = List<String>.from(profile.preferredTopics);
    if (profile.avatarUrl.isNotEmpty) _avatarUrl = profile.avatarUrl;
    await _saveToPrefs();

    return resp;
  }

  Future<void> sendEmailCode(String email, String purpose) async {
    await _client.sendEmailCode(
      SendEmailCodeRequest()
        ..email = email
        ..purpose = purpose,
      options: _opts(),
    );
  }

  Future<VerifyEmailCodeResponse> verifyEmailCode(String email, String code) async {
    final resp = await _client.verifyEmailCode(
      VerifyEmailCodeRequest()
        ..email = email
        ..code = code,
      options: _opts(),
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
      options: _opts(),
    );
  }

  Future<void> loginWithEmail(String email) async {
    await _client.loginWithEmail(
      EmailLoginRequest()..email = email,
      options: _opts(),
    );
  }

  Future<bool> checkUsername(String username) async {
    final resp = await _client.checkUsername(
      CheckUsernameRequest()..username = username,
      options: _opts(timeout: const Duration(seconds: 3)),
    );
    return resp.available;
  }

  /// Claim daily streak reward.
  Future<void> claimDailyReward() async {
    await _client.claimDailyReward(
      ClaimDailyRewardRequest(),
      options: _opts(),
    );
  }

  /// Refresh profile from server — call after match to get updated rating/stats.
  Future<void> refreshProfile() async {
    if (_token == null) return;
    try {
      final profile = await _client.getProfile(
        GetProfileRequest(),
        options: _opts(timeout: const Duration(seconds: 5)),
      );
      _rating = profile.rating;
      _matchesPlayed = profile.matchesPlayed;
      _wins = profile.wins;
      if (profile.email.isNotEmpty) _email = profile.email;
      _isGuest = profile.isGuest;
      await _saveToPrefs();
    } catch (_) {
      // Silently fail — will use cached values
    }
  }

  /// Delete account permanently.
  Future<void> deleteAccount() async {
    if (_token == null) return;
    await _client.deleteAccount(
      DeleteAccountRequest(),
      options: _opts(),
    );
    await logout();
  }

  bool get isLoggedIn => _token != null && _userId != null;

  static const _defaultTimeout = Duration(seconds: 10);

  CallOptions get authOptions => _opts();

  /// Merges auth metadata with a per-call timeout.
  CallOptions _opts({Duration timeout = _defaultTimeout}) {
    return CallOptions(
      metadata: _token != null ? {'authorization': 'Bearer $_token'} : {},
      timeout: timeout,
    );
  }

  /// Persist onboarding data to the backend.
  /// Any null/empty argument is omitted (partial update on the server).
  Future<void> updateProfile({
    String? displayName,
    String? avatarUrl,
    List<String>? preferredTopics,
    bool markOnboardingCompleted = false,
  }) async {
    final req = UpdateProfileRequest();
    if (displayName != null && displayName.isNotEmpty) {
      req.displayName = displayName;
    }
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      req.avatarUrl = avatarUrl;
    }
    if (preferredTopics != null && preferredTopics.isNotEmpty) {
      req.preferredTopics.addAll(preferredTopics);
    }
    if (markOnboardingCompleted) {
      req.onboardingCompleted = true;
    }
    await _client.updateProfile(req, options: authOptions);
    if (markOnboardingCompleted) _onboardingCompleted = true;
    if (preferredTopics != null) {
      _preferredTopics = List.unmodifiable(preferredTopics);
    }
    if (avatarUrl != null && avatarUrl.isNotEmpty) _avatarUrl = avatarUrl;
    await _saveToPrefs();
  }

  Future<void> logout() async {
    try { await GoogleSignIn().signOut(); } catch (_) {}
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
    prefs.setBool('auth_onboarding_completed', _onboardingCompleted);
  }
}
