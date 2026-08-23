import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentFileEntry {
  final String path;
  final String hash;
  final int size;

  const RecentFileEntry({
    required this.path,
    required this.hash,
    required this.size,
  });

  Map<String, dynamic> toJson() => {'path': path, 'hash': hash, 'size': size};

  factory RecentFileEntry.fromJson(Map<String, dynamic> json) {
    return RecentFileEntry(
      path: json['path'] as String? ?? '',
      hash: json['hash'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}

class RecentFilesService {
  static const String _keyRecentFiles = 'recent_files_v2';
  static const String _keyLegacyPaths = 'recent_files';
  static const String _keyRecentFilesExpanded = 'recent_files_expanded';
  static const int _maxRecentFiles = 10;
  static const int _sampleBytes = 64 * 1024;
  static Future<void> _operationQueue = Future<void>.value();

  static Future<T> _synchronized<T>(Future<T> Function() operation) {
    final result = _operationQueue.then((_) => operation());
    _operationQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<bool> getRecentFilesExpanded() {
    return _synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyRecentFilesExpanded) ?? true;
    });
  }

  Future<void> setRecentFilesExpanded(bool expanded) {
    return _synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyRecentFilesExpanded, expanded);
    });
  }

  // hash start & end of file
  static Future<String> computeFileHash(String path) async {
    final file = File(path);
    final length = await file.length();
    final digest = await sha256.bind(_hashSampleStream(file, length)).first;
    return digest.toString();
  }

  static Stream<List<int>> _hashSampleStream(File file, int length) async* {
    yield utf8.encode('len=$length;');
    if (length <= 0) return;

    final raf = await file.open();
    try {
      final headLen = length < _sampleBytes ? length : _sampleBytes;
      yield await raf.read(headLen);

      if (length > _sampleBytes * 2) {
        await raf.setPosition(length - _sampleBytes);
        yield await raf.read(_sampleBytes);
      } else if (length > _sampleBytes) {
        await raf.setPosition(headLen);
        yield await raf.read(length - headLen);
      }
    } finally {
      await raf.close();
    }
  }

  Future<List<RecentFileEntry>> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyRecentFiles);
    if (raw != null) {
      final list = <RecentFileEntry>[];
      for (final s in raw) {
        try {
          final map = jsonDecode(s) as Map<String, dynamic>;
          final e = RecentFileEntry.fromJson(map);
          if (e.path.isNotEmpty && e.hash.isNotEmpty) list.add(e);
        } catch (_) {}
      }
      return list;
    }

    final legacy = prefs.getStringList(_keyLegacyPaths);
    if (legacy == null || legacy.isEmpty) return [];
    await prefs.remove(_keyLegacyPaths);
    return [];
  }

  Future<void> _saveEntries(List<RecentFileEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = entries.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_keyRecentFiles, raw);
  }

  Future<List<String>> getRecentFiles() {
    return _synchronized(() async {
      final entries = await _loadEntries();
      if (entries.isEmpty) return <String>[];

      final valid = <RecentFileEntry>[];
      final paths = <String>[];

      for (final e in entries) {
        final file = File(e.path);
        if (!await file.exists()) continue;
        try {
          final size = await file.length();
          if (size != e.size) continue;
          final hash = await computeFileHash(e.path);
          if (hash != e.hash) continue;
          valid.add(e);
          paths.add(e.path);
        } catch (_) {}
      }

      if (valid.length != entries.length) {
        await _saveEntries(valid);
      }
      return paths;
    });
  }

  Future<void> addRecentFile(String path) {
    return _synchronized(() async {
      final file = File(path);
      if (!await file.exists()) return;

      final size = await file.length();
      final hash = await computeFileHash(path);
      final entry = RecentFileEntry(path: path, hash: hash, size: size);

      var entries = await _loadEntries();
      entries.removeWhere((e) => e.path == path);
      entries.insert(0, entry);
      if (entries.length > _maxRecentFiles) {
        entries = entries.sublist(0, _maxRecentFiles);
      }
      await _saveEntries(entries);
    });
  }

  Future<void> removeRecentFile(String path) {
    return _synchronized(() async {
      final entries = await _loadEntries();
      entries.removeWhere((e) => e.path == path);
      await _saveEntries(entries);
    });
  }

  Future<void> clearRecentFiles() {
    return _synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyRecentFiles);
      await prefs.remove(_keyLegacyPaths);
    });
  }

  Future<bool> verifyRecentFile(String path) {
    return _synchronized(() async {
      final entries = await _loadEntries();
      RecentFileEntry? entry;
      for (final e in entries) {
        if (e.path == path) {
          entry = e;
          break;
        }
      }
      if (entry == null) return false;
      final file = File(path);
      if (!await file.exists()) return false;
      try {
        final size = await file.length();
        if (size != entry.size) return false;
        final hash = await computeFileHash(path);
        return hash == entry.hash;
      } catch (_) {
        return false;
      }
    });
  }
}
