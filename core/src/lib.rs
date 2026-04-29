pub mod dictionary;
pub mod pdf_extract;

use std::ffi::{CStr, CString};
use std::os::raw::c_char;

// ------------------------------------------------------------
// C-compatible wrappers for Flutter FFI
// ------------------------------------------------------------

/// Initialise the engine with a path to soul_dict.db.zst
#[no_mangle]
pub extern "C" fn init_engine_ffi(path: *const c_char) -> i32 {
    if path.is_null() {
        return -1;
    }
    let c_str = unsafe { CStr::from_ptr(path) };
    let path_str = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => return -1,
    };
    if dictionary::load_dictionary(path_str) {
        0
    } else {
        -1
    }
}

/// Look up a word – returns JSON string (caller must free with free_string_ffi)
#[no_mangle]
pub extern "C" fn lookup_word_ffi(word: *const c_char) -> *mut c_char {
    if word.is_null() {
        return CString::new("[]").unwrap().into_raw();
    }
    let c_str = unsafe { CStr::from_ptr(word) };
    let word_str = c_str.to_str().unwrap_or("");
    let result = dictionary::lookup(word_str);
    CString::new(result).unwrap().into_raw()
}

/// Lemmatize a word – returns lemma (caller must free)
#[no_mangle]
pub extern "C" fn lemmatize_ffi(word: *const c_char) -> *mut c_char {
    if word.is_null() {
        return CString::new("").unwrap().into_raw();
    }
    let c_str = unsafe { CStr::from_ptr(word) };
    let word_str = c_str.to_str().unwrap_or("");
    let lemma = dictionary::lemmatize(word_str);
    CString::new(lemma).unwrap().into_raw()
}

/// Fuzzy search – returns JSON array (caller must free)
#[no_mangle]
pub extern "C" fn fuzzy_search_ffi(word: *const c_char, max_results: i32) -> *mut c_char {
    if word.is_null() {
        return CString::new("[]").unwrap().into_raw();
    }
    let c_str = unsafe { CStr::from_ptr(word) };
    let word_str = c_str.to_str().unwrap_or("");
    let max = if max_results > 0 { max_results as usize } else { 5 };
    let result = dictionary::fuzzy_search(word_str, max);
    CString::new(result).unwrap().into_raw()
}

/// Free a string that was returned by the above functions
#[no_mangle]
pub extern "C" fn free_string_ffi(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        let _ = CString::from_raw(ptr);
    };
}
