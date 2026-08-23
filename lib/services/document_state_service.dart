import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DocumentState {
  final int currentPage;
  final double scale;
  final DateTime lastOpened;

  DocumentState({
    required this.currentPage,
    required this.scale,
    required this.lastOpened,
  });

  factory DocumentState.fromJson(Map<String, dynamic> json) {
    return DocumentState(
      currentPage: json['currentPage'] as int? ?? 1,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      lastOpened: json['lastOpened'] != null
          ? DateTime.parse(json['lastOpened'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentPage': currentPage,
      'scale': scale,
      'lastOpened': lastOpened.toIso8601String(),
    };
  }
}

class DocumentStateService {
  static const String _keyDocumentStates = 'document_states';
  static const int _maxStoredDocuments = 50;
  static Future<void> _operationQueue = Future<void>.value();

  static Future<T> _synchronized<T>(Future<T> Function() operation) {
    final result = _operationQueue.then((_) => operation());
    _operationQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<DocumentState?> getDocumentState(String filePath) {
    return _synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      final statesJson = prefs.getString(_keyDocumentStates);

      if (statesJson == null) return null;

      try {
        final Map<String, dynamic> states = jsonDecode(statesJson);
        if (states.containsKey(filePath)) {
          return DocumentState.fromJson(
            states[filePath] as Map<String, dynamic>,
          );
        }
      } catch (_) {
        return null;
      }

      return null;
    });
  }

  Future<void> saveDocumentState(
    String filePath, {
    required int currentPage,
    required double scale,
  }) {
    return _synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      final statesJson = prefs.getString(_keyDocumentStates);

      Map<String, dynamic> states = {};
      if (statesJson != null) {
        try {
          states = jsonDecode(statesJson) as Map<String, dynamic>;
        } catch (_) {
          states = {};
        }
      }

      states[filePath] = DocumentState(
        currentPage: currentPage,
        scale: scale,
        lastOpened: DateTime.now(),
      ).toJson();

      if (states.length > _maxStoredDocuments) {
        final entries = states.entries.toList();
        entries.sort((a, b) {
          DateTime readDate(dynamic value) {
            if (value is! Map) return DateTime(1970);
            final raw = value['lastOpened'];
            return raw is String
                ? DateTime.tryParse(raw) ?? DateTime(1970)
                : DateTime(1970);
          }

          return readDate(b.value).compareTo(readDate(a.value));
        });

        states = Map.fromEntries(entries.take(_maxStoredDocuments));
      }

      await prefs.setString(_keyDocumentStates, jsonEncode(states));
    });
  }

  Future<void> removeDocumentState(String filePath) {
    return _synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      final statesJson = prefs.getString(_keyDocumentStates);

      if (statesJson == null) return;

      try {
        final Map<String, dynamic> states = jsonDecode(statesJson);
        states.remove(filePath);
        await prefs.setString(_keyDocumentStates, jsonEncode(states));
      } catch (_) {}
    });
  }

  Future<void> clearAllStates() {
    return _synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyDocumentStates);
    });
  }
}
