import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

class ExportBundleResult {
  const ExportBundleResult({
    required this.directoryPath,
    required this.filePaths,
  });

  final String directoryPath;
  final List<String> filePaths;
}

class ExcelSheetData {
  const ExcelSheetData({
    required this.name,
    required this.rows,
  });

  final String name;
  final List<List<String>> rows;
}

Future<ExportBundleResult> writeCsvBundle({
  required String bundleName,
  required Map<String, List<List<String>>> files,
}) async {
  final target = await createExportDirectory(bundleName: bundleName);
  await target.create(recursive: true);

  final filePaths = <String>[];
  for (final entry in files.entries) {
    final sanitized = _sanitizeFileName(entry.key);
    final path = '${target.path}${Platform.pathSeparator}$sanitized.csv';
    final file = File(path);
    await file.writeAsString(
      _toCsv(entry.value),
      encoding: utf8,
      flush: true,
    );
    filePaths.add(path);
  }

  return ExportBundleResult(
    directoryPath: target.path,
    filePaths: filePaths,
  );
}

Future<Directory> createExportDirectory({
  required String bundleName,
}) async {
  final root = await _ensureExportRoot();
  final timestamp = _timestampForFile(DateTime.now());
  return Directory(
      '${root.path}${Platform.pathSeparator}$bundleName-$timestamp');
}

Future<String> writeBinaryFile({
  required String bundleName,
  required String fileName,
  required List<int> bytes,
}) async {
  final target = await createExportDirectory(bundleName: bundleName);
  await target.create(recursive: true);

  final sanitized = _sanitizeFileName(fileName);
  final path = '${target.path}${Platform.pathSeparator}$sanitized';
  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}

Future<String> writeExcelWorkbook({
  required String bundleName,
  required String fileName,
  required List<ExcelSheetData> sheets,
}) async {
  final normalizedSheets = sheets.isEmpty
      ? const [
          ExcelSheetData(
            name: 'Sheet1',
            rows: [],
          ),
        ]
      : _normalizeSheetNames(sheets);

  final archive = Archive();
  archive.addFile(
    ArchiveFile.string(
      '[Content_Types].xml',
      _buildWorkbookContentTypesXml(normalizedSheets.length),
    ),
  );
  archive.addFile(
    ArchiveFile.string(
      '_rels/.rels',
      _rootRelationshipsXml,
    ),
  );
  archive.addFile(
    ArchiveFile.string(
      'xl/workbook.xml',
      _buildWorkbookXml(normalizedSheets),
    ),
  );
  archive.addFile(
    ArchiveFile.string(
      'xl/_rels/workbook.xml.rels',
      _buildWorkbookRelationshipsXml(normalizedSheets.length),
    ),
  );
  archive.addFile(
    ArchiveFile.string(
      'xl/styles.xml',
      _stylesXml,
    ),
  );

  for (var index = 0; index < normalizedSheets.length; index++) {
    archive.addFile(
      ArchiveFile.string(
        'xl/worksheets/sheet${index + 1}.xml',
        _buildWorksheetXml(normalizedSheets[index]),
      ),
    );
  }

  final bytes = ZipEncoder().encodeBytes(archive);
  return writeBinaryFile(
    bundleName: bundleName,
    fileName: fileName,
    bytes: bytes,
  );
}

Future<Directory> _ensureExportRoot() async {
  final home = Platform.environment['USERPROFILE'] ??
      Platform.environment['HOME'] ??
      Directory.current.path;
  final root = Directory(
    '$home${Platform.pathSeparator}Documents${Platform.pathSeparator}NiuNiuKaiPan${Platform.pathSeparator}exports',
  );
  await root.create(recursive: true);
  return root;
}

String _toCsv(List<List<String>> rows) {
  return rows.map((row) => row.map(_escapeCsvCell).join(',')).join('\r\n');
}

String _escapeCsvCell(String value) {
  final normalized = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final escaped = normalized.replaceAll('"', '""');
  if (escaped.contains(',') ||
      escaped.contains('"') ||
      escaped.contains('\n')) {
    return '"$escaped"';
  }
  return escaped;
}

String _sanitizeFileName(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
      .replaceAll(RegExp(r'\s+'), '_');
}

String _timestampForFile(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year}${two(value.month)}${two(value.day)}_'
      '${two(value.hour)}${two(value.minute)}${two(value.second)}';
}

List<ExcelSheetData> _normalizeSheetNames(List<ExcelSheetData> sheets) {
  final usedNames = <String>{};
  return sheets.map((sheet) {
    final sanitized = _uniqueSheetName(
      _sanitizeSheetName(sheet.name),
      usedNames,
    );
    usedNames.add(sanitized);
    return ExcelSheetData(
      name: sanitized,
      rows: sheet.rows,
    );
  }).toList(growable: false);
}

String _uniqueSheetName(String baseName, Set<String> usedNames) {
  if (!usedNames.contains(baseName)) {
    return baseName;
  }

  var suffix = 2;
  while (true) {
    final suffixLabel = ' ($suffix)';
    final maxBaseLength = 31 - suffixLabel.length;
    final trimmedBase = baseName.length > maxBaseLength
        ? baseName.substring(0, maxBaseLength)
        : baseName;
    final candidate = '$trimmedBase$suffixLabel';
    if (!usedNames.contains(candidate)) {
      return candidate;
    }
    suffix++;
  }
}

String _sanitizeSheetName(String value) {
  final sanitized = value
      .trim()
      .replaceAll(RegExp(r'[\[\]\*\?/\\:]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ');
  return _trimSheetName(sanitized.isEmpty ? 'Sheet' : sanitized);
}

String _trimSheetName(String value) {
  final trimmed = value.trim();
  if (trimmed.length <= 31) {
    return trimmed;
  }
  return trimmed.substring(0, 31);
}

String _buildWorkbookContentTypesXml(int sheetCount) {
  final overrides = StringBuffer()
    ..writeln(
      '<Override PartName="/xl/workbook.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>',
    )
    ..writeln(
      '<Override PartName="/xl/styles.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>',
    );

  for (var index = 0; index < sheetCount; index++) {
    overrides.writeln(
      '<Override PartName="/xl/worksheets/sheet${index + 1}.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
    );
  }

  return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  ${overrides.toString().trimRight()}
</Types>
''';
}

String _buildWorkbookXml(List<ExcelSheetData> sheets) {
  final sheetXml = StringBuffer();
  for (var index = 0; index < sheets.length; index++) {
    sheetXml.writeln(
      '<sheet name="${_escapeXmlAttribute(sheets[index].name)}" '
      'sheetId="${index + 1}" r:id="rId${index + 1}"/>',
    );
  }

  return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook
    xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <bookViews>
    <workbookView xWindow="0" yWindow="0" windowWidth="24000" windowHeight="12000"/>
  </bookViews>
  <sheets>
    ${sheetXml.toString().trimRight()}
  </sheets>
</workbook>
''';
}

String _buildWorkbookRelationshipsXml(int sheetCount) {
  final relationships = StringBuffer();
  for (var index = 0; index < sheetCount; index++) {
    relationships.writeln(
      '<Relationship Id="rId${index + 1}" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
      'Target="worksheets/sheet${index + 1}.xml"/>',
    );
  }
  relationships.writeln(
    '<Relationship Id="rId${sheetCount + 1}" '
    'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" '
    'Target="styles.xml"/>',
  );

  return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  ${relationships.toString().trimRight()}
</Relationships>
''';
}

String _buildWorksheetXml(ExcelSheetData sheet) {
  final rows = sheet.rows;
  final maxColumns = rows.fold<int>(
    0,
    (current, row) => row.length > current ? row.length : current,
  );

  final columnWidths = List<double>.generate(
    maxColumns,
    (index) => _columnWidthForSheet(rows, index),
    growable: false,
  );

  final columnsXml = StringBuffer();
  if (columnWidths.isNotEmpty) {
    columnsXml.writeln('<cols>');
    for (var index = 0; index < columnWidths.length; index++) {
      columnsXml.writeln(
        '<col min="${index + 1}" max="${index + 1}" '
        'width="${columnWidths[index].toStringAsFixed(2)}" customWidth="1"/>',
      );
    }
    columnsXml.writeln('</cols>');
  }

  final sheetDataXml = StringBuffer();
  for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
    final row = rows[rowIndex];
    final cellsXml = StringBuffer();
    for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
      final value = row[columnIndex];
      if (value.isEmpty) {
        continue;
      }
      final cellRef = '${_columnName(columnIndex + 1)}${rowIndex + 1}';
      final style = rowIndex == 0 ? ' s="1"' : '';
      cellsXml.writeln(
        '<c r="$cellRef" t="inlineStr"$style>'
        '<is><t xml:space="preserve">${_escapeXmlText(value)}</t></is>'
        '</c>',
      );
    }
    sheetDataXml.writeln(
      '<row r="${rowIndex + 1}">${cellsXml.toString().trimRight()}</row>',
    );
  }

  return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetViews>
    <sheetView workbookViewId="0"/>
  </sheetViews>
  ${columnsXml.toString().trimRight()}
  <sheetData>
    ${sheetDataXml.toString().trimRight()}
  </sheetData>
</worksheet>
''';
}

double _columnWidthForSheet(List<List<String>> rows, int columnIndex) {
  var maxLength = 10;
  for (final row in rows) {
    if (columnIndex >= row.length) {
      continue;
    }
    final length = row[columnIndex].trim().length;
    if (length > maxLength) {
      maxLength = length;
    }
  }
  final adjusted = maxLength + 2;
  return adjusted > 42 ? 42 : adjusted.toDouble();
}

String _columnName(int index) {
  var current = index;
  final buffer = StringBuffer();
  while (current > 0) {
    current--;
    buffer.writeCharCode(65 + (current % 26));
    current ~/= 26;
  }
  return buffer.toString().split('').reversed.join();
}

String _escapeXmlText(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

String _escapeXmlAttribute(String value) {
  return _escapeXmlText(value);
}

const _rootRelationshipsXml =
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1"
      Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
      Target="xl/workbook.xml"/>
</Relationships>
''';

const _stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="2">
    <font>
      <sz val="11"/>
      <color theme="1"/>
      <name val="Calibri"/>
      <family val="2"/>
      <scheme val="minor"/>
    </font>
    <font>
      <b/>
      <sz val="11"/>
      <color rgb="FFFFFFFF"/>
      <name val="Calibri"/>
      <family val="2"/>
      <scheme val="minor"/>
    </font>
  </fonts>
  <fills count="3">
    <fill>
      <patternFill patternType="none"/>
    </fill>
    <fill>
      <patternFill patternType="gray125"/>
    </fill>
    <fill>
      <patternFill patternType="solid">
        <fgColor rgb="FF1C3B33"/>
        <bgColor indexed="64"/>
      </patternFill>
    </fill>
  </fills>
  <borders count="1">
    <border>
      <left/>
      <right/>
      <top/>
      <bottom/>
      <diagonal/>
    </border>
  </borders>
  <cellStyleXfs count="1">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
  </cellStyleXfs>
  <cellXfs count="2">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
    <xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>
  </cellXfs>
  <cellStyles count="1">
    <cellStyle name="Normal" xfId="0" builtinId="0"/>
  </cellStyles>
</styleSheet>
''';
