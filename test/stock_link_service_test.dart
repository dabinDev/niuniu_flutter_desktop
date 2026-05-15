import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:niuniu_kaipan/shared/application/app_preferences_provider.dart';
import 'package:niuniu_kaipan/shared/application/stock_link_service.dart';

void main() {
  const service = StockLinkService();

  test('stock link service rejects invalid stock code', () async {
    final result = await service.openStock(
      'abc',
      const AppPreferences(),
    );

    expect(result.success, isFalse);
    expect(result.message, contains('6 位股票代码'));
  });

  test('stock link service reports missing client configuration', () async {
    final result = await service.openStock(
      '000001',
      const AppPreferences(),
    );

    expect(result.success, isFalse);
    expect(result.message, contains('未配置联动客户端'));
  });

  test('stock link service uses STA powershell foreground activation for TDX',
      () async {
    if (!Platform.isWindows) {
      return;
    }

    final tempDir = await Directory.systemTemp.createTemp('tdx_link_test');
    addTearDown(() => tempDir.delete(recursive: true));
    final exe = File('${tempDir.path}${Platform.pathSeparator}TdxW.exe');
    await exe.writeAsBytes(const [0]);

    List<String>? capturedArguments;
    final service = StockLinkService(
      processRunner: (executable, arguments) async {
        expect(executable, 'powershell');
        capturedArguments = arguments;
        return ProcessResult(42, 0, '', '');
      },
    );

    final result = await service.testPreferredClient(
      '000001',
      AppPreferences(tdxPath: exe.path),
    );

    expect(result.success, isTrue);
    expect(capturedArguments, isNotNull);
    expect(capturedArguments, contains('-Sta'));
    expect(capturedArguments!.last, contains('SetForegroundWindow'));
    expect(capturedArguments!.last, contains(r'$clientKey = '));
    expect(capturedArguments!.last, contains('EnumWindows'));
    expect(capturedArguments!.last, contains('SwitchToThisWindow'));
    expect(capturedArguments!.last, contains('keybd_event'));
    expect(capturedArguments!.last, contains('mouse_event'));
    expect(capturedArguments!.last, contains('Focus-ClientContent'));
    expect(capturedArguments!.last, contains('SendKeys'));
    expect(capturedArguments!.last, contains('mpv'));
    expect(capturedArguments!.last, contains('000001'));
  });

  test('stock link service can drive the local TDX client when enabled',
      () async {
    if (!Platform.isWindows ||
        Platform.environment['NIUNIU_REAL_TDX_LINK_TEST'] != '1') {
      return;
    }

    final tdxPath =
        Platform.environment['NIUNIU_REAL_TDX_PATH'] ?? r'D:\mytdx\mpv.exe';
    final expectedTitle =
        Platform.environment['NIUNIU_REAL_TDX_EXPECTED'] ?? '平安银行';
    final exe = File(tdxPath);
    if (!await exe.exists()) {
      return;
    }

    final result = await service.testPreferredClient(
      '000001',
      AppPreferences(tdxPath: exe.path),
    );
    expect(result.success, isTrue, reason: result.message);

    await Future<void>.delayed(const Duration(seconds: 2));
    final title = await _readProcessTitle('mpv');
    expect(title, contains(expectedTitle));
  }, timeout: const Timeout(Duration(seconds: 30)));
}

Future<String> _readProcessTitle(String processName) async {
  final result = await Process.run(
    'powershell',
    [
      '-NoProfile',
      '-Command',
      "(Get-Process -Name '$processName' -ErrorAction SilentlyContinue | Select-Object -First 1).MainWindowTitle",
    ],
  );
  return result.stdout.toString().trim();
}
