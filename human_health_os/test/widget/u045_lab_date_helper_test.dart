import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/l10n/strings.dart';

// U045 review: the lab sample-date helper follows the language and keeps
// the date pattern whole (no hardcoded English 'YYYY-MM-DD').
void main() {
  test('EN lab date helper is the whole EN pattern', () {
    expect(const S(AppLang.en).dateHelperYmd, ymdEn);
  });
  test('TR lab date helper is the whole TR pattern', () {
    expect(const S(AppLang.tr).dateHelperYmd, ymdTr);
  });
}
