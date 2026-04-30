import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'asset_loader.dart';

typedef InitEngineNative = Int8 Function(Pointer<Utf8>);
typedef InitEngineDart = int Function(Pointer<Utf8>);
typedef LookupWordNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef LookupWordDart = Pointer<Utf8> Function(Pointer<Utf8>);
typedef LemmatizeNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef LemmatizeDart = Pointer<Utf8> Function(Pointer<Utf8>);

enum EngineState { uninitialized, loading, ready, error }

class CoreBridge {
  late DynamicLibrary _lib;
  late InitEngineDart _initEngine;
  late LookupWordDart _lookupWord;
  late LemmatizeDart _lemmatize;

  EngineState state = EngineState.uninitialized;
  String? errorMessage;
  static final CoreBridge _instance = CoreBridge._internal();
  factory CoreBridge() => _instance;
  CoreBridge._internal();

  bool get isLoaded => state == EngineState.ready;

  /// Call this to ensure the engine is ready. Safe to call multiple times.
  Future<void> loadIfNeeded() async {
    if (state == EngineState.ready) return;
    if (state == EngineState.loading) {
      // Wait for the current load to finish (simple polling, no event loop needed)
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (state == EngineState.ready || state == EngineState.error) return;
      }
    }
    if (state == EngineState.error) {
      // Allow retry
      state = EngineState.uninitialized;
      errorMessage = null;
    }
    await load();
  }

  /// Internal load – can be called externally only if state is uninitialized.
  Future<void> load() async {
    if (state == EngineState.ready || state == EngineState.loading) return;

    state = EngineState.loading;
    errorMessage = null;
    try {
      _lib = DynamicLibrary.open('libhumaid_core.so');
      _initEngine = _lib.lookupFunction<InitEngineNative, InitEngineDart>('init_engine');
      _lookupWord = _lib.lookupFunction<LookupWordNative, LookupWordDart>('lookup_word');
      _lemmatize = _lib.lookupFunction<LemmatizeNative, LemmatizeDart>('lemmatize');

      final dictPath = await AssetLoader.copyDictionaryToLocal();
      if (dictPath == null) {
        errorMessage = 'Dictionary file not found.';
        state = EngineState.error;
        return;
      }

      final pathPtr = dictPath.toNativeUtf8();
      final result = _initEngine(pathPtr);
      calloc.free(pathPtr);

      if (result == 1) {
        state = EngineState.ready;
      } else {
        errorMessage = 'Engine initialization returned failure.';
        state = EngineState.error;
      }
    } catch (e) {
      errorMessage = 'Engine load exception: $e';
      state = EngineState.error;
    }
  }

  String lookup(String word) {
    if (state != EngineState.ready) return '[]';
    final wordPtr = word.toNativeUtf8();
    final resultPtr = _lookupWord(wordPtr);
    calloc.free(wordPtr);
    return resultPtr.cast<Utf8>().toDartString();
  }

  String lemmatize(String word) {
    if (state != EngineState.ready) return word;
    final wordPtr = word.toNativeUtf8();
    final resultPtr = _lemmatize(wordPtr);
    calloc.free(wordPtr);
    return resultPtr.cast<Utf8>().toDartString();
  }
}
