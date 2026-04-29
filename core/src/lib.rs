pub mod dictionary;
pub mod pdf_extract;

use std::path::Path;

/// Initialise the core engine: load dictionary from a compressed .zst file.
/// `dict_path_zst` is the path to soul_dict.db.zst.
/// Returns true on success.
pub fn init_engine(dict_path_zst: &str) -> bool {
    dictionary::load_dictionary(dict_path_zst)
}

/// Look up a word. Returns a JSON string with the word's details or empty array.
pub fn lookup_word(word: &str) -> String {
    dictionary::lookup(word)
}

/// Lemmatize a word (e.g., "running" -> "run").
pub fn lemmatize(word: &str) -> String {
    dictionary::lemmatize(word)
}

/// Fuzzy search for a word (e.g., "recieve" -> ["receive", "receiver", ...]).
pub fn fuzzy_search(word: &str, max_results: usize) -> String {
    dictionary::fuzzy_search(word, max_results)
}

/// (Future) Extract all words with positions from a PDF page.
pub fn extract_page_words(pdf_path: &str, page_num: u32) -> String {
    pdf_extract::extract_page_words(pdf_path, page_num)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_placeholder() {
        // Will require an actual dictionary file in the test environment.
        // For now just check that the module loads.
        assert!(true);
    }
}
