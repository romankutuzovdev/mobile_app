import 'dart:async';
import 'dart:math' as math;

import 'package:dotted_border/dotted_border.dart';
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

/// Три точки-индикатор «печатает» (прыгают по очереди)
class TypingDotsIndicator extends StatefulWidget {
  const TypingDotsIndicator({
    super.key,
    this.color = LightThemeColors.accentOrange,
    this.size = 4.0,
  });
  final Color color;
  final double size;

  @override
  State<TypingDotsIndicator> createState() => _TypingDotsIndicatorState();
}

class _TypingDotsIndicatorState extends State<TypingDotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final phase = (_controller.value + i * 0.25) % 1.0;
              final bounce = math.sin(phase * math.pi);
              return Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                child: Transform.translate(
                  offset: Offset(0, -bounce * 4),
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
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

/// Цвета онбординга для чёрной темы (второй дизайн)
class DarkThemeOnboardingColors {
  static const background = Color(0xFF0A0A0B);
  static const backgroundGradientStart = Color(0xFF0D0D0E);
  static const backgroundGradientEnd = Color(0xFF1A1512);
  static const accentOrange = Color(0xFFE8A055);

  static const textPrimary = Color(0xFFF9FAFB);
  static const textSecondary = Color(0xFFB8B8B8);
  static const textMuted = Color(0xFF9CA3AF);

  static const buttonPrimaryBg = Color(0xFFE8A055);
  static const buttonPrimaryText = Color(0xFF1A1A1A);
  static const buttonSecondaryBg = Color(0xFF0D0D0E);
  static const buttonSecondaryBorder = Color(0xFF3D3D3D);
  static const buttonSecondaryText = Color(0xFFF9FAFB);

  static const dotActive = Color(0xFFF9FAFB);
  static const dotInactive = Color(0xFF525252);
  static const shadowColor = Color(0x40000000);
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
  /// Базовый URL бэкенда.
  /// flutter run --dart-define=API_URL=http://... — переопределить URL бекенда
  static String get _baseUrl {
    const url = String.fromEnvironment('API_URL', defaultValue: 'http://151.242.191.8:8888');
    return url;
  }

  static bool _isRefreshing = false;

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
          if (e.response?.statusCode != 401) return handler.next(e);
          if (e.requestOptions.path.contains('/auth/refresh')) {
            await clearTokens();
            return handler.next(e);
          }
          final refreshToken = await SharedPreferences.getInstance().then(
            (p) => p.getString('refresh_token'),
          );
          if (refreshToken == null || refreshToken.isEmpty) return handler.next(e);
          if (_isRefreshing) {
            await Future.delayed(const Duration(milliseconds: 500));
            final token = await SharedPreferences.getInstance().then(
              (p) => p.getString('access_token'),
            );
            if (token != null && token.isNotEmpty) {
              e.requestOptions.headers['Authorization'] = 'Bearer $token';
              return handler.resolve(await dio.fetch(e.requestOptions));
            }
            return handler.next(e);
          }
          _isRefreshing = true;
          try {
            final refreshDio = Dio(BaseOptions(baseUrl: _baseUrl));
            final response = await refreshDio.post(
              '/auth/refresh',
              data: {'refresh_token': refreshToken},
            );
            final data = response.data as Map<String, dynamic>?;
            final access = data?['access_token'] as String? ?? '';
            final refresh = data?['refresh_token'] as String? ?? '';
            if (access.isNotEmpty && refresh.isNotEmpty) {
              await saveTokens(access, refresh);
              e.requestOptions.headers['Authorization'] = 'Bearer $access';
              return handler.resolve(await dio.fetch(e.requestOptions));
            }
            await clearTokens();
          } catch (_) {
            await clearTokens();
          } finally {
            _isRefreshing = false;
          }
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

  /// Безопасное извлечение сообщения об ошибке из DioException.
  /// Всегда выводит конкретную ошибку от сервера, если есть.
  static String parseError(DioException e, String fallback) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        var detail = data['detail'];
        if (detail == null) detail = data['message'];
        if (detail != null) {
          if (detail is String && detail.isNotEmpty) return detail;
          if (detail is List && detail.isNotEmpty) {
            final first = detail[0];
            if (first is Map && first['msg'] != null) {
              return first['msg'].toString();
            }
            if (first is String) return first;
            return first.toString();
          }
          return detail.toString();
        }
      }
      if (data is String && data.isNotEmpty) return data;
      // Нет ответа от сервера — показываем причину (сеть, таймаут и т.д.)
      final statusCode = e.response?.statusCode;
      final type = e.type;
      final msg = e.message ?? '';
      if (type == DioExceptionType.connectionTimeout ||
          type == DioExceptionType.sendTimeout ||
          type == DioExceptionType.receiveTimeout) {
        return 'Таймаут соединения. Проверьте интернет. ${msg.isNotEmpty ? msg : ""}'.trim();
      }
      if (type == DioExceptionType.connectionError) {
        return 'Нет соединения с сервером. ${msg.isNotEmpty ? msg : "Проверьте интернет."}'.trim();
      }
      if (type == DioExceptionType.unknown && msg.isNotEmpty) {
        return '$fallback: $msg';
      }
      if (statusCode != null) return '$fallback (HTTP $statusCode)';
      return fallback;
    } catch (_) {
      return e.message?.isNotEmpty == true ? '${e.message}' : fallback;
    }
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

/// Провайдер темы (ночной режим)
class ThemeModeScope extends InheritedWidget {
  final bool darkMode;
  final void Function(bool) setDarkMode;

  const ThemeModeScope({
    super.key,
    required this.darkMode,
    required this.setDarkMode,
    required super.child,
  });

  static ThemeModeScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeModeScope>();

  @override
  bool updateShouldNotify(ThemeModeScope oldWidget) =>
      darkMode != oldWidget.darkMode;
}

/// Приложение
class AutoAssistantApp extends StatefulWidget {
  const AutoAssistantApp({super.key});

  @override
  State<AutoAssistantApp> createState() => _AutoAssistantAppState();
}

class _AutoAssistantAppState extends State<AutoAssistantApp> {
  bool _darkMode = false;
  bool _themeLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _themeLoaded = true;
    });
  }

  void _setDarkMode(bool value) async {
    setState(() => _darkMode = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
  }

  @override
  Widget build(BuildContext context) {
    if (!_themeLoaded) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return ThemeModeScope(
      darkMode: _darkMode,
      setDarkMode: _setDarkMode,
      child: MaterialApp(
        title: 'AI Auto Assistant',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
        home: const SplashScreen(),
      ),
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
    final isDark = ThemeModeScope.of(context)?.darkMode ?? false;
    final bg = isDark ? DarkThemeOnboardingColors.background : LightThemeColors.background;
    final accent = isDark ? DarkThemeOnboardingColors.accentOrange : LightThemeColors.accentOrange;
    final text = isDark ? DarkThemeOnboardingColors.textPrimary : LightThemeColors.textPrimary;
    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car_filled_rounded, color: accent, size: 72),
            const SizedBox(height: 16),
            Text(
              'AI Auto Assistant',
              style: TextStyle(
                color: text,
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
    final isDark = ThemeModeScope.of(context)?.darkMode ?? false;
    return Scaffold(
      backgroundColor: isDark ? DarkThemeOnboardingColors.background : LightThemeColors.background,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 180,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [
                            DarkThemeOnboardingColors.backgroundGradientStart,
                            DarkThemeOnboardingColors.backgroundGradientEnd,
                          ]
                        : [
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
                  children: [
                    _OnboardingPage1(isDark: isDark),
                    _OnboardingPage2(isDark: isDark),
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
                                ? (isDark ? DarkThemeOnboardingColors.dotActive : LightThemeColors.accentOrange)
                                : (isDark ? DarkThemeOnboardingColors.dotInactive : const Color(0xFFD1D5DB)),
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
                          backgroundColor: isDark ? DarkThemeOnboardingColors.buttonPrimaryBg : LightThemeColors.buttonPrimaryBg,
                          foregroundColor: isDark ? DarkThemeOnboardingColors.buttonPrimaryText : LightThemeColors.buttonPrimaryText,
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
                          foregroundColor: isDark ? DarkThemeOnboardingColors.buttonSecondaryText : LightThemeColors.buttonSecondaryText,
                          backgroundColor: isDark ? DarkThemeOnboardingColors.buttonSecondaryBg : LightThemeColors.buttonSecondaryBg,
                          side: BorderSide(
                            color: isDark ? DarkThemeOnboardingColors.buttonSecondaryBorder : LightThemeColors.buttonSecondaryBorder,
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
  const _OnboardingPage1({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? DarkThemeOnboardingColors.textPrimary : LightThemeColors.textPrimary;
    final textSecondary = isDark ? DarkThemeOnboardingColors.textSecondary : LightThemeColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI-помощник для вашего автомобиля',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'VIN, мануалы и умные ответы именно по вашему авто',
                  style: TextStyle(
                    color: textSecondary,
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
                      color: isDark
                          ? DarkThemeOnboardingColors.shadowColor
                          : Colors.black.withOpacity(0.12),
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
          Text(
            'AI анализирует данные по VIN и даёт точные рекомендации',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textPrimary,
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
  const _OnboardingPage2({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? DarkThemeOnboardingColors.textPrimary : LightThemeColors.textPrimary;
    final textSecondary = isDark ? DarkThemeOnboardingColors.textSecondary : LightThemeColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Определяет авто по VIN за секунды',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Добавьте авто по VIN и задавайте вопросы именно по вашему автомобилю',
                  style: TextStyle(
                    color: textSecondary,
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
                      color: isDark
                          ? DarkThemeOnboardingColors.shadowColor
                          : Colors.black.withOpacity(0.12),
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
          Text(
            'Добавьте авто по VIN — и получайте ответы именно по вашей модели',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textPrimary,
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
      final hasPasscode = await PasscodeService.hasPasscode();
      if (hasPasscode) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const PasscodeSetupScreen(allowBack: false),
          ),
          (_) => false,
        );
      }
    } on DioException catch (e) {
      setState(() {
        _error = ApiClient.parseError(e, 'Ошибка авторизации');
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
                      : Text(_step == 0 ? 'Продолжить' : 'Войти'),
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
        _error = ApiClient.parseError(e, 'Ошибка регистрации');
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
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.error, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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

/// Экран настройки код-пароля (шаг 4/4 регистрации или после входа)
class PasscodeSetupScreen extends StatefulWidget {
  const PasscodeSetupScreen({super.key, this.allowBack = true});

  final bool allowBack;

  @override
  State<PasscodeSetupScreen> createState() => _PasscodeSetupScreenState();
}

class _PasscodeSetupScreenState extends State<PasscodeSetupScreen> {
  final List<int> _digits = [];
  bool _showError = false;
  int _step = 0; // 0 = ввод, 1 = подтверждение
  String _firstPasscode = '';

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
    if (_step == 0) {
      setState(() {
        _firstPasscode = passcode;
        _digits.clear();
        _step = 1;
      });
    } else {
      if (passcode != _firstPasscode) {
        setState(() {
          _showError = true;
          _digits.clear();
          _firstPasscode = '';
          _step = 0;
        });
        return;
      }
      await PasscodeService.setPasscode(passcode);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightThemeColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.allowBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: LightThemeColors.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          widget.allowBack ? 'Регистрация' : 'Настройка код-пароля',
          style: const TextStyle(
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
                widget.allowBack ? '4/4' : '',
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
              Text(
                _step == 0 ? 'Введите код-пароль' : 'Повторите код-пароль',
                style: const TextStyle(
                  color: LightThemeColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _step == 0
                    ? 'Введите 4 цифры для разблокировки приложения'
                    : 'Введите код ещё раз для подтверждения',
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
              if (_showError) ...[
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'Коды не совпадают. Введите заново',
                    style: TextStyle(color: AppColors.error, fontSize: 14),
                  ),
                ),
              ],
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

/// Форматирует телефон для отображения: +998 93 201 49 79
String _formatPhoneForDisplay(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return phone;
  final buffer = StringBuffer('+');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (i == 3 || i == 5 || i == 7 || i == 9)) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Экран верификации телефона (шаг 2/4 регистрации)
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
  String _code = '';
  bool _loading = false;
  bool _verifying = false;
  String? _error;
  int _resendTimer = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer = 60;
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

  bool get _canProceed => _code.length == 4 && !_verifying && !_loading;

  void _onKeyPressed(String key) {
    if (key == 'backspace') {
      if (_code.isNotEmpty) {
        setState(() {
          _code = _code.substring(0, _code.length - 1);
          _error = null;
        });
      }
      return;
    }
    if (_code.length < 4 && RegExp(r'^\d$').hasMatch(key)) {
      setState(() {
        _code += key;
        _error = null;
      });
      if (_code.length == 4) {
        _verifyCode();
      }
    }
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
        data: {'phone': widget.phone},
      );

      if (!mounted) return;
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Код отправлен повторно'),
          backgroundColor: LightThemeColors.accentOrange,
        ),
      );
    } on DioException catch (e) {
      setState(() {
        _error = ApiClient.parseError(e, 'Ошибка отправки кода');
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
    if (_code.length < 4) return;

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      await ApiClient.dio.post(
        '/auth/verify-phone',
        data: {'phone': widget.phone, 'code': _code},
      );

      final loginResponse = await ApiClient.dio.post(
        '/auth/login',
        data: {'phone': widget.phone, 'password': widget.password},
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
        _error = ApiClient.parseError(e, 'Неверный код подтверждения');
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
    final formattedPhone = _formatPhoneForDisplay(widget.phone);
    final minutes = _resendTimer ~/ 60;
    final seconds = _resendTimer % 60;
    final timerStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

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
                '2/4',
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
        child: Column(
          children: [
            Expanded(child: _buildCodeContent(formattedPhone, timerStr)),
            // Кнопка внизу (как на главной)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _canProceed ? _verifyCode : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canProceed
                        ? LightThemeColors.buttonPrimaryBg
                        : const Color(0xFF9CA3AF),
                    foregroundColor: _canProceed
                        ? LightThemeColors.buttonPrimaryText
                        : Colors.white,
                    disabledBackgroundColor: const Color(0xFF9CA3AF),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: _verifying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Продолжить'),
                ),
              ),
            ),
            // Цифровая клавиатура
            Container(
              color: const Color(0xFFE5E7EB),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildKeypadRow(['1', '2', '3']),
                    const SizedBox(height: 12),
                    _buildKeypadRow(['4', '5', '6']),
                    const SizedBox(height: 12),
                    _buildKeypadRow(['7', '8', '9']),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildKeypadKey('+*#', false)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildKeypadKey('0', true)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildKeypadKey('⌫', true, isBackspace: true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeContent(String formattedPhone, String timerStr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Введите код из СМС',
            style: TextStyle(
              color: LightThemeColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Мы отправили код на номер: $formattedPhone',
            style: const TextStyle(
              color: LightThemeColors.textSecondary,
              fontSize: 14,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFF97373),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 12),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: List.generate(4, (i) {
                final hasDigit = i < _code.length;
                final isActive = i == _code.length;
                final underlineColor = hasDigit || isActive
                    ? LightThemeColors.accentOrange
                    : const Color(0xFFE0E0E0);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox(
                    width: 44,
                    child: Column(
                      children: [
                        Text(
                          hasDigit ? _code[i] : (isActive ? '|' : ''),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: LightThemeColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 2,
                          width: 44,
                          decoration: BoxDecoration(
                            color: underlineColor,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: GestureDetector(
              onTap: _resendTimer == 0 && !_loading ? _sendCode : null,
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(
                    color: LightThemeColors.textSecondary,
                    fontSize: 14,
                  ),
                  children: [
                    const TextSpan(text: 'Отправить код повторно: '),
                    TextSpan(
                      text: _resendTimer > 0 ? timerStr : 'готово',
                      style: const TextStyle(
                        color: LightThemeColors.accentOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: _buildKeypadKey(keys[i], true)),
        ],
      ],
    );
  }

  Widget _buildKeypadKey(String label, bool enabled, {bool isBackspace = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: enabled
              ? () => _onKeyPressed(isBackspace ? 'backspace' : label[0])
              : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isBackspace ? 20 : 22,
                fontWeight: FontWeight.w500,
                color: enabled ? LightThemeColors.textPrimary : LightThemeColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Основной shell с нижней навигацией (светлая тема)
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _chatKey = GlobalKey<_ChatScreenState>();

  void selectTab(int index) => setState(() => _index = index);

  Future<void> switchToCarChat(int carId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_car_id', carId);
    setState(() => _index = 2);
    // Даём Flutter время перестроить дерево, затем перезагружаем чат
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatKey.currentState?._loadCurrentCarAndHistory();
    });
  }

  late final _screens = [
    const CarsScreen(),
    const ManualsCatalogScreen(),
    ChatScreen(key: _chatKey),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isSelected = List.generate(4, (i) => i == _index);
    return Scaffold(
      backgroundColor: LightThemeColors.background,
      body: _screens[_index],
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.directions_car_outlined, Icons.directions_car_rounded, 'Автомобили', isSelected[0]),
                _buildNavItem(1, Icons.menu_book_outlined, Icons.menu_book_rounded, 'Мануалы', isSelected[1]),
                _buildNavItem(2, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Чат', isSelected[2]),
                _buildNavItem(3, Icons.person_outline_rounded, Icons.person_rounded, 'Профиль', isSelected[3]),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildNavItem(int index, IconData iconOutlined, IconData iconFilled, String label, bool selected) {
    final color = selected ? LightThemeColors.accentOrange : const Color(0xFF666666);
    return InkWell(
      onTap: () => setState(() => _index = index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? iconFilled : iconOutlined, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Сообщение в чате по мануалу
class _ManualChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  _ManualChatMessage({required this.role, required this.content});
}

/// Чат по мануалу (диалог вместо одиночного Q&A)
class ManualChatScreen extends StatefulWidget {
  final String brandName;
  final List<Map<String, dynamic>> cars;
  final String? brand;
  final String? model;
  final int? year;

  const ManualChatScreen({
    super.key,
    required this.brandName,
    this.cars = const [],
    this.brand,
    this.model,
    this.year,
  });

  @override
  State<ManualChatScreen> createState() => _ManualChatScreenState();
}

class _ManualChatScreenState extends State<ManualChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ManualChatMessage> _messages = [];
  bool _sending = false;
  final Set<int> _likedMessages = {};
  final Set<int> _copiedMessages = {};

  int? get _carId {
    for (final c in widget.cars) {
      final manuals = (c['manuals'] as List<dynamic>?) ?? [];
      if (manuals.isNotEmpty) return c['id'] as int?;
    }
    return null;
  }

  bool get _canAsk => _carId != null || (widget.brand != null && widget.model != null && widget.year != null);

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || !_canAsk || _sending) return;
    _controller.clear();
    setState(() {
      _messages.add(_ManualChatMessage(role: 'user', content: text));
      _sending = true;
    });
    _scrollToBottom();
    try {
      final data = <String, dynamic>{'question': text};
      if (_carId != null) {
        data['car_id'] = _carId;
      } else if (widget.brand != null && widget.model != null && widget.year != null) {
        data['brand'] = widget.brand;
        data['model'] = widget.model;
        data['year'] = widget.year;
      }
      final resp = await ApiClient.dio.post(
        '/manuals/chat/manual',
        data: data,
      );
      final respData = resp.data as Map<String, dynamic>;
      final answer = respData['answer']?.toString() ?? 'Нет ответа';
      if (mounted) {
        setState(() {
          _messages.add(_ManualChatMessage(role: 'assistant', content: answer));
          _sending = false;
        });
        _scrollToBottom();
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ManualChatMessage(role: 'assistant', content: ApiClient.parseError(e, 'Ошибка поиска')));
          _sending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ManualChatMessage(role: 'assistant', content: 'Ошибка: $e'));
          _sending = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1C1C1E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Мануал: ${widget.brandName}',
          style: const TextStyle(
            color: Color(0xFF1C1C1E),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE5E5EA), height: 1),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Column(
        children: [
          Expanded(
            child: _messages.isEmpty && !_sending
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Задайте вопрос по мануалу ${widget.brandName}.\nНапример: как заменить масло?',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    reverse: true,
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: _messages.length + (_sending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_sending && index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFFA82F),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Text('М',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(18),
                                    topRight: Radius.circular(18),
                                    bottomLeft: Radius.circular(4),
                                    bottomRight: Radius.circular(18),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const TypingDotsIndicator(
                                  color: Color(0xFFFFA82F),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final realIndex = _sending ? index - 1 : index;
                      final m = _messages[_messages.length - 1 - realIndex];
                      final isUser = m.role == 'user';

                      if (isUser) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.72,
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFA82F),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(18),
                                  topRight: Radius.circular(18),
                                  bottomLeft: Radius.circular(18),
                                  bottomRight: Radius.circular(4),
                                ),
                              ),
                              child: Text(
                                m.content,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      // Assistant message
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFA82F),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text('М',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width * 0.72,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF2F2F7),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(18),
                                        topRight: Radius.circular(18),
                                        bottomLeft: Radius.circular(4),
                                        bottomRight: Radius.circular(18),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      m.content,
                                      style: const TextStyle(
                                        color: Color(0xFF1C1C1E),
                                        fontSize: 15,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      _ActionBtn(
                                        icon: _copiedMessages.contains(realIndex)
                                            ? Icons.check_rounded
                                            : Icons.copy_outlined,
                                        active: _copiedMessages.contains(realIndex),
                                        onTap: () {
                                          Clipboard.setData(
                                              ClipboardData(text: m.content));
                                          setState(() {
                                            _copiedMessages.add(realIndex);
                                          });
                                          Future.delayed(
                                              const Duration(seconds: 2), () {
                                            if (mounted) {
                                              setState(() {
                                                _copiedMessages.remove(realIndex);
                                              });
                                            }
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      _ActionBtn(
                                        icon: _likedMessages.contains(realIndex)
                                            ? Icons.thumb_up_rounded
                                            : Icons.thumb_up_outlined,
                                        active: _likedMessages.contains(realIndex),
                                        onTap: () {
                                          setState(() {
                                            if (_likedMessages.contains(realIndex)) {
                                              _likedMessages.remove(realIndex);
                                            } else {
                                              _likedMessages.add(realIndex);
                                            }
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      _ActionBtn(
                                        icon: Icons.thumb_down_outlined,
                                        onTap: () {},
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 10,
              bottom: MediaQuery.of(context).padding.bottom + 10,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Icon(Icons.add,
                              color: Color(0xFF8E8E93), size: 22),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            minLines: 1,
                            maxLines: 5,
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _sendMessage(),
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Вопрос по мануалу...',
                              hintStyle: TextStyle(
                                color: Color(0xFFAEAEB2),
                                fontSize: 15,
                              ),
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 10),
                            ),
                            style: const TextStyle(
                              color: Color(0xFF1C1C1E),
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (!hasText)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Icon(Icons.mic_none_rounded,
                                color: Color(0xFF8E8E93), size: 22),
                          ),
                      ],
                    ),
                  ),
                ),
                if (hasText) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA82F),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                      Colors.white),
                                ),
                              )
                            : const Icon(
                                Icons.arrow_upward_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}

/// Каталог мануалов: марки авто, при наличии мануалов — открыть чат
class ManualsCatalogScreen extends StatefulWidget {
  const ManualsCatalogScreen({super.key});

  @override
  State<ManualsCatalogScreen> createState() => _ManualsCatalogScreenState();
}

class _ManualsCatalogScreenState extends State<ManualsCatalogScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _brands = [];
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadData();
  }

  Future<void> _loadUser() async {
    try {
      final resp = await ApiClient.dio.get('/auth/me');
      if (!mounted) return;
      final data = resp.data as Map<String, dynamic>?;
      final un = data?['username']?.toString();
      setState(() => _userName = (un != null && un.isNotEmpty) ? un : 'Профиль');
    } catch (_) {
      if (!mounted) return;
      setState(() => _userName = 'Профиль');
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalogData = await ApiClient.dio.get('/manuals/catalog/tree');
      if (!mounted) return;
      final brandsRaw = (catalogData.data as Map<String, dynamic>?)?['brands'] as List<dynamic>? ?? [];
      setState(() {
        _brands = brandsRaw.map((b) => Map<String, dynamic>.from(b as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка загрузки: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightThemeColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadUser();
            await _loadData();
          },
          color: LightThemeColors.accentOrange,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          final shell = context.findAncestorStateOfType<_MainShellState>();
                          shell?.selectTab(3);
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: LightThemeColors.accentOrange.withOpacity(0.3),
                              child: Text(
                                (_userName?.isNotEmpty == true ? _userName![0] : '?').toUpperCase(),
                                style: const TextStyle(color: LightThemeColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(_userName ?? 'Профиль', style: const TextStyle(color: LightThemeColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded, color: LightThemeColors.textSecondary, size: 22),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loading ? null : _loadData, color: LightThemeColors.textPrimary),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text('Каталог мануалов', style: const TextStyle(color: LightThemeColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: LightThemeColors.accentOrange)))
              else if (_error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      Text(_error!, style: const TextStyle(color: Color(0xFFF97373))),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _loadData, child: const Text('Повторить')),
                    ]),
                  ),
                )
              else if (_brands.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('Нет мануалов. Загрузите мануал для машины.', style: TextStyle(color: LightThemeColors.textSecondary))),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final brand = _brands[index] as Map<String, dynamic>;
                      final name = (brand['name'] ?? '').toString();
                      final models = (brand['models'] as List<dynamic>?) ?? [];
                      final modelCount = models.length;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => _ManualModelsScreen(brandName: name, models: models),
                          )),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: LightThemeColors.accentOrange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.directions_car_rounded, color: LightThemeColors.accentOrange, size: 24),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('$modelCount ${modelCount == 1 ? 'модель' : modelCount < 5 ? 'модели' : 'моделей'}'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                        ),
                      );
                    },
                    childCount: _brands.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Экран моделей внутри марки
class _ManualModelsScreen extends StatelessWidget {
  final String brandName;
  final List<dynamic> models;

  const _ManualModelsScreen({required this.brandName, required this.models});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightThemeColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context)),
        title: Text(brandName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: models.length,
        itemBuilder: (context, index) {
          final model = models[index] as Map<String, dynamic>;
          final modelName = (model['name'] ?? '').toString();
          final years = (model['years'] as List<dynamic>?) ?? [];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => _ManualYearsScreen(brandName: brandName, modelName: modelName, years: years),
              )),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: LightThemeColors.accentOrange.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.car_repair_rounded, color: LightThemeColors.accentOrange, size: 22),
              ),
              title: Text(modelName, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${years.length} ${years.length == 1 ? 'год' : years.length < 5 ? 'года' : 'лет'}'),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          );
        },
      ),
    );
  }
}

/// Экран годов внутри модели
class _ManualYearsScreen extends StatelessWidget {
  final String brandName;
  final String modelName;
  final List<dynamic> years;

  const _ManualYearsScreen({required this.brandName, required this.modelName, required this.years});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightThemeColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context)),
        title: Text('$brandName $modelName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: years.length,
        itemBuilder: (context, index) {
          final y = years[index] as Map<String, dynamic>;
          final year = (y['year'] ?? 0) as int;
          final manuals = (y['manuals'] as List<dynamic>?) ?? [];
          final title = '$brandName $modelName $year';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ManualChatScreen(
                  brandName: title,
                  brand: brandName,
                  model: modelName,
                  year: year,
                ),
              )),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: LightThemeColors.accentOrange.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.menu_book_rounded, color: LightThemeColors.accentOrange, size: 24),
              ),
              title: Text('$year год', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
              subtitle: Text('${manuals.length} ${manuals.length == 1 ? 'мануал' : manuals.length < 5 ? 'мануала' : 'мануалов'}'),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          );
        },
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
  String? _userName;

  Future<void> _loadUser() async {
    try {
      final resp = await ApiClient.dio.get('/auth/me');
      if (!mounted) return;
      final data = resp.data as Map<String, dynamic>?;
      final un = data?['username']?.toString();
      setState(() {
        _userName = (un != null && un.isNotEmpty) ? un : 'Профиль';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _userName = 'Профиль');
    }
  }

  Future<void> _loadCars() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiClient.dio.get('/cars/');
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getInt('current_car_id');
      setState(() {
        _cars = response.data as List<dynamic>;
        _currentCarId = savedId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка загрузки списка авто: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _setCurrentCar(int id, {bool closeScreen = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_car_id', id);
    if (!mounted) return;
    setState(() => _currentCarId = id);
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
    if (!mounted) return;
    setState(() => _currentCarId = id);
  }

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadCars();
  }

  void _openAddCar() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddCarByVinScreen()),
    ).then((_) => _loadCars());
  }

  Future<void> _deleteCar(int carId) async {
    try {
      await ApiClient.dio.delete('/cars/$carId');
      if (!mounted) return;
      setState(() => _cars.removeWhere((c) => (c as Map)['id'] == carId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightThemeColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadUser();
            await _loadCars();
          },
          child: CustomScrollView(
            slivers: [
              // Хедер: аватар + имя + колокольчик
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          final shell = context.findAncestorStateOfType<_MainShellState>();
                          shell?.selectTab(3);
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: LightThemeColors.accentOrange.withOpacity(0.3),
                              child: Text(
                                (_userName?.isNotEmpty == true ? _userName![0] : '?').toUpperCase(),
                                style: const TextStyle(
                                  color: LightThemeColors.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _userName ?? 'Профиль',
                              style: const TextStyle(
                                color: LightThemeColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded,
                                color: LightThemeColors.textSecondary, size: 22),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_outlined),
                            onPressed: () {},
                            color: LightThemeColors.textPrimary,
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF97373),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Заголовок
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    'Все автомобили',
                    style: const TextStyle(
                      color: LightThemeColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              // Карточка "Добавить автомобиль"
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GestureDetector(
                    onTap: _openAddCar,
                    child: DottedBorder(
                      borderType: BorderType.RRect,
                      radius: const Radius.circular(12),
                      strokeWidth: 1.5,
                      dashPattern: const [6, 3],
                      color: const Color(0xFFB0B0B0),
                      padding: EdgeInsets.zero,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                          color: Colors.transparent,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_rounded,
                                size: 40,
                                color: LightThemeColors.textSecondary,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'ДОБАВИТЬ АВТОМОБИЛЬ',
                                style: TextStyle(
                                  color: LightThemeColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, style: const TextStyle(color: Color(0xFFF97373))),
                  ),
                )
              else if (_cars.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Автомобилей пока нет.\nДобавьте через VIN.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: LightThemeColors.textSecondary),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
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
                        if (id == null) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildCarCard(car, id, brand, model, year, vin, createdAt),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Dismissible(
                            key: ValueKey<int>(id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE53935),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
                                  SizedBox(height: 6),
                                  Text(
                                    'Убрать из списка',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            onDismissed: (_) => _deleteCar(id),
                            child: _buildCarCard(car, id, brand, model, year, vin, createdAt),
                          ),
                        );
                      },
                      childCount: _cars.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarCard(
    Map<String, dynamic> car,
    int? id,
    String brand,
    String model,
    String year,
    String vin,
    DateTime? createdAt,
  ) {
    final title = [
      brand.toUpperCase(),
      model.toUpperCase(),
      if (year.isNotEmpty) '($year)',
    ].where((e) => e.isNotEmpty).join(' ');

    final hasManuals = car['has_manuals'] == true;
    final yearInt = int.tryParse(year) ?? 0;

    return InkWell(
      onTap: () {
        if (id != null) {
          _setCurrentCar(id, closeScreen: false);
          final shell = context.findAncestorStateOfType<_MainShellState>();
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => CarDetailsScreen(
                car: car,
                onAskAI: shell != null ? (carId) => shell.switchToCarChat(carId) : null,
              ),
              transitionsBuilder: (_, animation, __, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 350),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: LightThemeColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (vin.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'VIN: $vin',
                      style: const TextStyle(
                        color: LightThemeColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Добавлено: '
                      '${createdAt.day.toString().padLeft(2, '0')}.'
                      '${createdAt.month.toString().padLeft(2, '0')}.'
                      '${createdAt.year}',
                      style: const TextStyle(
                        color: LightThemeColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (hasManuals) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ManualChatScreen(
                              brandName: '$brand $model${year.isNotEmpty ? ' $year' : ''}',
                              brand: brand.isNotEmpty ? brand : null,
                              model: model.isNotEmpty ? model : null,
                              year: yearInt > 0 ? yearInt : null,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: LightThemeColors.accentOrange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: LightThemeColors.accentOrange, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.menu_book_rounded, size: 16, color: LightThemeColors.accentOrange),
                            const SizedBox(width: 6),
                            Text(
                              'Есть мануал',
                              style: TextStyle(
                                color: LightThemeColors.accentOrange,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: LightThemeColors.accentOrange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.directions_car_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
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
      if (!mounted) return;
      setState(() {
        _vinInfo = response.data as Map<String, dynamic>;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiClient.parseError(e, 'Не удалось определить авто');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
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
      if (!mounted) return;
      setState(() {
        _error = ApiClient.parseError(e, 'Не удалось добавить авто');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vinInfo = _vinInfo;
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
          'Добавить авто по VIN',
          style: TextStyle(
            color: LightThemeColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              TextField(
                controller: _vinController,
                maxLength: 17,
                style: const TextStyle(
                  color: LightThemeColors.textPrimary,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: 'Введите номер VIN',
                  hintStyle: TextStyle(
                    color: LightThemeColors.textMuted,
                    fontSize: 16,
                  ),
                  counterText: '',
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
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
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
                  style: TextStyle(
                    color: LightThemeColors.accentOrange,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFE53935), fontSize: 14),
                ),
              ],
              const SizedBox(height: 16),
              if (vinInfo != null)
                Builder(
                  builder: (context) {
                    final basic = vinInfo['basic_info'] as Map<String, dynamic>?;
                    final brand = basic?['brand']?.toString() ?? '';
                    final model = basic?['model']?.toString() ?? '';
                    final year = basic?['year'];
                    final vin = _vinController.text.trim();

                    final engine = vinInfo['engine'] as Map<String, dynamic>?;
                    final transmission = vinInfo['transmission'] as Map<String, dynamic>?;
                    final dimensions = vinInfo['dimensions'] as Map<String, dynamic>?;
                    final fuel = vinInfo['fuel'] as Map<String, dynamic>?;
                    final safety = vinInfo['safety'] as Map<String, dynamic>?;

                    final title = [
                      brand.toUpperCase(),
                      model.toUpperCase(),
                      if (year != null) '($year)',
                    ].where((e) => e.toString().isNotEmpty).join(' ');

                    Widget _specSection(String title, List<String> items) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: LightThemeColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (items.isEmpty)
                              const Text(
                                'Информация не найдена',
                                style: TextStyle(
                                  color: LightThemeColors.textMuted,
                                  fontSize: 13,
                                ),
                              )
                            else
                              ...items.map((s) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  s,
                                  style: const TextStyle(
                                    color: LightThemeColors.textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              )),
                          ],
                        ),
                      );
                    }

                    final engineItems = <String>[];
                    if (engine != null) {
                      if (engine['type'] != null) engineItems.add('Тип: ${engine['type']}');
                      if (engine['code'] != null) engineItems.add('Код: ${engine['code']}');
                      if (engine['volume_l'] != null) engineItems.add('Объём: ${engine['volume_l']} л');
                      if (engine['power_hp'] != null) engineItems.add('Мощность: ${engine['power_hp']} л.с.');
                    }

                    final transItems = <String>[];
                    if (transmission != null) {
                      if (transmission['type'] != null) transItems.add('Тип: ${transmission['type']}');
                      if (transmission['gears'] != null) transItems.add('Передачи: ${transmission['gears']}');
                      if (transmission['drive'] != null) transItems.add('Привод: ${transmission['drive']}');
                    }

                    final dimItems = <String>[];
                    if (dimensions != null && (dimensions['length_mm'] != null || dimensions['width_mm'] != null || dimensions['height_mm'] != null || dimensions['wheelbase_mm'] != null)) {
                      if (dimensions['length_mm'] != null) dimItems.add('Длина: ${dimensions['length_mm']} мм');
                      if (dimensions['width_mm'] != null) dimItems.add('Ширина: ${dimensions['width_mm']} мм');
                      if (dimensions['height_mm'] != null) dimItems.add('Высота: ${dimensions['height_mm']} мм');
                      if (dimensions['wheelbase_mm'] != null) dimItems.add('Колёсная база: ${dimensions['wheelbase_mm']} мм');
                    }

                    final fuelItems = <String>[];
                    if (fuel != null) {
                      if (fuel['fuel_type'] != null) fuelItems.add('Тип: ${fuel['fuel_type']}');
                    }

                    final safetyItems = <String>[];
                    if (safety != null) {
                      if (safety['abs'] != null) safetyItems.add('ABS: ${safety['abs']}');
                      final stab = safety['traction_control'] ?? safety['esp'];
                      if (stab != null) safetyItems.add('Стабилизация: $stab');
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 180,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8E8E8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.directions_car_rounded,
                              size: 72,
                              color: LightThemeColors.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title.isNotEmpty ? title : 'Автомобиль',
                          style: const TextStyle(
                            color: LightThemeColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _specSection('Двигатель', engineItems),
                        _specSection('Трансмиссия', transItems),
                        _specSection('Габариты', dimItems),
                        _specSection('Топливо', fuelItems),
                        _specSection('Безопасность', safetyItems),
                        const SizedBox(height: 12),
                        Text(
                          'VIN проверен: $vin',
                          style: const TextStyle(
                            color: LightThemeColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (vinInfo != null) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _loading ? null : _searchVin,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: LightThemeColors.accentOrange,
                          side: const BorderSide(color: LightThemeColors.accentOrange),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Проверить авто'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _addCar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LightThemeColors.accentOrange,
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
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Добавить авто'),
                      ),
                    ),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _searchVin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F2937),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF9CA3AF),
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
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Проверить авто'),
                      ),
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

/// Экран детальной информации об авто (демо, с мок‑данными)
class CarDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> car;
  final Future<void> Function(int carId)? onAskAI;
  const CarDetailsScreen({super.key, required this.car, this.onAskAI});

  @override
  State<CarDetailsScreen> createState() => _CarDetailsScreenState();
}

class _CarDetailsScreenState extends State<CarDetailsScreen> {
  Map<String, dynamic>? _apiData;
  final _manualQuestionController = TextEditingController();
  bool _manualSearching = false;
  String? _manualAnswer;
  String? _manualError;
  List<Map<String, dynamic>> _manualsForCar = [];
  List<Map<String, dynamic>> _orphanedManuals = [];
  bool _attachingManual = false;

  @override
  void initState() {
    super.initState();
    _loadCarInfo();
  }

  @override
  void dispose() {
    _manualQuestionController.dispose();
    super.dispose();
  }

  Future<void> _loadManualsForCar() async {
    final carId = widget.car['id'] as int?;
    if (carId == null) return;
    try {
      final resp = await ApiClient.dio.get('/manuals/', queryParameters: {'car_id': carId});
      final raw = resp.data;
      final list = raw is List
          ? List<Map<String, dynamic>>.from(
              (raw as List).map((e) => Map<String, dynamic>.from(e as Map)))
          : <Map<String, dynamic>>[];
      if (mounted) setState(() => _manualsForCar = list);
      if (list.isEmpty) _loadOrphanedManuals();
    } catch (_) {
      if (mounted) setState(() => _manualsForCar = []);
    }
  }

  Future<void> _loadOrphanedManuals() async {
    try {
      final resp = await ApiClient.dio.get('/manuals/', queryParameters: {'orphaned': true});
      final raw = resp.data;
      final list = raw is List
          ? List<Map<String, dynamic>>.from(
              (raw as List).map((e) => Map<String, dynamic>.from(e as Map)))
          : <Map<String, dynamic>>[];
      if (mounted) setState(() => _orphanedManuals = list);
    } catch (_) {
      if (mounted) setState(() => _orphanedManuals = []);
    }
  }

  Future<void> _attachOrphanedManual(String manualId) async {
    final carId = widget.car['id'] as int?;
    if (carId == null || _attachingManual) return;
    setState(() => _attachingManual = true);
    try {
      await ApiClient.dio.patch(
        '/manuals/$manualId/car',
        data: {'car_id': carId},
      );
      if (mounted) {
        setState(() {
          _attachingManual = false;
          _orphanedManuals = [];
        });
        _loadManualsForCar();
      }
    } catch (e) {
      if (mounted) setState(() => _attachingManual = false);
    }
  }

  Future<void> _searchManual() async {
    final question = _manualQuestionController.text.trim();
    if (question.isEmpty) return;
    final carId = widget.car['id'] as int?;
    if (carId == null) return;
    setState(() {
      _manualSearching = true;
      _manualAnswer = null;
      _manualError = null;
    });
    try {
      final resp = await ApiClient.dio.post(
        '/manuals/chat/manual',
        data: {'car_id': carId, 'question': question},
      );
      final data = resp.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _manualAnswer = data['answer']?.toString();
          _manualSearching = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _manualError = ApiClient.parseError(e, 'Ошибка поиска по мануалу');
          _manualSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _manualError = 'Ошибка: $e';
          _manualSearching = false;
        });
      }
    }
  }

  Future<void> _loadCarInfo() async {
    try {
      final id = widget.car['id'];
      _loadManualsForCar();
      final resp = await ApiClient.dio.get('/cars/$id');
      final data = resp.data as Map<String, dynamic>;
      final carInfo = data['car_info'] as Map<String, dynamic>?;
      if (carInfo != null && carInfo['api_data'] != null) {
        if (!mounted) return;
        setState(() => _apiData = carInfo['api_data'] as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final car = widget.car;
    final brand = (car['brand']?.toString() ?? '').toString();
    final model = (car['model']?.toString() ?? '').toString();
    final year = (car['year']?.toString() ?? '').toString();
    final vin = (car['vin']?.toString() ?? '').toString();
    final createdAtStr = widget.car['created_at']?.toString();

    DateTime? createdAt;
    if (createdAtStr != null) {
      try { createdAt = DateTime.parse(createdAtStr); } catch (_) {}
    }
    final createdAtText = createdAt != null
        ? '${createdAt.day.toString().padLeft(2, '0')}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.year}'
        : 'дата не указана';

    // Данные из api_data или дефолтные
    final oil = _apiData?['oil_type']?.toString() ?? '5W‑30, Full Synthetic';
    final oilVol = _apiData != null ? 'объём ~${_apiData!['oil_volume_l']} л' : 'объём ~4–5 л';
    final serviceKm = _apiData?['service_interval_km']?.toString() ?? '10 000';
    final engine = _apiData?['engine']?.toString();
    final hp = _apiData?['engine_power_hp']?.toString();
    final transmission = _apiData?['transmission']?.toString();
    final drive = _apiData?['drive_type']?.toString();
    final tires = _apiData?['tires']?.toString();
    final commonProblems = (_apiData?['common_problems'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ?? [
      'Подтекание масла по прокладке клапанной крышки.',
      'Износ стоек стабилизатора и втулок подвески.',
      'Шумы от подшипников ступиц на высоком пробеге.',
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF1C1C1E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Детали автомобиля',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E)),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE5E5EA)),
        ),
      ),
      body: Column(
        children: [
          // Фото + белый «захлёст» через Stack
          SizedBox(
            height: 250,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF3A3A3C), Color(0xFF8B6914)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.directions_car_filled_rounded,
                          size: 110, color: Colors.white24),
                    ),
                  ),
                ),
                // Белый «колпачок» с закруглёнными верхними углами поверх фото
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Скроллируемый белый контент
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Точки пагинации
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) => Container(
                          width: i == 0 ? 16 : 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: i == 0
                                ? const Color(0xFF1C1C1E)
                                : const Color(0xFFD1D1D6),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        )),
                      ),
                    ),

                    // Заголовок
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${brand.toUpperCase()} ${model.toUpperCase()}${year.isNotEmpty ? ' ($year)' : ''}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1C1C1E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (vin.isNotEmpty)
                            Text('VIN: $vin',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                          const SizedBox(height: 2),
                          Text('Добавлено: $createdAtText',
                              style: const TextStyle(fontSize: 12, color: Color(0xFFAEAEB2))),
                        ],
                      ),
                    ),

                    const _Divider(),

                    // ТО и обслуживание
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle('ТО и обслуживание'),
                          const SizedBox(height: 10),
                          _BulletLine('Замена масла каждые $serviceKm км или 1 год.'),
                          const _BulletLine('ТО‑1: масло, фильтр, осмотр подвески и тормозов.'),
                          const _BulletLine('ТО‑2: добавляется замена свечей и салонного фильтра.'),
                        ],
                      ),
                    ),

                    const _Divider(),

                    // Расходники
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle('Расходники'),
                          const SizedBox(height: 10),
                          _KeyValueRow(label: 'Масло двигателя', value: '$oil, $oilVol'),
                          const _KeyValueRow(label: 'Фильтр масляный', value: 'Оригинал / аналог по VIN'),
                          const _KeyValueRow(label: 'Фильтр воздушный', value: 'Замена каждые 20–30 тыс. км'),
                          const _KeyValueRow(label: 'Тормозные колодки', value: 'Ресурс 30–50 тыс. км'),
                          if (tires != null)
                            _KeyValueRow(label: 'Шины', value: tires),
                        ],
                      ),
                    ),

                    if (engine != null || hp != null || transmission != null) ...[
                      const _Divider(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle('Характеристики'),
                            const SizedBox(height: 10),
                            if (engine != null) _KeyValueRow(label: 'Двигатель', value: engine),
                            if (hp != null) _KeyValueRow(label: 'Мощность', value: '$hp л.с.'),
                            if (transmission != null) _KeyValueRow(label: 'КПП', value: transmission),
                            if (drive != null) _KeyValueRow(label: 'Привод', value: drive),
                          ],
                        ),
                      ),
                    ],

                    const _Divider(),

                    // Типичные проблемы
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle('Типичные проблемы'),
                          const SizedBox(height: 10),
                          ...commonProblems.map((p) => _BulletLine(p)),
                        ],
                      ),
                    ),

                    const _Divider(),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle('Поиск по мануалу'),
                          const SizedBox(height: 8),
                          if (_manualsForCar.isEmpty && _orphanedManuals.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFFB74D)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Найден мануал без привязки (возможно, после удаления авто):',
                                    style: TextStyle(
                                      color: Color(0xFFE65100),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ..._orphanedManuals.map((m) {
                                    final id = m['id']?.toString();
                                    final title = m['title']?.toString() ?? 'Мануал';
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: const TextStyle(fontSize: 13),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: _attachingManual || id == null
                                                ? null
                                                : () => _attachOrphanedManual(id),
                                            child: _attachingManual
                                                ? const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child: CircularProgressIndicator(strokeWidth: 2),
                                                  )
                                                : const Text('Привязать'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 4),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Text(
                            _manualsForCar.isEmpty
                                ? 'Загрузите мануал (PDF/DOCX) для этого авто через API, затем задайте вопрос.'
                                : 'Найдено мануалов: ${_manualsForCar.length}. Задайте вопрос:',
                            style: const TextStyle(
                              color: Color(0xFF6B6B6B),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _manualQuestionController,
                            decoration: InputDecoration(
                              hintText: 'Например: как заменить масло?',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            maxLines: 2,
                            onSubmitted: (_) => _searchManual(),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _manualSearching ? null : _searchManual,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1C1C1E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _manualSearching
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text('Искать в мануале'),
                            ),
                          ),
                          if (_manualError != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _manualError!,
                              style: const TextStyle(color: Color(0xFFE53935), fontSize: 14),
                            ),
                          ],
                          if (_manualAnswer != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE0E0E0)),
                              ),
                              child: Text(
                                _manualAnswer!,
                                style: const TextStyle(
                                  color: Color(0xFF1C1C1E),
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),

          // Кнопка внизу
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            child: GestureDetector(
              onTap: () async {
                final carId = widget.car['id'] as int?;
                if (!mounted) return;
                Navigator.of(context).pop();
                if (widget.onAskAI != null && carId != null) {
                  await widget.onAskAI!(carId);
                }
              },
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    'Спросить AI помощника',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1C1C1E),
    ),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
    child: Divider(height: 32, color: Color(0xFFE5E5EA)),
  );
}

class _BulletLine extends StatelessWidget {
  final String text;
  const _BulletLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFF1C1C1E), fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF1C1C1E), fontSize: 14, height: 1.4),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6B6B6B), fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF1C1C1E), fontSize: 14),
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
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  final List<ChatMessage> _messages = [];
  List<Map<String, dynamic>> _cars = [];
  bool _sending = false;
  int? _currentCarId;
  String? _currentCarTitle;
  String? _currentCarSubtitle;
  final Set<int> _likedMessages = {};
  final Set<int> _copiedMessages = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentCarAndHistory();
  }

  Future<void> _loadCurrentCarAndHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final carId = prefs.getInt('current_car_id');

    try {
      final carsResp = await ApiClient.dio.get('/cars/');
      final cars = (carsResp.data as List<dynamic>).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() => _cars = cars);

      final selectedId = carId ?? (cars.isNotEmpty ? cars.first['id'] as int : null);
      if (selectedId == null) return;

      final car = cars.firstWhere((c) => c['id'] == selectedId, orElse: () => cars.first);
      setState(() {
        _currentCarId = car['id'] as int;
        _currentCarTitle = '${car['brand']} ${car['model']}';
        _currentCarSubtitle = car['year']?.toString() ?? '';
      });
      await prefs.setInt('current_car_id', _currentCarId!);
    } catch (_) {
      if (carId == null) return;
      if (!mounted) return;
      setState(() => _currentCarId = carId);
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

  Future<void> _switchCar(Map<String, dynamic> car) async {
    final prefs = await SharedPreferences.getInstance();
    final id = car['id'] as int;
    await prefs.setInt('current_car_id', id);
    if (!mounted) return;
    setState(() {
      _currentCarId = id;
      _currentCarTitle = '${car['brand']} ${car['model']}';
      _currentCarSubtitle = car['year']?.toString() ?? '';
      _messages.clear();
      _likedMessages.clear();
      _copiedMessages.clear();
    });
    _scaffoldKey.currentState?.closeDrawer();
    try {
      final resp = await ApiClient.dio.get('/chat/history/$id');
      final List<dynamic> history = resp.data as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(history.map((m) => ChatMessage(
                m['content'] as String? ?? '',
                (m['role'] as String? ?? 'assistant') == 'user',
              )));
      });
    } catch (_) {}
  }

  void _goToCars() {
    _scaffoldKey.currentState?.closeDrawer();
    // Переключаем на таб "Автомобили" (индекс 0) без скрытия нижнего меню
    final shell = context.findAncestorStateOfType<_MainShellState>();
    if (shell != null) {
      shell.selectTab(0);
    } else {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const CarsScreen()))
          .then((changed) {
        if (changed == true) _loadCurrentCarAndHistory();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.trim().isNotEmpty;
    final searchQuery = _searchController.text.toLowerCase();
    final filteredCars = _cars.where((c) {
      final name = '${c['brand']} ${c['model']}'.toLowerCase();
      return searchQuery.isEmpty || name.contains(searchQuery);
    }).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawerEdgeDragWidth: MediaQuery.of(context).size.width * 0.3,
      drawer: Drawer(
        backgroundColor: const Color(0xFFF2F2F7),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.search,
                                color: Color(0xFFAEAEB2), size: 18),
                            hintText: 'Поиск',
                            hintStyle: TextStyle(
                                color: Color(0xFFAEAEB2), fontSize: 15),
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.more_horiz,
                        color: Color(0xFF1C1C1E), size: 22),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'История',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: filteredCars.length,
                  itemBuilder: (context, i) {
                    final car = filteredCars[i];
                    final isActive = car['id'] == _currentCarId;
                    final name = '${car['brand']} ${car['model']}';
                    final year = car['year']?.toString() ?? '';
                    return GestureDetector(
                      onTap: () => _switchCar(car),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$name $year',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: const Color(0xFF1C1C1E),
                                  fontWeight: isActive
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isActive)
                              const Icon(Icons.check,
                                  color: Color(0xFFFFA82F), size: 16),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                child: GestureDetector(
                  onTap: () {
                    _scaffoldKey.currentState?.closeDrawer();
                    _goToCars();
                  },
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFA82F),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text(
                        'Создать новый чат',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text(
              'AI-помощник',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E),
              ),
            ),
            if (_currentCarTitle != null) ...[
              const SizedBox(width: 4),
              Text(
                '/ $_currentCarTitle${_currentCarSubtitle != null ? ' $_currentCarSubtitle' : ''}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF8E8E93),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            onPressed: _goToCars,
            icon: const Icon(Icons.add, color: Color(0xFF1C1C1E)),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz, color: Color(0xFF1C1C1E)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE5E5EA), height: 1),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              reverse: true,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (context, index) {
                if (_sending && index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFA82F),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text('AI',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(18),
                              topRight: Radius.circular(18),
                              bottomLeft: Radius.circular(4),
                              bottomRight: Radius.circular(18),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const TypingDotsIndicator(
                            color: Color(0xFFFFA82F),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final realIndex = _sending ? index - 1 : index;
                final msg = _messages[_messages.length - 1 - realIndex];
                final isUser = msg.isUser;

                if (isUser) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.72,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFA82F),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(18),
                            topRight: Radius.circular(18),
                            bottomLeft: Radius.circular(18),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                        child: Text(
                          msg.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                // AI message
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFA82F),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text('AI',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.72,
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F2F7),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(18),
                                  topRight: Radius.circular(18),
                                  bottomLeft: Radius.circular(4),
                                  bottomRight: Radius.circular(18),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                msg.text,
                                style: const TextStyle(
                                  color: Color(0xFF1C1C1E),
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _ActionBtn(
                                  icon: _copiedMessages.contains(realIndex)
                                      ? Icons.check_rounded
                                      : Icons.copy_outlined,
                                  active: _copiedMessages.contains(realIndex),
                                  onTap: () {
                                    Clipboard.setData(
                                        ClipboardData(text: msg.text));
                                    setState(() {
                                      _copiedMessages.add(realIndex);
                                    });
                                    Future.delayed(
                                        const Duration(seconds: 2), () {
                                      if (mounted) {
                                        setState(() {
                                          _copiedMessages.remove(realIndex);
                                        });
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(width: 4),
                                _ActionBtn(
                                  icon: _likedMessages.contains(realIndex)
                                      ? Icons.thumb_up_rounded
                                      : Icons.thumb_up_outlined,
                                  active: _likedMessages.contains(realIndex),
                                  onTap: () {
                                    setState(() {
                                      if (_likedMessages.contains(realIndex)) {
                                        _likedMessages.remove(realIndex);
                                      } else {
                                        _likedMessages.add(realIndex);
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(width: 4),
                                _ActionBtn(
                                  icon: Icons.thumb_down_outlined,
                                  onTap: () {},
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 10,
              bottom: MediaQuery.of(context).padding.bottom + 10,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Пилл с полем ввода
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Icon(Icons.add,
                              color: Color(0xFF8E8E93), size: 22),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            minLines: 1,
                            maxLines: 5,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Напишите AI-помощник',
                              hintStyle: TextStyle(
                                color: Color(0xFFAEAEB2),
                                fontSize: 15,
                              ),
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 10),
                            ),
                            style: const TextStyle(
                              color: Color(0xFF1C1C1E),
                              fontSize: 15,
                            ),
                          ),
                        ),
                        // Микрофон — только когда текста нет
                        if (!hasText)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Icon(Icons.mic_none_rounded,
                                color: Color(0xFF8E8E93), size: 22),
                          ),
                      ],
                    ),
                  ),
                ),
                // Оранжевая кнопка — только когда есть текст
                if (hasText) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA82F),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                      Colors.white),
                                ),
                              )
                            : const Icon(
                                Icons.arrow_upward_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  const _ActionBtn({required this.icon, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFA82F) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 15,
          color: active ? Colors.white : const Color(0xFF8E8E93),
        ),
      ),
    );
  }
}

/// Настройки профиля — смена пароля
class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _error = null;
    if (!_formKey.currentState!.validate()) return;
    final current = _currentController.text;
    final newPass = _newController.text;
    setState(() => _loading = true);
    try {
      await ApiClient.dio.patch(
        '/auth/change-password',
        data: {
          'current_password': current,
          'new_password': newPass,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароль успешно изменён')),
      );
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.response?.data is Map
            ? (e.response!.data['detail'] as String? ?? 'Ошибка смены пароля')
            : 'Ошибка смены пароля';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Ошибка смены пароля';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.background : Colors.white;
    final textColor = isDark ? AppColors.textPrimary : const Color(0xFF1C1C1E);
    final hintColor = isDark ? AppColors.textMuted : const Color(0xFF8E8E93);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Настройки профиля',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textColor),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Изменить пароль',
              style: TextStyle(fontSize: 15, color: hintColor, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _currentController,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                labelText: 'Текущий пароль',
                hintText: 'Введите текущий пароль',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureCurrent ? Icons.visibility_off : Icons.visibility,
                    color: hintColor,
                  ),
                  onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Введите текущий пароль' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newController,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'Новый пароль',
                hintText: 'Минимум 8 символов',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNew ? Icons.visibility_off : Icons.visibility,
                    color: hintColor,
                  ),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Введите новый пароль';
                if (v.length < 8) return 'Минимум 8 символов';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Подтверждение',
                hintText: 'Повторите новый пароль',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    color: hintColor,
                  ),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) {
                if (v != _newController.text) return 'Пароли не совпадают';
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Сохранить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// О приложении
class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.background : Colors.white;
    final textColor = isDark ? AppColors.textPrimary : const Color(0xFF1C1C1E);
    final mutedColor = isDark ? AppColors.textSecondary : const Color(0xFF6B6B6B);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'О приложении',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textColor),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.directions_car_filled_rounded,
                  size: 72,
                  color: isDark ? AppColors.accentPrimary : LightThemeColors.accentOrange,
                ),
                const SizedBox(height: 16),
                Text(
                  'AI Auto Assistant',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Версия 1.0.0',
                  style: TextStyle(fontSize: 14, color: mutedColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'AI Auto Assistant — умный помощник для владельцев автомобилей. Получайте ответы на вопросы по вашим мануалам, управляйте списком авто и многое другое.',
            style: TextStyle(fontSize: 15, color: mutedColor, height: 1.5),
            textAlign: TextAlign.center,
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
  String? _phone;
  String? _username;
  bool _notificationsOn = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() => _notificationsOn = prefs.getBool('notifications') ?? true);
      final userResp = await ApiClient.dio.get('/auth/me');
      final data = userResp.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _phone = data['phone']?.toString();
        _username = data['username']?.toString();
      });
    } catch (_) {}
  }

  Future<void> _toggleNotifications(bool v) async {
    setState(() => _notificationsOn = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', v);
  }

  Future<void> _logout() async {
    await ApiClient.clearTokens();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
      (_) => false,
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: const Text('Это действие нельзя отменить. Все данные будут удалены.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) _logout();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _username ?? _phone ?? '—';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.background : Colors.white;
    final textColor = isDark ? AppColors.textPrimary : const Color(0xFF1C1C1E);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 18),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Профиль',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textColor),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: textColor, size: 20),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Avatar + name
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E5EA),
                    border: Border.all(color: bg, width: 3),
                  ),
                  child: Icon(Icons.person, size: 44, color: isDark ? AppColors.textMuted : const Color(0xFFAEAEB2)),
                ),
                const SizedBox(height: 10),
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.accentSoft : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, color: isDark ? AppColors.accentPrimary : const Color(0xFFFFA82F), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Подписка PLUS',
                        style: TextStyle(
                          color: isDark ? AppColors.accentPrimary : const Color(0xFFFFA82F),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Основное
          _SectionLabel('Основное'),
          _SettingsCard(children: [
            _SettingsRow(
              icon: Icons.person_outline,
              label: 'Настройки профиля',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
              ),
            ),
            _SettingsDivider(),
            _SettingsRow(
              icon: Icons.notifications_none_rounded,
              label: 'Уведомление',
              trailing: Switch(
                value: _notificationsOn,
                onChanged: _toggleNotifications,
                activeColor: const Color(0xFFFFA82F),
              ),
            ),
            _SettingsDivider(),
            _SettingsRow(
              icon: Icons.nightlight_round_outlined,
              label: 'Ночной режим',
              trailing: Switch(
                value: ThemeModeScope.of(context)?.darkMode ?? false,
                onChanged: (v) => ThemeModeScope.of(context)?.setDarkMode(v),
                activeColor: const Color(0xFFFFA82F),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Premium banner
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: isDark ? AppColors.accentSoft : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.accentPrimary.withOpacity(0.3) : const Color(0xFFFFD180), width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Получите премиум',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Воспользуйтесь всеми\nвозможностями приложения',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.textSecondary : const Color(0xFF6B6B6B),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  child: Container(
                    width: 110,
                    color: isDark ? AppColors.accentPrimary.withOpacity(0.2) : const Color(0xFFFFE0B2),
                    child: Icon(
                      Icons.directions_car_filled_rounded,
                      size: 64,
                      color: isDark ? AppColors.accentPrimary : const Color(0xFFFFA82F),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Другое
          _SectionLabel('Другое'),
          _SettingsCard(children: [
            _SettingsRow(
              icon: Icons.info_outline_rounded,
              label: 'О приложении',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutAppScreen()),
              ),
            ),
            _SettingsDivider(),
            _SettingsRow(
              icon: Icons.logout_rounded,
              label: 'Выйти с аккаунта',
              labelColor: const Color(0xFFFF3B30),
              iconColor: const Color(0xFFFF3B30),
              onTap: _logout,
            ),
            _SettingsDivider(),
            _SettingsRow(
              icon: Icons.delete_outline_rounded,
              label: 'Удалить аккаунт',
              labelColor: const Color(0xFFFF3B30),
              iconColor: const Color(0xFFFF3B30),
              onTap: _deleteAccount,
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.textSecondary : const Color(0xFF6B6B6B),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      indent: 48,
      color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E5EA),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? labelColor;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.labelColor,
    this.iconColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultLabel = labelColor ?? (isDark ? AppColors.textPrimary : const Color(0xFF1C1C1E));
    final defaultIcon = iconColor ?? (isDark ? AppColors.textSecondary : const Color(0xFF6B6B6B));
    final defaultChevron = isDark ? AppColors.textMuted : const Color(0xFFAEAEB2);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? defaultIcon),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: labelColor ?? defaultLabel,
                ),
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right, color: defaultChevron, size: 20),
          ],
        ),
      ),
    );
  }
}