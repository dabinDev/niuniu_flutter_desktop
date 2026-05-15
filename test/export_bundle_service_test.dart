import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niuniu_kaipan/shared/application/export_bundle_service.dart';

void main() {
  test('writeExcelWorkbook creates xlsx archive with workbook parts', () async {
    final filePath = await writeExcelWorkbook(
      bundleName: 'test_excel_bundle',
      fileName: 'board_height.xlsx',
      sheets: const [
        ExcelSheetData(
          name: 'Summary/Overview',
          rows: [
            ['label', 'value'],
            ['trade_date', '2026-04-17'],
          ],
        ),
        ExcelSheetData(
          name: 'Summary/Overview',
          rows: [
            ['date', 'height'],
            ['2026-04-17', '4'],
          ],
        ),
      ],
    );

    addTearDown(() async {
      final directory = Directory(filePath).parent;
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final file = File(filePath);
    expect(await file.exists(), isTrue);
    expect(file.path.endsWith('.xlsx'), isTrue);

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files.map((file) => file.name).toSet();

    expect(names, contains('[Content_Types].xml'));
    expect(names, contains('_rels/.rels'));
    expect(names, contains('xl/workbook.xml'));
    expect(names, contains('xl/styles.xml'));
    expect(names, contains('xl/worksheets/sheet1.xml'));
    expect(names, contains('xl/worksheets/sheet2.xml'));

    final workbook = archive.findFile('xl/workbook.xml');
    expect(workbook, isNotNull);
    final workbookXml = String.fromCharCodes(workbook!.content as List<int>);
    expect(workbookXml, contains('Summary_Overview'));
    expect(workbookXml, contains('Summary_Overview (2)'));
  });
}
