import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'asset_loader.dart';

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

  bool get isLoaded => _loaded;

  Future<bool> load() async {
    if (_loaded) return true;
    try {
      _lib = DynamicLibrary.open('libhumaid_core.so');

      _initEngine =
          _lib.lookupFunction<InitEngineNative, InitEngineDart>('init_engine');
      _lookupWord = _lib
          .lookupFunction<LookupWordNative, LookupWordDart>('lookup_word');
      _lemmatize =
          _lib.lookupFunction<LemmatizeNative, LemmatizeDart>('lemmatize');

      // Ensure dictionary exists locally
      final dictPath = await AssetLoader.copyDictionaryToLocal();
      if (dictPath == null) return false;

      final pathPtr = dictPath.toNativeUtf8();
      final result = _initEngine(pathPtr);
      calloc.free(pathPtr);

      _loaded = result == 1;
      return _loaded;
    } catch (e) {
      print("Core load failed: $e");
      return false;
    }
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
