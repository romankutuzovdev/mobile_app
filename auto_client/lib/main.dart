import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AutoAssistantApp());
}

/// Цвета приложения (тёмная тема)
class AppColors {
  static const background = Color(0xFF020617);
  static const backgroundElevated = Color(0xCC020617);
  static const accentPrimary = Color(0xFF22C55E);
  static const accentSecondary = Color(0xFF14F4FF);
  static const accentSoft = Color(0x3322C55E);

  static const textPrimary = Color(0xFFF9FAFB);
  static const textSecondary = Color(0xFF9CA3AF);
  static const textMuted = Color(0xFF6B7280);

  static const error = Color(0xFFF97373);
}

/// Цвета светлой темы
class LightThemeColors {
  /// Фон по центру — светло-серый как на скрине (#F2F2F2)
  static const background = Color(0xFFF2F2F2);
  /// Градиент сверху: мягкий персиковый → плавный переход в фон
  static const backgroundGradientStart = Color(0xFFFFF0E6);
  static const backgroundGradientEnd = Color(0xFFF2F2F2);
  static const accentOrange = Color(0xFFFFA82F);
  static const accentOrangeBorder = Color(0xFFFFA82F);

  static const textPrimary = Color(0xFF1F2937);
  static const textSecondary = Color(0xFF4B5563);
  static const textMuted = Color(0xFF6B7280);

  static const cardBackground = Color(0xFF1F2937);
  static const cardBorder = Color(0x1A000000);

  /// Кнопки онбординга
  static const buttonPrimaryBg = Color(0xFFFFA82F);
  static const buttonPrimaryText = Color(0xFF1F2937);
  static const buttonSecondaryBg = Color(0xFFFFFFFF);
  static const buttonSecondaryBorder = Color(0xFFE5E7EB);
  static const buttonSecondaryText = Color(0xFF1F2937);
}

/// Тема
class AppTheme {
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'SF Pro Text',
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accentPrimary,
      secondary: AppColors.accentSecondary,
      background: AppColors.background,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xB30F172A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.accentPrimary, width: 1.4),
      ),
      hintStyle: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 14,
      ),
      labelStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accentPrimary,
        foregroundColor: Colors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
      ),
    ),
  );

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: LightThemeColors.background,
    fontFamily: 'SF Pro Text',
    colorScheme: const ColorScheme.light(
      primary: LightThemeColors.accentOrange,
      secondary: LightThemeColors.accentOrange,
      surface: LightThemeColors.background,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: LightThemeColors.textPrimary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: LightThemeColors.accentOrange,
          width: 1.4,
        ),
      ),
      hintStyle: const TextStyle(color: LightThemeColors.textMuted, fontSize: 14),
      labelStyle: const TextStyle(
        color: LightThemeColors.textSecondary,
        fontSize: 14,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: LightThemeColors.accentOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: LightThemeColors.accentOrange,
        side: const BorderSide(color: LightThemeColors.accentOrange),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(
        color: LightThemeColors.textPrimary,
        fontSize: 14,
      ),
    ),
  );
}

/// Клиент API
class ApiClient {
  /// Базовый URL бэкенда
  static String get _baseUrl {
    return 'http://localhost:8001';
  }

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 120),
      receiveTimeout: const Duration(seconds: 120),
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('access_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (e, handler) async {
          // Здесь можно будет добавить обновление токена по refresh_token
          return handler.next(e);
        },
      ),
    );

  static Future<void> saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }
}

/// Сервис код-пароля и биометрии
class PasscodeService {
  static const _storage = FlutterSecureStorage();
  static const _keyPasscode = 'app_passcode';

  static Future<void> setPasscode(String passcode) async {
    if (kIsWeb) return;
    await _storage.write(key: _keyPasscode, value: passcode);
  }

  static Future<bool> hasPasscode() async {
    if (kIsWeb) return false;
    try {
      final v = await _storage.read(key: _keyPasscode);
      return v != null && v.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> verifyPasscode(String passcode) async {
    if (kIsWeb) return false;
    try {
      final stored = await _storage.read(key: _keyPasscode);
      return stored == passcode;
    } catch (_) {
      return false;
    }
  }

  static Future<void> clearPasscode() async {
    if (kIsWeb) return;
    await _storage.delete(key: _keyPasscode);
  }

  static Future<bool> canUseBiometrics() async {
    if (kIsWeb) return false;
    try {
      final auth = LocalAuthentication();
      return await auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticateWithBiometrics() async {
    if (kIsWeb) return false;
    try {
      final auth = LocalAuthentication();
      return await auth.authenticate(
        localizedReason: 'Разблокировать приложение',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

/// Уведомления в Telegram (для запросов "не нашли авто")
class TelegramNotifier {
  /// TODO: подставьте сюда реальные данные
  static const String _botToken =
      '7502109831:AAEgT9iiww8PJTHGq8nFtZN4fQbxz-txb9U';
  static const String _chatId = '7207166462';

  static bool get _enabled => _botToken.isNotEmpty && _chatId.isNotEmpty;

  /// Отправить сообщение, что пользователь не нашёл своё авто
  static Future<void> sendCarNotFound({
    required String vin,
    String? phone,
  }) async {
    if (!_enabled) return;

    final buffer = StringBuffer()
      ..writeln('🚗 Пользователь не нашёл своё авто')
      ..writeln('VIN: $vin');
    if (phone != null && phone.isNotEmpty) {
      buffer.writeln('Телефон: $phone');
    }

    final text = buffer.toString();

    try {
      await Dio().post(
        'https://api.telegram.org/bot$_botToken/sendMessage',
        data: {
          'chat_id': _chatId,
          'text': text,
        },
      );
    } catch (_) {
      // Для демо игнорируем ошибку, можно добавить логирование
    }
  }
}

/// Модель сообщения чата
class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage(this.text, this.isUser);
}

/// Приложение
class AutoAssistantApp extends StatelessWidget {
  const AutoAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Auto Assistant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}

/// Splash + проверка сессии
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 800));
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      final hasPasscode = await PasscodeService.hasPasscode();
      if (hasPasscode) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PasscodeUnlockScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingPager()),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightThemeColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.directions_car_filled_rounded,
                color: LightThemeColors.accentOrange, size: 72),
            SizedBox(height: 16),
            Text(
              'AI Auto Assistant',
              style: TextStyle(
                color: LightThemeColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Онбординг
class OnboardingPager extends StatefulWidget {
  const OnboardingPager({super.key});

  @override
  State<OnboardingPager> createState() => _OnboardingPagerState();
}

class _OnboardingPagerState extends State<OnboardingPager> {
  final _controller = PageController();
  int _page = 0;

  void _goNext() {
    if (_page == 0) {
      _controller.animateToPage(
        1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightThemeColors.background,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 180,
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      LightThemeColors.backgroundGradientStart,
                      LightThemeColors.background,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: const [
                    _OnboardingPage1(),
                    _OnboardingPage2(),
                  ],
                ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        2,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: i == _page ? 20 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: i == _page
                                ? LightThemeColors.accentOrange
                                : const Color(0xFFD1D5DB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _goNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LightThemeColors.buttonPrimaryBg,
                          foregroundColor: LightThemeColors.buttonPrimaryText,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(_page == 0 ? 'Далее' : 'Начать'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const PhoneLoginScreen(),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: LightThemeColors.buttonSecondaryText,
                          backgroundColor: LightThemeColors.buttonSecondaryBg,
                          side: const BorderSide(
                            color: LightThemeColors.buttonSecondaryBorder,
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        child: const Text('Уже зарегистрированны? Войти'),
                      ),
                    ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage1 extends StatelessWidget {
  const _OnboardingPage1();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'AI-помощник для вашего автомобиля',
                  style: TextStyle(
                    color: LightThemeColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'VIN, мануалы и умные ответы именно по вашему авто',
                  style: TextStyle(
                    color: LightThemeColors.textSecondary,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320, maxHeight: 420),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/onboarding_iphone_mockup.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'AI анализирует данные по VIN и даёт точные рекомендации',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LightThemeColors.textPrimary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage2 extends StatelessWidget {
  const _OnboardingPage2();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Определяет авто по VIN за секунды',
                  style: TextStyle(
                    color: LightThemeColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Добавьте авто по VIN и задавайте вопросы именно по вашему автомобилю',
                  style: TextStyle(
                    color: LightThemeColors.textSecondary,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320, maxHeight: 420),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/onboarding_iphone_mockup_2.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Добавьте авто по VIN — и получайте ответы именно по вашей модели',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: LightThemeColors.textPrimary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Экран логина по телефону/паролю
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;
  int _step = 0; // 0 = телефон, 1 = пароль

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (phone.isEmpty || password.isEmpty) {
      setState(() => _error = 'Введите телефон и пароль');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Можно убрать '+' перед отправкой, если бэкенд ждёт только цифры
      final normalizedPhone = phone.startsWith('+') ? phone.substring(1) : phone;

      final response = await ApiClient.dio.post(
        '/auth/login',
        data: {
          'phone': normalizedPhone,
          'password': password,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final access = data['access_token'] as String? ?? '';
      final refresh = data['refresh_token'] as String? ?? '';

      await ApiClient.saveTokens(access, refresh);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['detail']?.toString() ?? 'Ошибка авторизации';
      });
    } catch (e) {
      setState(() => _error = 'Ошибка: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _goToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightThemeColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: LightThemeColors.textPrimary),
          onPressed: () {
            if (_step == 1) {
              setState(() => _step = 0);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const Text(
          'Авторизация',
          style: TextStyle(
            color: LightThemeColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_step + 1}/2',
                style: const TextStyle(
                  color: LightThemeColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_step == 0) ...[
                const Text(
                  'Введите номер телефона',
                  style: TextStyle(
                    color: LightThemeColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: const TextStyle(
                    color: LightThemeColors.textPrimary,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: '7 999 123 45 67',
                    hintStyle: TextStyle(
                      color: LightThemeColors.textMuted,
                      fontSize: 16,
                    ),
                    prefixText: '+',
                    prefixStyle: const TextStyle(
                      color: LightThemeColors.textPrimary,
                      fontSize: 16,
                    ),
                    filled: false,
                    border: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: LightThemeColors.accentOrange,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                const Text(
                  'Введите пароль',
                  style: TextStyle(
                    color: LightThemeColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(
                    color: LightThemeColors.textPrimary,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Пароль',
                    hintStyle: TextStyle(
                      color: LightThemeColors.textMuted,
                      fontSize: 16,
                    ),
                    filled: false,
                    border: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: LightThemeColors.accentOrange,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 14),
                ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading
                      ? null
                      : () {
                          if (_step == 0) {
                            final phone = _phoneController.text.trim();
                            if (phone.isEmpty) {
                              setState(() => _error = 'Введите номер телефона');
                              return;
                            }
                            setState(() {
                              _step = 1;
                              _error = null;
                            });
                          } else {
                            _login();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LightThemeColors.buttonPrimaryBg,
                    foregroundColor: LightThemeColors.buttonPrimaryText,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Color(0xFF1F2937)),
                          ),
                        )
                      : Text(_step == 0 ? 'Получить код' : 'Войти'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _goToRegister,
                  child: const Text(
                    'Нет аккаунта? Зарегистрироваться',
                    style: TextStyle(
                      color: LightThemeColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Экран регистрации с верификацией телефона
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;
  int _step = 0; // 0 = телефон + согласие, 1 = пароль, 2 = подтверждение пароля
  bool _consentAccepted = true;

  Future<void> _register() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (phone.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Заполните все поля');
      return;
    }
    if (!_consentAccepted) {
      setState(() => _error = 'Необходимо согласие на обработку персональных данных');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Пароли не совпадают');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final normalizedPhone = phone.startsWith('+') ? phone.substring(1) : phone;

      // Регистрация пользователя
      await ApiClient.dio.post(
        '/auth/register',
        data: {
          'phone': normalizedPhone,
          'password': password,
        },
      );

      // Отправка кода верификации
      await ApiClient.dio.post(
        '/auth/send-verification-code',
        data: {
          'phone': normalizedPhone,
        },
      );

      if (!mounted) return;
      
      // Переход на экран верификации
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PhoneVerificationScreen(
            phone: normalizedPhone,
            password: password,
          ),
        ),
      );
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['detail']?.toString() ?? 'Ошибка регистрации';
      });
    } catch (e) {
      setState(() => _error = 'Ошибка: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  bool get _canProceed {
    if (_step == 0) {
      return _phoneController.text.trim().isNotEmpty && _consentAccepted;
    }
    if (_step == 1) return _passwordController.text.isNotEmpty;
    return true;
  }

  void _goNext() {
    if (_step == 0) {
      final phone = _phoneController.text.trim();
      if (phone.isEmpty) {
        setState(() => _error = 'Введите номер телефона');
        return;
      }
      if (!_consentAccepted) {
        setState(() => _error = 'Необходимо согласие на обработку персональных данных');
        return;
      }
      setState(() {
        _step = 1;
        _error = null;
      });
    } else if (_step == 1) {
      if (_passwordController.text.isEmpty) {
        setState(() => _error = 'Введите пароль');
        return;
      }
      setState(() {
        _step = 2;
        _error = null;
      });
    } else {
      _register();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightThemeColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: LightThemeColors.textPrimary),
          onPressed: () {
            if (_step > 0) {
              setState(() => _step--);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const Text(
          'Регистрация',
          style: TextStyle(
            color: LightThemeColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_step + 1}/4',
                style: const TextStyle(
                  color: LightThemeColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_step == 0) ...[
                const Text(
                  'Введите данные для регистрации',
                  style: TextStyle(
                    color: LightThemeColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _phoneController,
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: const TextStyle(
                    color: LightThemeColors.textPrimary,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: '7 999 123 45 67',
                    hintStyle: TextStyle(
                      color: LightThemeColors.textMuted,
                      fontSize: 16,
                    ),
                    prefixText: '+',
                    prefixStyle: const TextStyle(
                      color: LightThemeColors.textPrimary,
                      fontSize: 16,
                    ),
                    filled: false,
                    border: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: LightThemeColors.accentOrange,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                InkWell(
                  onTap: () => setState(() => _consentAccepted = !_consentAccepted),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _consentAccepted,
                          onChanged: (v) => setState(() => _consentAccepted = v ?? false),
                          activeColor: LightThemeColors.accentOrange,
                          fillColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return LightThemeColors.accentOrange;
                            }
                            return Colors.transparent;
                          }),
                          side: BorderSide(
                            color: _consentAccepted
                                ? LightThemeColors.accentOrange
                                : const Color(0xFFE0E0E0),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: LightThemeColors.textPrimary,
                                fontSize: 14,
                                height: 1.4,
                              ),
                              children: [
                                const TextSpan(text: 'Вы даёте согласие на обработку ваших '),
                                TextSpan(
                                  text: 'персональных данных',
                                  style: const TextStyle(
                                    color: LightThemeColors.accentOrange,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_step == 1) ...[
                const Text(
                  'Придумайте пароль',
                  style: TextStyle(
                    color: LightThemeColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _passwordController,
                  onChanged: (_) => setState(() {}),
                  obscureText: true,
                  style: const TextStyle(
                    color: LightThemeColors.textPrimary,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Пароль',
                    hintStyle: TextStyle(
                      color: LightThemeColors.textMuted,
                      fontSize: 16,
                    ),
                    filled: false,
                    border: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: LightThemeColors.accentOrange,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                const Text(
                  'Повторите пароль',
                  style: TextStyle(
                    color: LightThemeColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _confirmController,
                  obscureText: true,
                  style: const TextStyle(
                    color: LightThemeColors.textPrimary,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Повторите пароль',
                    hintStyle: TextStyle(
                      color: LightThemeColors.textMuted,
                      fontSize: 16,
                    ),
                    filled: false,
                    border: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: LightThemeColors.accentOrange,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 14),
                ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : _goNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canProceed
                        ? LightThemeColors.accentOrange
                        : const Color(0xFF1F2937),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Продолжить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Экран настройки код-пароля (шаг 4/4 регистрации)
class PasscodeSetupScreen extends StatefulWidget {
  const PasscodeSetupScreen({super.key});

  @override
  State<PasscodeSetupScreen> createState() => _PasscodeSetupScreenState();
}

class _PasscodeSetupScreenState extends State<PasscodeSetupScreen> {
  final List<int> _digits = [];
  bool _showError = false;

  void _onDigit(int d) {
    if (_digits.length >= 4) return;
    setState(() {
      _digits.add(d);
      _showError = false;
    });
    if (_digits.length == 4) {
      _complete();
    }
  }

  void _onBackspace() {
    if (_digits.isEmpty) return;
    setState(() {
      _digits.removeLast();
      _showError = false;
    });
  }

  Future<void> _complete() async {
    final passcode = _digits.join();
    await PasscodeService.setPasscode(passcode);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightThemeColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: LightThemeColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Регистрация',
          style: TextStyle(
            color: LightThemeColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '4/4',
                style: const TextStyle(
                  color: LightThemeColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Введите код-пароль',
                style: TextStyle(
                  color: LightThemeColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Введите 4 цифры, которые будут использованы для разблокировки приложения',
                style: TextStyle(
                  color: LightThemeColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = i < _digits.length;
                    return Container(
                      width: 16,
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _showError
                            ? AppColors.error
                            : filled
                                ? LightThemeColors.textPrimary
                                : const Color(0xFFD0D0D0),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    );
                  }),
                ),
              ),
              const Spacer(),
              _PasscodeKeypad(
                onDigit: _onDigit,
                onBackspace: _onBackspace,
                showBiometric: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Экран разблокировки по код-паролю
class PasscodeUnlockScreen extends StatefulWidget {
  const PasscodeUnlockScreen({super.key});

  @override
  State<PasscodeUnlockScreen> createState() => _PasscodeUnlockScreenState();
}

class _PasscodeUnlockScreenState extends State<PasscodeUnlockScreen> {
  final List<int> _digits = [];
  bool _showError = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final ok = await PasscodeService.canUseBiometrics();
    if (mounted) setState(() => _biometricAvailable = ok);
  }

  void _onDigit(int d) {
    if (_digits.length >= 4) return;
    setState(() {
      _digits.add(d);
      _showError = false;
    });
    if (_digits.length == 4) {
      _verify();
    }
  }

  void _onBackspace() {
    if (_digits.isEmpty) return;
    setState(() {
      _digits.removeLast();
      _showError = false;
    });
  }

  Future<void> _verify() async {
    final passcode = _digits.join();
    final ok = await PasscodeService.verifyPasscode(passcode);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } else {
      setState(() {
        _digits.clear();
        _showError = true;
      });
    }
  }

  Future<void> _tryBiometric() async {
    final ok = await PasscodeService.authenticateWithBiometrics();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightThemeColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            children: [
              const Text(
                'Введите код-пароль',
                style: TextStyle(
                  color: LightThemeColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Введите 4 цифры для разблокировки',
                style: TextStyle(
                  color: LightThemeColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 40),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = i < _digits.length;
                    return Container(
                      width: 16,
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _showError
                            ? AppColors.error
                            : filled
                                ? LightThemeColors.textPrimary
                                : const Color(0xFFD0D0D0),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    );
                  }),
                ),
              ),
              const Spacer(),
              _PasscodeKeypad(
                onDigit: _onDigit,
                onBackspace: _onBackspace,
                showBiometric: _biometricAvailable,
                onBiometric: _tryBiometric,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Цифровая клавиатура для код-пароля
class _PasscodeKeypad extends StatelessWidget {
  final void Function(int) onDigit;
  final VoidCallback onBackspace;
  final bool showBiometric;
  final VoidCallback? onBiometric;

  const _PasscodeKeypad({
    required this.onDigit,
    required this.onBackspace,
    required this.showBiometric,
    this.onBiometric,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _KeypadButton(value: 1, onTap: () => onDigit(1)),
            _KeypadButton(value: 2, onTap: () => onDigit(2)),
            _KeypadButton(value: 3, onTap: () => onDigit(3)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _KeypadButton(value: 4, onTap: () => onDigit(4)),
            _KeypadButton(value: 5, onTap: () => onDigit(5)),
            _KeypadButton(value: 6, onTap: () => onDigit(6)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _KeypadButton(value: 7, onTap: () => onDigit(7)),
            _KeypadButton(value: 8, onTap: () => onDigit(8)),
            _KeypadButton(value: 9, onTap: () => onDigit(9)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: IconButton(
                onPressed: onBackspace,
                icon: const Icon(
                  Icons.backspace_outlined,
                  size: 24,
                  color: LightThemeColors.textPrimary,
                ),
              ),
            ),
            _KeypadButton(value: 0, onTap: () => onDigit(0)),
            showBiometric && onBiometric != null
                ? SizedBox(
                    width: 72,
                    height: 72,
                    child: IconButton(
                      onPressed: onBiometric,
                      icon: const Icon(
                        Icons.face_rounded,
                        size: 32,
                        color: LightThemeColors.textPrimary,
                      ),
                    ),
                  )
                : const SizedBox(width: 72, height: 72),
          ],
        ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final int value;
  final VoidCallback onTap;

  const _KeypadButton({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(36),
          child: SizedBox(
            width: 72,
            height: 72,
            child: Center(
              child: Text(
                '$value',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                  color: LightThemeColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Экран верификации телефона
class PhoneVerificationScreen extends StatefulWidget {
  final String phone;
  final String password;

  const PhoneVerificationScreen({
    super.key,
    required this.phone,
    required this.password,
  });

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  bool _verifying = false;
  String? _error;
  int _resendTimer = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer = 60; // 60 секунд
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendCode() async {
    if (_resendTimer > 0) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ApiClient.dio.post(
        '/auth/send-verification-code',
        data: {
          'phone': widget.phone,
        },
      );

      if (!mounted) return;
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Код отправлен повторно'),
          backgroundColor: AppColors.accentPrimary,
        ),
      );
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['detail']?.toString() ?? 'Ошибка отправки кода';
      });
    } catch (e) {
      setState(() => _error = 'Ошибка: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty || code.length < 4) {
      setState(() => _error = 'Введите код подтверждения');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      // Подтверждение телефона
      await ApiClient.dio.post(
        '/auth/verify-phone',
        data: {
          'phone': widget.phone,
          'code': code,
        },
      );

      // Автоматический вход после верификации
      final loginResponse = await ApiClient.dio.post(
        '/auth/login',
        data: {
          'phone': widget.phone,
          'password': widget.password,
        },
      );

      final data = loginResponse.data as Map<String, dynamic>;
      final access = data['access_token'] as String? ?? '';
      final refresh = data['refresh_token'] as String? ?? '';

      await ApiClient.saveTokens(access, refresh);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PasscodeSetupScreen()),
        (_) => false,
      );
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['detail']?.toString() ?? 'Неверный код подтверждения';
      });
    } catch (e) {
      setState(() => _error = 'Ошибка: $e');
    } finally {
      if (mounted) {
        setState(() => _verifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Подтверждение телефона'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Введите код подтверждения',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Код отправлен на номер +${widget.phone}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 8,
                ),
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  labelText: 'Код подтверждения',
                  hintText: '000000',
                  counterText: '',
                ),
                onSubmitted: (_) => _verifyCode(),
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_verifying || _loading) ? null : _verifyCode,
                  child: _verifying
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : const Text('Подтвердить'),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: _resendTimer > 0
                    ? Text(
                        'Повторная отправка через $_resendTimer сек',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                      )
                    : TextButton(
                        onPressed: _loading ? null : _sendCode,
                        child: const Text(
                          'Отправить код повторно',
                          style: TextStyle(color: AppColors.accentPrimary),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Основной shell с нижней навигацией
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _screens = const [
    ChatScreen(),
    CarsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _screens[_index],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF020617),
        currentIndex: _index,
        selectedItemColor: AppColors.accentPrimary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome),
            label: 'AI чат',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car_filled_rounded),
            label: 'Мои авто',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}

/// Экран списка авто
class CarsScreen extends StatefulWidget {
  const CarsScreen({super.key});

  @override
  State<CarsScreen> createState() => _CarsScreenState();
}

class _CarsScreenState extends State<CarsScreen> {
  bool _loading = false;
  String? _error;
  List<dynamic> _cars = [];
  int? _currentCarId;

  Future<void> _loadCars() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiClient.dio.get('/cars/');
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getInt('current_car_id');
      setState(() {
        _cars = response.data as List<dynamic>;
        _currentCarId = savedId;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки списка авто: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _setCurrentCar(int id, {bool closeScreen = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_car_id', id);
    setState(() {
      _currentCarId = id;
    });
    if (!mounted) return;
    // Если экран был открыт поверх чата (через кнопку "Сменить"),
    // вернёмся назад и дадим знать, что авто изменилось.
    if (closeScreen) {
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.pop(true);
      }
    }
  }

  /// Установить текущее авто без закрытия экрана (для открытия деталей)
  Future<void> _setCurrentCarSilent(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_car_id', id);
    setState(() {
      _currentCarId = id;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadCars();
  }

  void _openAddCar() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddCarByVinScreen()),
    ).then((_) => _loadCars());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Мои автомобили'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _openAddCar,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCars,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ListView(
                      children: [
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ],
                    )
                  : _cars.isEmpty
                      ? const Center(
                          child: Text(
                            'Автомобилей пока нет.\nДобавьте через VIN.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _cars.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final car = _cars[index] as Map<String, dynamic>;
                            final id = car['id'] as int?;
                            final brand = car['brand']?.toString() ?? '';
                            final model = car['model']?.toString() ?? '';
                            final year = car['year']?.toString() ?? '';
                            final vin = car['vin']?.toString() ?? '';
                            final createdAtStr = car['created_at']?.toString();
                            DateTime? createdAt;
                            if (createdAtStr != null) {
                              try {
                                createdAt = DateTime.parse(createdAtStr);
                              } catch (_) {
                                createdAt = null;
                              }
                            }

                            final isCurrent = id != null && id == _currentCarId;

                            return InkWell(
                              onTap: () {
                                if (id != null) {
                                  // Устанавливаем авто как текущее для чата (без закрытия экрана)
                                  _setCurrentCar(id, closeScreen: false);
                                  // Открываем экран деталей
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          CarDetailsScreen(car: car),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xB30F172A),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isCurrent
                                        ? AppColors.accentPrimary
                                        : Colors.white.withOpacity(0.06),
                                  ),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    const Icon(Icons.directions_car_filled_rounded,
                                        color: AppColors.accentSecondary),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            [
                                              brand,
                                              model,
                                              if (year.isNotEmpty) '($year)'
                                            ].where((e) => e.isNotEmpty).join(' '),
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (vin.isNotEmpty)
                                            Text(
                                              'VIN: $vin',
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 13,
                                              ),
                                            ),
                                          if (createdAt != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Добавлено: '
                                              '${createdAt.day.toString().padLeft(2, '0')}.'
                                              '${createdAt.month.toString().padLeft(2, '0')}.'
                                              '${createdAt.year}',
                                              style: const TextStyle(
                                                color: AppColors.textMuted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                          // Дополнительная пометка выбранного авто убрана по требованию
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}

/// Экран добавления авто по VIN (упрощён)
class AddCarByVinScreen extends StatefulWidget {
  const AddCarByVinScreen({super.key});

  @override
  State<AddCarByVinScreen> createState() => _AddCarByVinScreenState();
}

class _AddCarByVinScreenState extends State<AddCarByVinScreen> {
  final _vinController = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _vinInfo;
  String? _error;

  Future<void> _searchVin() async {
    final vin = _vinController.text.trim();
    if (vin.length != 17) {
      setState(() => _error = 'VIN должен содержать 17 символов');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _vinInfo = null;
    });

    try {
      final response = await ApiClient.dio.post(
        '/cars/search-vin',
        data: {'vin': vin},
      );
      setState(() {
        _vinInfo = response.data as Map<String, dynamic>;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['detail']?.toString() ??
            'Не удалось определить авто';
      });
    } catch (e) {
      setState(() => _error = 'Ошибка: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _addCar() async {
    final vin = _vinController.text.trim();
    if (vin.length != 17) {
      setState(() => _error = 'VIN должен содержать 17 символов');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ApiClient.dio.post('/cars/add-by-vin', data: {'vin': vin});
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['detail']?.toString() ??
            'Не удалось добавить авто';
      });
    } catch (e) {
      setState(() => _error = 'Ошибка: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vinInfo = _vinInfo;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Добавить авто по VIN'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _vinController,
                maxLength: 17,
                decoration: const InputDecoration(
                  labelText: 'VIN',
                  hintText: 'Например, WDB12345678901234',
                ),
              ),
              const SizedBox(height: 8),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  final vin = _vinController.text.trim();
                  String? phone;
                  try {
                    final resp = await ApiClient.dio.get('/auth/me');
                    phone = resp.data['phone']?.toString();
                  } catch (_) {
                    phone = null;
                  }

                  await TelegramNotifier.sendCarNotFound(
                    vin: vin.isEmpty ? 'VIN не указан' : vin,
                    phone: phone,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Сообщение отправлено. Спасибо!'),
                    ),
                  );
                },
                child: const Text(
                  'Не нашли своё авто? Сообщить нам',
                  style: TextStyle(color: AppColors.accentPrimary),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _searchVin,
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                          : const Text('Проверить авто'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (vinInfo != null)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _loading ? null : _addCar,
                        child: const Text('Добавить'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (vinInfo != null)
                Builder(
                  builder: (context) {
                    final basic = vinInfo['basic_info'] as Map<String, dynamic>?;
                    final brand = basic?['brand']?.toString() ?? '';
                    final model = basic?['model']?.toString() ?? '';
                    final year = basic?['year'];

                    final engine =
                        vinInfo['engine'] as Map<String, dynamic>?;
                    final transmission =
                        vinInfo['transmission'] as Map<String, dynamic>?;
                    final dimensions =
                        vinInfo['dimensions'] as Map<String, dynamic>?;
                    final fuel =
                        vinInfo['fuel'] as Map<String, dynamic>?;
                    final safety =
                        vinInfo['safety'] as Map<String, dynamic>?;
                    final trims =
                        vinInfo['possible_trim_levels'] as List<dynamic>?;
                    final notes = vinInfo['notes']?.toString();

                    return Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xB30F172A),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (brand.isNotEmpty || model.isNotEmpty)
                            Text(
                              '$brand $model',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (year != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              year.toString(),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          if (engine != null && engine.isNotEmpty) ...[
                            const Text(
                              'Двигатель',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (engine['type'] != null)
                              Text('Тип: ${engine['type']}'),
                            if (engine['code'] != null)
                              Text('Код: ${engine['code']}'),
                            if (engine['volume_l'] != null)
                              Text('Объём: ${engine['volume_l']} л'),
                            if (engine['power_hp'] != null)
                              Text('Мощность: ${engine['power_hp']} л.с.'),
                            const SizedBox(height: 8),
                          ],
                          if (transmission != null &&
                              transmission.isNotEmpty) ...[
                            const Text(
                              'Трансмиссия',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (transmission['type'] != null)
                              Text('Тип: ${transmission['type']}'),
                            if (transmission['gears'] != null)
                              Text('Передачи: ${transmission['gears']}'),
                            if (transmission['drive'] != null)
                              Text('Привод: ${transmission['drive']}'),
                            const SizedBox(height: 8),
                          ],
                          if (dimensions != null && dimensions.isNotEmpty) ...[
                            const Text(
                              'Габариты',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (dimensions['length_mm'] != null)
                              Text('Длина: ${dimensions['length_mm']} мм'),
                            if (dimensions['width_mm'] != null)
                              Text('Ширина: ${dimensions['width_mm']} мм'),
                            if (dimensions['height_mm'] != null)
                              Text('Высота: ${dimensions['height_mm']} мм'),
                            if (dimensions['wheelbase_mm'] != null)
                              Text(
                                  'Колёсная база: ${dimensions['wheelbase_mm']} мм'),
                            const SizedBox(height: 8),
                          ],
                          if (fuel != null && fuel.isNotEmpty) ...[
                            const Text(
                              'Топливо',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (fuel['fuel_type'] != null)
                              Text('Тип: ${fuel['fuel_type']}'),
                            if (fuel['average_consumption_l_per_100km'] != null)
                              Text(
                                  'Расход: ${fuel['average_consumption_l_per_100km']} л/100 км'),
                            if (fuel['tank_l'] != null)
                              Text('Бак: ${fuel['tank_l']} л'),
                            const SizedBox(height: 8),
                          ],
                          if (safety != null && safety.isNotEmpty) ...[
                            const Text(
                              'Безопасность',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (safety['airbags'] != null)
                              Text('Подушки: ${safety['airbags']}'),
                            if (safety['abs'] != null)
                              Text('ABS: ${safety['abs']}'),
                            if (safety['esp'] != null)
                              Text('ESP: ${safety['esp']}'),
                            if (safety['traction_control'] != null)
                              Text(
                                  'Стабилизация: ${safety['traction_control']}'),
                            const SizedBox(height: 8),
                          ],
                          if (trims != null && trims.isNotEmpty) ...[
                            const Text(
                              'Возможные комплектации',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              trims.join(', '),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (notes != null && notes.isNotEmpty) ...[
                            const Text(
                              'Примечания',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notes,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Экран детальной информации об авто (демо, с мок‑данными)
class CarDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> car;

  const CarDetailsScreen({super.key, required this.car});

  @override
  Widget build(BuildContext context) {
    final brand = car['brand']?.toString() ?? '';
    final model = car['model']?.toString() ?? '';
    final year = car['year']?.toString() ?? '';
    final vin = car['vin']?.toString() ?? '';
    final createdAtStr = car['created_at']?.toString();

    DateTime? createdAt;
    if (createdAtStr != null) {
      try {
        createdAt = DateTime.parse(createdAtStr);
      } catch (_) {
        createdAt = null;
      }
    }

    String createdAtText;
    if (createdAt != null) {
      createdAtText =
          '${createdAt.day.toString().padLeft(2, '0')}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.year}';
    } else {
      createdAtText = 'дата не указана';
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Детали автомобиля'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0F172A),
                      Color(0xFF022C22),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 52,
                          width: 52,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.directions_car_filled_rounded,
                            color: AppColors.accentSecondary,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$brand $model',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (year.isNotEmpty)
                                Text(
                                  year,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (vin.isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons.confirmation_number_rounded,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'VIN: $vin',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.event_note_rounded,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Добавлено: $createdAtText',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'ТО и обслуживание',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xB30F172A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _BulletLine('Замена масла каждые 8 000–10 000 км или 1 год.'),
                    _BulletLine('ТО‑1: масло, фильтр, осмотр подвески и тормозов.'),
                    _BulletLine('ТО‑2: добавляется замена свечей и салонного фильтра.'),
                    SizedBox(height: 4),
                    Text(
                      'Данные примерные и будут уточняться на основе VIN и мануалов.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Расходники',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xB30F172A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _KeyValueRow(label: 'Масло двигателя', value: '5W‑30, объём ~4–5 л'),
                    _KeyValueRow(label: 'Фильтр масляный', value: 'Оригинал / аналог по VIN'),
                    _KeyValueRow(label: 'Фильтр воздушный', value: 'Замена каждые 20–30 тыс. км'),
                    _KeyValueRow(label: 'Тормозные колодки', value: 'Ресурс 30–50 тыс. км'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Типичные проблемы',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xB30F172A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _BulletLine('Подтекание масла по прокладке клапанной крышки.'),
                    _BulletLine('Износ стойк стабилизатора и втулок подвески.'),
                    _BulletLine('Шумы от подшипников ступиц на высоком пробеге.'),
                    SizedBox(height: 4),
                    Text(
                      'В финальной версии список будет формироваться индивидуально '
                      'по модели и двигателю на основе базы поломок и отзывов.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String text;

  const _BulletLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              color: AppColors.accentPrimary,
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _KeyValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Экран чата
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _sending = false;
  int? _currentCarId;
  String? _currentCarTitle;
  String? _currentCarSubtitle;

  @override
  void initState() {
    super.initState();
    _loadCurrentCarAndHistory();
  }

  Future<void> _loadCurrentCarAndHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final carId = prefs.getInt('current_car_id');
    if (carId == null) return;

    if (!mounted) return;
    setState(() {
      _currentCarId = carId;
    });

    try {
      final carsResp = await ApiClient.dio.get('/cars/');
      final cars = carsResp.data as List<dynamic>;
      final car =
          cars.cast<Map<String, dynamic>>().firstWhere((c) => c['id'] == carId);
      final brand = car['brand'] ?? '';
      final model = car['model'] ?? '';
      final year = car['year']?.toString() ?? '';
      if (!mounted) return;
      setState(() {
        _currentCarTitle = '$brand $model';
        _currentCarSubtitle = year;
      });
    } catch (_) {
      // игнорируем, если не нашли
    }

    try {
      final resp = await ApiClient.dio.get('/chat/history/$carId');
      final List<dynamic> history = resp.data as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(
            history.map(
              (m) => ChatMessage(
                m['content'] as String? ?? '',
                (m['role'] as String? ?? 'assistant') == 'user',
              ),
            ),
          );
      });
    } catch (_) {
      // если истории нет — просто пусто
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (_currentCarId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала выберите авто в разделе «Мои авто».'),
        ),
      );
      return;
    }

    setState(() {
      _messages.add(ChatMessage(text, true));
      _sending = true;
    });
    _controller.clear();

    try {
      final response = await ApiClient.dio.post(
        '/chat/vehicle',
        data: {
          'car_id': _currentCarId,
          'question': text,
        },
      );
      final data = response.data as Map<String, dynamic>? ?? {};
      final List<dynamic> history = data['messages'] as List<dynamic>? ?? [];

      setState(() {
        _messages
          ..clear()
          ..addAll(
            history.map(
              (m) => ChatMessage(
                m['content'] as String? ?? '',
                (m['role'] as String? ?? 'assistant') == 'user',
              ),
            ),
          );
      });
    } catch (e) {
      // при таймауте или 502 просто покажем ошибку
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось получить ответ от AI: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _goToCars() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (_) => const CarsScreen()),
        )
        .then((changed) {
      // Если на экране выбора авто реально сменили машину —
      // перезагрузим заголовок и историю чата.
      if (changed == true) {
        _loadCurrentCarAndHistory();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          children: [
            const Text('AI‑помощник'),
            if (_currentCarTitle != null)
              Text(
                _currentCarTitle!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _goToCars,
            child: const Text(
              'Сменить',
              style: TextStyle(color: AppColors.accentPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              reverse: true,
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (context, index) {
                if (_sending && index == 0) {
                  // "AI думает..."
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x661E3A3F),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.accentSoft),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                AppColors.accentPrimary,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'AI думает...',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final realIndex = _sending ? index - 1 : index;
                final msg =
                    _messages[_messages.length - 1 - realIndex]; // reverse
                final isUser = msg.isUser;
                final alignment =
                    isUser ? Alignment.centerRight : Alignment.centerLeft;

                return Align(
                  alignment: alignment,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.82,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xCC0F172A)
                          : const Color(0x661E3A3F),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft:
                            Radius.circular(isUser ? 20 : 6),
                        bottomRight:
                            Radius.circular(isUser ? 6 : 20),
                      ),
                      border: Border.all(
                        color: isUser
                            ? Colors.white.withOpacity(0.06)
                            : AppColors.accentSoft,
                      ),
                    ),
                    child: Text(
                      msg.text,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.only(left: 16, right: 16, bottom: 20, top: 8),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xB30F172A),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: AppColors.accentPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText:
                            'Спроси про обслуживание, ремонт или ошибки',
                        hintStyle: TextStyle(
                          color: AppColors.textMuted,
                        ),
                      ),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: _sending ? null : _sendMessage,
                    child: Container(
                      height: 40,
                      width: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accentPrimary,
                            AppColors.accentSecondary,
                          ],
                        ),
                      ),
                      child: Center(
                        child: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.black),
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.black,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Профиль
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = false;
  String? _error;
  List<dynamic> _cars = [];
  String? _phone;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await ApiClient.dio.get('/cars/');
      final userResp = await ApiClient.dio.get('/auth/me');
      setState(() {
        _cars = resp.data as List<dynamic>;
        _phone = userResp.data['phone']?.toString();
      });
    } catch (e) {
      setState(() => _error = 'Ошибка загрузки профиля: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await ApiClient.clearTokens();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
      (_) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Профиль'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_phone != null)
                Text(
                  'Телефон: +$_phone',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                ),
              const SizedBox(height: 16),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error),
                )
              else ...[
                const Text(
                  'Ваши автомобили',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                if (_cars.isEmpty)
                  const Text(
                    'Пока нет добавленных авто.',
                    style: TextStyle(color: AppColors.textMuted),
                  )
                else
                  ..._cars.map((c) {
                    final car = c as Map<String, dynamic>;
                    final brand = car['brand'] ?? '';
                    final model = car['model'] ?? '';
                    final year = car['year']?.toString() ?? '';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xB30F172A),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_car_filled_rounded,
                              color: AppColors.accentSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$brand $model ${year.isNotEmpty ? '($year)' : ''}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: AppColors.textPrimary,
                ),
                child: const Text('Выйти'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}