import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_preferences_provider.dart';

typedef StockLinkProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

class StockLinkResult {
  const StockLinkResult({
    required this.success,
    required this.message,
    this.client,
  });

  final bool success;
  final String message;
  final StockLinkClient? client;
}

class StockLinkService {
  const StockLinkService({
    StockLinkProcessRunner? processRunner,
  }) : _processRunner = processRunner;

  final StockLinkProcessRunner? _processRunner;

  static DateTime? _lastOpenedAt;
  static String? _lastOpenedCode;

  Future<StockLinkResult> openStock(
    String code,
    AppPreferences preferences,
  ) async {
    final normalizedCode = _normalizeCode(code);
    if (normalizedCode == null) {
      return const StockLinkResult(
        success: false,
        message: '请输入 6 位股票代码。',
      );
    }

    if (!Platform.isWindows) {
      return const StockLinkResult(
        success: false,
        message: '股票联动目前只支持 Windows 桌面端。',
      );
    }

    if (_isDebounced(normalizedCode)) {
      return const StockLinkResult(
        success: true,
        message: '已忽略重复联动请求。',
      );
    }

    final candidates = <StockLinkClient>[
      preferences.stockLinkClient,
      ...StockLinkClient.values.where(
        (client) => client != preferences.stockLinkClient,
      ),
    ].where((client) => _pathForClient(preferences, client).isNotEmpty).toList(
          growable: false,
        );

    if (candidates.isEmpty) {
      return const StockLinkResult(
        success: false,
        message: '未配置联动客户端，请先在设置中填写通达信或同花顺路径。',
      );
    }

    StockLinkResult? lastFailure;
    for (final client in candidates) {
      final result = await _openInClient(
        client,
        normalizedCode,
        preferences,
      );
      if (result.success) {
        _remember(normalizedCode);
        return result;
      }
      lastFailure = result;
    }

    return lastFailure ??
        const StockLinkResult(
          success: false,
          message: '联动失败，请检查客户端路径和桌面环境。',
        );
  }

  Future<StockLinkResult> testPreferredClient(
    String code,
    AppPreferences preferences,
  ) async {
    final normalizedCode = _normalizeCode(code);
    if (normalizedCode == null) {
      return const StockLinkResult(
        success: false,
        message: '请输入 6 位股票代码。',
      );
    }

    if (!Platform.isWindows) {
      return const StockLinkResult(
        success: false,
        message: '股票联动目前只支持 Windows 桌面端。',
      );
    }

    final result = await _openInClient(
      preferences.stockLinkClient,
      normalizedCode,
      preferences,
    );
    if (result.success) {
      _remember(normalizedCode);
    }
    return result;
  }

  Future<StockLinkResult> _openInClient(
    StockLinkClient client,
    String code,
    AppPreferences preferences,
  ) async {
    final executablePath = _pathForClient(preferences, client);
    if (executablePath.isEmpty) {
      return StockLinkResult(
        success: false,
        message: '${client.label} 路径未配置。',
        client: client,
      );
    }

    final executable = File(executablePath);
    if (!await executable.exists()) {
      return StockLinkResult(
        success: false,
        message: '${client.label} 路径不存在，请重新检查设置。',
        client: client,
      );
    }

    final script = _buildWindowsActivationScript(
      executablePath: executablePath,
      code: code,
      client: client,
    );

    try {
      final processRunner = _processRunner ?? Process.run;
      final result = await processRunner(
        'powershell',
        [
          '-NoProfile',
          '-Sta',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          script,
        ],
      );

      if (result.exitCode == 0) {
        return StockLinkResult(
          success: true,
          message: '已在 ${client.label} 中打开 $code。',
          client: client,
        );
      }

      final output = [
        if (result.stdout.toString().trim().isNotEmpty)
          result.stdout.toString().trim(),
        if (result.stderr.toString().trim().isNotEmpty)
          result.stderr.toString().trim(),
      ].join('\n');

      return StockLinkResult(
        success: false,
        message: output.isEmpty
            ? '${client.label} 联动失败，请检查客户端是否可正常启动。'
            : '${client.label} 联动失败：$output',
        client: client,
      );
    } catch (error) {
      return StockLinkResult(
        success: false,
        message: '${client.label} 联动失败：$error',
        client: client,
      );
    }
  }

  String _pathForClient(
    AppPreferences preferences,
    StockLinkClient client,
  ) {
    return switch (client) {
      StockLinkClient.tdx => preferences.tdxPath.trim(),
      StockLinkClient.ths => preferences.thsPath.trim(),
    };
  }

  bool _isDebounced(String code) {
    final lastOpenedAt = _lastOpenedAt;
    if (_lastOpenedCode != code || lastOpenedAt == null) {
      return false;
    }
    return DateTime.now().difference(lastOpenedAt).inMilliseconds < 500;
  }

  void _remember(String code) {
    _lastOpenedCode = code;
    _lastOpenedAt = DateTime.now();
  }

  String? _normalizeCode(String rawCode) {
    final normalized = rawCode.trim();
    final regex = RegExp(r'^\d{6}$');
    if (!regex.hasMatch(normalized)) {
      return null;
    }
    return normalized;
  }

  String _buildWindowsActivationScript({
    required String executablePath,
    required String code,
    required StockLinkClient client,
  }) {
    final clientLabel = client.label;
    final clientKey = client.storageValue;
    final escapedPath = _powerShellLiteral(executablePath);
    final escapedCode = _powerShellLiteral(code);
    final escapedClientLabel = _powerShellLiteral(clientLabel);
    final escapedClientKey = _powerShellLiteral(clientKey);

    return '''
\$ErrorActionPreference = 'Stop'
\$path = $escapedPath
\$code = $escapedCode
\$clientLabel = $escapedClientLabel
\$clientKey = $escapedClientKey
\$processName = [System.IO.Path]::GetFileNameWithoutExtension(\$path)
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class NiuNiuWin32 {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern void SwitchToThisWindow(IntPtr hWnd, bool fAltTab);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(int dwFlags, int dx, int dy, int dwData, UIntPtr dwExtraInfo);
  [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, int dwFlags, UIntPtr dwExtraInfo);
}
"@

function Get-ProcessPathSafe {
  param([System.Diagnostics.Process]\$Process)
  try {
    return [string]\$Process.Path
  } catch {
    return ''
  }
}

function Get-CandidateProcesses {
  \$installRoot = Split-Path -Parent \$path
  \$names = New-Object System.Collections.Generic.List[string]
  \$names.Add(\$processName)
  if (\$clientKey -eq 'tdx') {
    foreach (\$name in @('TdxW', 'TdxW64', 'TdxNonSP', 'TdxSP', 'mainfree', 'mpv')) {
      \$names.Add(\$name)
    }
  } elseif (\$clientKey -eq 'ths') {
    foreach (\$name in @('hexin', 'ths')) {
      \$names.Add(\$name)
    }
  }

  \$byName = @(foreach (\$name in (\$names | Select-Object -Unique)) {
    Get-Process -Name \$name -ErrorAction SilentlyContinue
  })
  \$byRoot = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
    \$candidatePath = Get-ProcessPathSafe \$_
    \$candidatePath -and \$candidatePath.StartsWith(\$installRoot, [System.StringComparison]::OrdinalIgnoreCase)
  })

  @(\$byName + \$byRoot) |
    Where-Object { \$_ } |
    Sort-Object Id -Unique
}

function Get-WindowTextSafe {
  param([IntPtr]\$Hwnd)
  \$buffer = New-Object System.Text.StringBuilder 512
  [NiuNiuWin32]::GetWindowText(\$Hwnd, \$buffer, \$buffer.Capacity) | Out-Null
  return \$buffer.ToString()
}

function Get-ClassNameSafe {
  param([IntPtr]\$Hwnd)
  \$buffer = New-Object System.Text.StringBuilder 256
  [NiuNiuWin32]::GetClassName(\$Hwnd, \$buffer, \$buffer.Capacity) | Out-Null
  return \$buffer.ToString()
}

function Find-ClientWindow {
  \$candidateProcesses = @(Get-CandidateProcesses)
  if (\$candidateProcesses.Count -eq 0) {
    return \$null
  }

  \$pidSet = New-Object 'System.Collections.Generic.HashSet[int]'
  foreach (\$candidate in \$candidateProcesses) {
    [void]\$pidSet.Add([int]\$candidate.Id)
  }

  \$windows = New-Object System.Collections.Generic.List[object]
  foreach (\$candidate in \$candidateProcesses) {
    try {
      \$candidate.Refresh()
      if (\$candidate.MainWindowHandle -ne 0) {
        \$hwnd = [IntPtr]\$candidate.MainWindowHandle
        \$windows.Add([pscustomobject]@{
          Hwnd = \$hwnd
          Pid = [int]\$candidate.Id
          ProcessName = \$candidate.ProcessName
          Title = \$candidate.MainWindowTitle
          ClassName = Get-ClassNameSafe \$hwnd
          Preferred = 1
        })
      }
    } catch {}
  }

  \$callback = [NiuNiuWin32+EnumWindowsProc]{
    param([IntPtr]\$hwnd, [IntPtr]\$lParam)
    if (-not [NiuNiuWin32]::IsWindowVisible(\$hwnd)) {
      return \$true
    }
    [uint32]\$windowPid = 0
    [NiuNiuWin32]::GetWindowThreadProcessId(\$hwnd, [ref]\$windowPid) | Out-Null
    if (\$pidSet.Contains([int]\$windowPid)) {
      \$process = \$candidateProcesses | Where-Object { \$_.Id -eq [int]\$windowPid } | Select-Object -First 1
      \$title = Get-WindowTextSafe \$hwnd
      \$className = Get-ClassNameSafe \$hwnd
      \$windows.Add([pscustomobject]@{
        Hwnd = \$hwnd
        Pid = [int]\$windowPid
        ProcessName = if (\$process) { \$process.ProcessName } else { '' }
        Title = \$title
        ClassName = \$className
        Preferred = if (\$title) { 2 } else { 0 }
      })
    }
    return \$true
  }
  [NiuNiuWin32]::EnumWindows(\$callback, [IntPtr]::Zero) | Out-Null

  \$windows |
    Sort-Object @{ Expression = {
      if (\$_.ClassName -like 'TdxW*' -or \$_.ClassName -like 'Afx:*') { 3 }
      elseif (\$_.Title) { \$_.Preferred }
      else { 0 }
    }; Descending = \$true }, Pid |
    Select-Object -First 1
}

function Wait-ClientWindow {
  param([int]\$TimeoutMilliseconds = 5000)
  \$deadline = [DateTime]::UtcNow.AddMilliseconds(\$TimeoutMilliseconds)
  do {
    \$found = Find-ClientWindow
    if (\$found) { return \$found }
    Start-Sleep -Milliseconds 250
  } while ([DateTime]::UtcNow -lt \$deadline)
  return \$null
}

\$window = Find-ClientWindow
if (-not \$window) {
  \$workDir = Split-Path -Parent \$path
  Start-Process -FilePath \$path -WorkingDirectory \$workDir | Out-Null
  \$window = Wait-ClientWindow -TimeoutMilliseconds 10000
}
if (-not \$window) {
  if (\$clientKey -eq 'ths') {
    Start-Process -FilePath \$path -ArgumentList "/stock=\$code" | Out-Null
    exit 0
  }
  throw "已启动 \$clientLabel，但未找到可接收键盘输入的主窗口。"
}

Write-Output ("target pid={0} hwnd={1} process={2} title={3} class={4}" -f \$window.Pid, \$window.Hwnd, \$window.ProcessName, \$window.Title, \$window.ClassName)

\$hwnd = [IntPtr]\$window.Hwnd
\$shell = New-Object -ComObject WScript.Shell
\$activated = \$false
for (\$i = 0; \$i -lt 6; \$i++) {
  try {
    [NiuNiuWin32]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 30
    [NiuNiuWin32]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [NiuNiuWin32]::ShowWindow(\$hwnd, 9) | Out-Null
    [NiuNiuWin32]::ShowWindowAsync(\$hwnd, 9) | Out-Null
    [NiuNiuWin32]::BringWindowToTop(\$hwnd) | Out-Null
    [NiuNiuWin32]::SwitchToThisWindow(\$hwnd, \$true)
    [NiuNiuWin32]::SetForegroundWindow(\$hwnd) | Out-Null
    Start-Sleep -Milliseconds 180
    \$activated = ([NiuNiuWin32]::GetForegroundWindow() -eq \$hwnd)
    if (-not \$activated) {
      \$activated = \$shell.AppActivate([int]\$window.Pid)
    }
    if (-not \$activated -and \$window.Title) {
      \$activated = \$shell.AppActivate([string]\$window.Title)
    }
  } catch {
    \$activated = \$false
  }
  if (\$activated) { break }
  Start-Sleep -Milliseconds 500
}
if (-not \$activated) {
  if (\$clientKey -eq 'ths') {
    Start-Process -FilePath \$path -ArgumentList "/stock=\$code" | Out-Null
    exit 0
  }
  throw "无法激活 \$clientLabel 窗口，请确认客户端未被最小化到托盘或被权限隔离。"
}

function Send-Key {
  param([byte]\$VirtualKey, [int]\$DelayMilliseconds = 45)
  [NiuNiuWin32]::keybd_event(\$VirtualKey, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds \$DelayMilliseconds
  [NiuNiuWin32]::keybd_event(\$VirtualKey, 0, 2, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds \$DelayMilliseconds
}

function Focus-ClientContent {
  param([IntPtr]\$Hwnd)
  try {
    \$rect = New-Object NiuNiuWin32+RECT
    if ([NiuNiuWin32]::GetWindowRect(\$Hwnd, [ref]\$rect)) {
      \$x = [int](\$rect.Left + ((\$rect.Right - \$rect.Left) / 2))
      \$y = [int](\$rect.Top + ((\$rect.Bottom - \$rect.Top) / 2))
      [NiuNiuWin32]::SetCursorPos(\$x, \$y) | Out-Null
      Start-Sleep -Milliseconds 80
      [NiuNiuWin32]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
      Start-Sleep -Milliseconds 40
      [NiuNiuWin32]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
      Start-Sleep -Milliseconds 180
    }
  } catch {}
}

Start-Sleep -Milliseconds 220
\$beforeTitle = Get-WindowTextSafe \$hwnd
if (\$clientKey -eq 'tdx') {
  Focus-ClientContent \$hwnd
}
Send-Key 0x1B 80
Start-Sleep -Milliseconds 120
foreach (\$ch in \$code.ToCharArray()) {
  Send-Key ([byte][int][char]\$ch) 35
}
Start-Sleep -Milliseconds 80
Send-Key 0x0D 60
Start-Sleep -Milliseconds 650
\$afterTitle = Get-WindowTextSafe \$hwnd
if (\$afterTitle -eq \$beforeTitle) {
  try {
    [NiuNiuWin32]::ShowWindow(\$hwnd, 9) | Out-Null
    [NiuNiuWin32]::BringWindowToTop(\$hwnd) | Out-Null
    [NiuNiuWin32]::SwitchToThisWindow(\$hwnd, \$true)
    [NiuNiuWin32]::SetForegroundWindow(\$hwnd) | Out-Null
    Start-Sleep -Milliseconds 160
    if (\$clientKey -eq 'tdx') {
      Focus-ClientContent \$hwnd
    }
    \$shell.AppActivate([int]\$window.Pid) | Out-Null
    Start-Sleep -Milliseconds 160
    \$shell.SendKeys('{ESC}')
    Start-Sleep -Milliseconds 120
    \$shell.SendKeys(\$code)
    Start-Sleep -Milliseconds 120
    \$shell.SendKeys('{ENTER}')
  } catch {}
}
''';
  }

  String _powerShellLiteral(String value) {
    final escaped = value.replaceAll("'", "''");
    return "'$escaped'";
  }
}

final stockLinkServiceProvider = Provider<StockLinkService>((ref) {
  return const StockLinkService();
});

Future<StockLinkResult> openStockLinkFromUi({
  required BuildContext context,
  required WidgetRef ref,
  required String code,
  bool showSuccess = false,
  bool preferredOnly = false,
}) async {
  final preferences =
      ref.read(appPreferencesProvider).valueOrNull ?? const AppPreferences();
  final service = ref.read(stockLinkServiceProvider);
  final result = preferredOnly
      ? await service.testPreferredClient(code, preferences)
      : await service.openStock(code, preferences);

  if (!context.mounted) {
    return result;
  }

  if (!result.success || showSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? null : const Color(0xFFC9553F),
      ),
    );
  }

  return result;
}
