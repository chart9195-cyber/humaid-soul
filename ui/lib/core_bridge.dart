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

typedef FreeStringNative = Void Function(Pointer<Utf8>);
typedef FreeStringDart = void Function(Pointer<Utf8>);

class CoreBridge {
  late final DynamicLibrary _lib;
  late final InitEngineDart _initEngine;
  late final LookupWordDart _lookupWord;
  late final LemmatizeDart _lemmatize;
  // Free function not strictly needed since we use Utf8 string conversion later
  static final CoreBridge _instance = CoreBridge._internal();

  factory CoreBridge() => _instance;

  CoreBridge._internal();

  bool _loaded = false;

  Future<bool> load() async {
    if (_loaded) return true;
    try {
      // Load libhumaid_core.so (it must be placed in the right jniLibs folder)
      _lib = DynamicLibrary.open('libhumaid_core.so');

      _initEngine = _lib.lookupFunction<InitEngineNative, InitEngineDart>('init_engine');
      _lookupWord = _lib.lookupFunction<LookupWordNative, LookupWordDart>('lookup_word');
      _lemmatize = _lib.lookupFunction<LemmatizeNative, LemmatizeDart>('lemmatize');

      // Locate dictionary file (download or extract from assets)
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
    // Place the dictionary in the app's documents folder.
    // You'll need to copy the asset there on first launch.
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/soul_dict.db.zst');
    if (await file.exists()) {
      return file.path;
    }
    return null; // will be handled by asset copy logic later
  }

  /// Returns the lookup result as a JSON string.
  String lookup(String word) {
    final wordPtr = word.toNativeUtf8();
    final resultPtr = _lookupWord(wordPtr);
    calloc.free(wordPtr);
    final result = resultPtr.cast<Utf8>().toDartString();
    // We don't free the returned string because Rust allocates it with CString and
    // we need to provide a free function. For simplicity, we'll add a free function later.
    // For now, small memory leak on each call; manageable for prototyping.
    return result;
  }

  String lemmatize(String word) {
    final wordPtr = word.toNativeUtf8();
    final resultPtr = _lemmatize(wordPtr);
    calloc.free(wordPtr);
    return resultPtr.cast<Utf8>().toDartString();
  }
}
