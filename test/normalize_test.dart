import 'package:almuhra_crossword/core/arabic/normalize.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hamza seats are unified', () {
    expect(normalizeArabic('أإآٱ'), 'اااا');
    expect(normalizeArabic('مؤمن'), 'مومن');
    expect(normalizeArabic('رئيس'), 'رييس');
  });

  test('ta marbuta becomes ha; hamza and alef maqsura are kept', () {
    expect(normalizeArabic('دجلة'), 'دجله');
    expect(normalizeArabic('سماء'), 'سماء');
    expect(normalizeArabic('مصطفى'), 'مصطفى');
  });

  test('tashkeel, tatweel and spaces are removed', () {
    expect(normalizeArabic('عَمّـــان'), 'عمان');
    expect(normalizeArabic('قُرْآن'), 'قران');
    expect(normalizeArabic(' بغداد '), 'بغداد');
  });

  test('alphabet: 30 unique single letters, no ta marbuta', () {
    expect(arabicAlphabet.length, 30);
    expect(arabicAlphabet.toSet().length, 30);
    expect(arabicAlphabet.contains('ة'), isFalse);
    for (final l in arabicAlphabet) {
      expect(l.runes.length, 1);
    }
  });

  test('isValidAnswer', () {
    expect(isValidAnswer('بغداد'), isTrue);
    expect(isValidAnswer('H2O'), isFalse);
    expect(isValidAnswer('ب'), isFalse);
    expect(isValidAnswer('ابن سينا'), isFalse);
    expect(isValidAnswer('ابجدهوزحطي'), isTrue);
    expect(isValidAnswer('ابجدهوزحطيك'), isFalse);
  });
}
