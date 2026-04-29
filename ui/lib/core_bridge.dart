import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';

// Rust function signatures
typedef InitEngineNative = Int8 Function(Pointer<Utf8>);
typedef InitEngineDart = int Function(Pointer<Utf8>);

typedef LookupWordNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef LookupWordDart = Pointer<Utf8> Function(Pointer<Utf8>);

typedef LemmatizeNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef LemmatizeDart = Pointer<Utf8> Function(Pointer<Utf8>);

class CoreBridge {
  late DynamicLibrary _lib;
  late InitEngineDart _initEngine;
  late LookupWordDart _lookupWord;
  late LemmatizeDart _lemmatize;

  bool _loaded = false;

  static final CoreBridge _instance = CoreBridge._internal();
  factory CoreBridge() => _instance;
  CoreBridge._internal();

  /// Public getter so other screens can check if engine is initialised.
  bool get isLoaded => _loaded;

  Future<bool> load() async {
    if (_loaded) return true;
    try {
      _lib = DynamicLibrary.open('libhumaid_core.so');

      _initEngine = _lib.lookupFunction<InitEngineNative, InitEngineDart>('init_engine');
      _lookupWord = _lib.lookupFunction<LookupWordNative, LookupWordDart>('lookup_word');
      _lemmatize = _lib.lookupFunction<LemmatizeNative, LemmatizeDart>('lemmatize');

      final dictPath = await _dictionaryPath();
      if (dictPath == null) return false;

      final pathPtr = dictPath.toNativeUtf8();
      final result = _initEngine(pathPtr);
      calloc.free(pathPtr);

      _loaded = result == 1;
      return _loaded;
    } catch (e) {
      print("Failed to load core: $e");
      return false;
    }
  }

  Future<String?> _dictionaryPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/soul_dict.db.zst');
    if (await file.exists()) {
      return file.path;
    }
    return null;
  }

  String lookup(String word) {
    final wordPtr = word.toNativeUtf8();
    final resultPtr = _lookupWord(wordPtr);
    calloc.free(wordPtr);
    return resultPtr.cast<Utf8>().toDartString();
  }

  String lemmatize(String word) {
    final wordPtr = word.toNativeUtf8();
    final resultPtr = _lemmatize(wordPtr);
    calloc.free(wordPtr);
    return resultPtr.cast<Utf8>().toDartString();
  }
}
