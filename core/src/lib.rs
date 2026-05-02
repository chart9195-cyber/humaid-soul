pub mod dictionary;
pub mod pdf_extract;

use std::ffi::{CStr, CString};
use std::os::raw::c_char;

/// FFI: Initialize engine with main dictionary path.
#[no_mangle]
pub extern "C" fn init_engine(path: *const c_char) -> i8 {
    let path_str = unsafe { CStr::from_ptr(path) }.to_string_lossy();
    if dictionary::load_dictionary(&path_str) { 1 } else { 0 }
}

/// FFI: Load a domain dictionary. Pass empty string to unload.
#[no_mangle]
pub extern "C" fn load_domain_dictionary(path: *const c_char) -> i8 {
    let path_str = unsafe { CStr::from_ptr(path) }.to_string_lossy();
    if dictionary::load_domain_dictionary(&path_str) { 1 } else { 0 }
}

/// FFI: Look up a word. Returns JSON string (caller must free).
#[no_mangle]
pub extern "C" fn lookup_word(word: *const c_char) -> *mut c_char {
    let word_str = unsafe { CStr::from_ptr(word) }.to_string_lossy();
    let result = dictionary::lookup(&word_str);
    CString::new(result).unwrap().into_raw()
}

/// FFI: Lemmatize a word. Returns the lemma.
#[no_mangle]
pub extern "C" fn lemmatize(word: *const c_char) -> *mut c_char {
    let word_str = unsafe { CStr::from_ptr(word) }.to_string_lossy();
    let result = dictionary::lemmatize(&word_str);
    CString::new(result).unwrap().into_raw()
}
