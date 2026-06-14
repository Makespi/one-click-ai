import 'dart:convert';
import 'dart:io' show File, HttpClient, Platform;

/// Manages license activation, token storage, and validation.
class ActivationService {
  static const _tokenFile = '.one-click-ai-activation';

  /// Get the device identifier (hardware-bound).
  static String get deviceId {
    final hostname = Platform.environment['COMPUTERNAME'] ??
        Platform.environment['HOSTNAME'] ??
        'unknown';
    // Simple device fingerprint
    return '${Platform.operatingSystem}-$hostname';
  }

  /// Path to the local activation data file.
  static String get _storagePath {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/tmp';
    final sep = Platform.isWindows ? '\\' : '/';
    return '$home$sep$_tokenFile';
  }

  /// Read saved activation data.
  static Future<ActivationData?> readActivation() async {
    try {
      final file = File(_storagePath);
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return ActivationData(
        token: json['token'] as String,
        secret: json['secret'] as String,
        expire: json['expire'] as int,
        expHuman: json['exp_human'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Save activation data to local storage.
  static Future<void> saveActivation(ActivationData data) async {
    final file = File(_storagePath);
    await file.writeAsString(jsonEncode({
      'token': data.token,
      'secret': data.secret,
      'expire': data.expire,
      'exp_human': data.expHuman,
    }));
  }

  /// Check if the activation is still valid.
  static bool isActivated(ActivationData? data) {
    if (data == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return data.expire > now;
  }

  /// Send activation code to the server.
  static Future<ActivateResult> activate(String code) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final uri = Uri.parse('https://api.panzi.help/issue.php');
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/x-www-form-urlencoded');

      final body = 'code=${Uri.encodeComponent(code)}&device=${Uri.encodeComponent(deviceId)}';
      request.write(body);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      final json = jsonDecode(responseBody) as Map<String, dynamic>;

      if (json['ok'] == true) {
        final data = ActivationData(
          token: json['token'] as String? ?? '',
          secret: json['secret'] as String? ?? '',
          expire: (json['expire'] as num?)?.toInt() ?? 0,
          expHuman: json['exp_human'] as String?,
        );
        await saveActivation(data);
        return ActivateResult(
          success: true,
          message: json['msg'] as String? ?? '激活成功',
          data: data,
        );
      } else {
        return ActivateResult(
          success: false,
          message: json['msg'] as String? ?? '激活失败',
        );
      }
    } catch (e) {
      return ActivateResult(
        success: false,
        message: '网络错误: ${e.toString()}',
      );
    }
  }
}

class ActivationData {
  final String token;
  final String secret;
  final int expire;
  final String? expHuman;

  const ActivationData({
    required this.token,
    required this.secret,
    required this.expire,
    this.expHuman,
  });

  bool get isValid {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return expire > now;
  }

  String get expireText {
    if (expHuman != null) return expHuman!;
    final dt = DateTime.fromMillisecondsSinceEpoch(expire * 1000);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class ActivateResult {
  final bool success;
  final String message;
  final ActivationData? data;

  const ActivateResult({
    required this.success,
    required this.message,
    this.data,
  });
}
