import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'export_bundle_service.dart';

class WorkspaceImageExportResult {
  const WorkspaceImageExportResult({
    required this.filePath,
    required this.copiedToClipboard,
  });

  final String filePath;
  final bool copiedToClipboard;
}

Future<Uint8List?> captureRepaintBoundaryPng({
  required GlobalKey repaintBoundaryKey,
  required BuildContext context,
  double maxDevicePixelRatio = 2.0,
  double maxOutputHeight = 3000,
}) async {
  final boundaryContext = repaintBoundaryKey.currentContext;
  if (boundaryContext == null) {
    return null;
  }

  await WidgetsBinding.instance.endOfFrame;
  if (!context.mounted) {
    return null;
  }

  final boundary = boundaryContext.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null || boundary.size.isEmpty) {
    return null;
  }

  final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  final heightScaleCap =
      boundary.size.height <= 0 ? 1.0 : maxOutputHeight / boundary.size.height;
  final pixelRatio = math.min(
    math.min(devicePixelRatio, maxDevicePixelRatio),
    heightScaleCap <= 0 ? 1.0 : heightScaleCap,
  );

  final image = await boundary.toImage(
    pixelRatio: pixelRatio <= 0 ? 1.0 : pixelRatio,
  );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData?.buffer.asUint8List();
}

Future<WorkspaceImageExportResult?> captureWorkspaceImage({
  required GlobalKey repaintBoundaryKey,
  required BuildContext context,
  required String bundleName,
  required String fileName,
}) async {
  final bytes = await captureRepaintBoundaryPng(
    repaintBoundaryKey: repaintBoundaryKey,
    context: context,
  );
  if (bytes == null) {
    return null;
  }

  final filePath = await writeBinaryFile(
    bundleName: bundleName,
    fileName: fileName,
    bytes: bytes,
  );
  final copiedToClipboard = await copyPngFileToClipboard(filePath);
  return WorkspaceImageExportResult(
    filePath: filePath,
    copiedToClipboard: copiedToClipboard,
  );
}

Future<bool> copyPngFileToClipboard(String filePath) async {
  if (!Platform.isWindows) {
    return false;
  }

  final script = '''
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
\$path = ${_powerShellLiteral(filePath)}
\$bytes = [System.IO.File]::ReadAllBytes(\$path)
\$stream = New-Object System.IO.MemoryStream(,\$bytes)
\$image = [System.Drawing.Image]::FromStream(\$stream)
\$bitmap = New-Object System.Drawing.Bitmap \$image
try {
  [System.Windows.Forms.Clipboard]::SetImage(\$bitmap)
} finally {
  \$bitmap.Dispose()
  \$image.Dispose()
  \$stream.Dispose()
}
''';

  try {
    final result = await Process.run(
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
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

String _powerShellLiteral(String value) {
  final escaped = value.replaceAll("'", "''");
  return "'$escaped'";
}
