import 'dart:convert';

import 'package:flutter/services.dart';

const String wordBankAsset = 'words/bank_v1.json';

/// One word of the bank with its clue.
class BankEntry {
  const BankEntry({
    required this.id,
    required this.answer,
    required this.display,
    required this.clue,
    required this.category,
    required this.difficulty,
  });

  factory BankEntry.fromJson(Map<String, dynamic> j) => BankEntry(
        id: j['id'] as int,
        answer: j['answer'] as String,
        display: j['display'] as String,
        clue: j['clue'] as String,
        category: j['category'] as String,
        difficulty: j['difficulty'] as int,
      );

  final int id;
  final String answer;
  final String display;
  final String clue;
  final String category;
  final int difficulty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'answer': answer,
        'display': display,
        'clue': clue,
        'category': category,
        'difficulty': difficulty,
      };
}

List<BankEntry> parseWordBank(String source) => [
      for (final e in jsonDecode(source) as List)
        BankEntry.fromJson((e as Map).cast<String, dynamic>()),
    ];

/// Loads the bundled bank. Works offline: the file ships inside the app.
Future<List<BankEntry>> loadWordBank([AssetBundle? bundle]) async =>
    parseWordBank(await (bundle ?? rootBundle).loadString(wordBankAsset));
