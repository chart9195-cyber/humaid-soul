import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// C signature types
typedef InitEngineNative = Int32 Function(Pointer<Utf8> path);
typedef InitEngineDart = int Function(Pointer<Utf8> path);

typedef LookupWordNative = Pointer<Utf8> Function(Pointer<Utf8> word);
typedef LookupWordDart = Pointer<Utf8> Function(Pointer<Utf8> word);

typedef LemmatizeNative = Pointer<Utf8> Function(Pointer<Utf8> word);
typedef LemmatizeDart = Pointer<Utf8> Function(Pointer<Utf8> word);

typedef FuzzySearchNative = Pointer<Utf8> Function(Pointer<Utf8> word, Int32 maxResults);
typedef FuzzySearchDart = Pointer<Utf8> Function(Pointer<Utf8> word, int maxResults);

typedef FreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef FreeStringDart = void Function(Pointer<Utf8> ptr);

class NativeBridge {
  late final DynamicLibrary _lib;
  late final InitEngineDart initEngine;
  late final LookupWordDart lookupWord;
  late final LemmatizeDart lemmatize;
  late final FuzzySearchDart fuzzySearch;
  late final FreeStringDart freeString;

  NativeBridge() {
    if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libhumaid_core.so');
    } else if (Platform.isIOS) {
      _lib = DynamicLibrary.process(); // iOS statically linked
    } else {
      throw UnsupportedError('Unsupported platform');
    }

    initEngine = _lib
        .lookupFunction<InitEngineNative, InitEngineDart>('init_engine_ffi');

    lookupWord = _lib
        .lookupFunction<LookupWordNative, LookupWordDart>('lookup_word_ffi');

    lemmatize = _lib
        .lookupFunction<LemmatizeNative, LemmatizeDart>('lemmatize_ffi');

    fuzzySearch = _lib
        .lookupFunction<FuzzySearchNative, FuzzySearchDart>('fuzzy_search_ffi');

    freeString = _lib
        .lookupFunction<FreeStringNative, FreeStringDart>('free_string_ffi');
  }
}
