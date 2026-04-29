use once_cell::sync::OnceCell;
use rusqlite::{params, Connection};
use serde::Serialize;
use std::io::Read;
use std::sync::Mutex;

// Global dictionary connection protected by a mutex.
static DICTIONARY: OnceCell<Mutex<Connection>> = OnceCell::new();

/// Load the dictionary from a Zstandard‑compressed SQLite file.
/// Decompresses the file, writes a temporary SQLite database,
/// opens a connection, and stores it in the global dictionary.
pub fn load_dictionary(path_zst: &str) -> bool {
    // Read compressed file.
    let mut file = match std::fs::File::open(path_zst) {
        Ok(f) => f,
        Err(e) => {
            log::error!("Failed to open dictionary file: {}", e);
            return false;
        }
    };

    let mut compressed = Vec::new();
    if file.read_to_end(&mut compressed).is_err() {
        return false;
    }

    // Decompress using streaming decoder.
    let mut decoder = match zstd::stream::Decoder::new(&compressed[..]) {
        Ok(d) => d,
        Err(e) => {
            log::error!("Failed to create Zstd decoder: {}", e);
            return false;
        }
    };

    let mut decompressed = Vec::new();
    if decoder.read_to_end(&mut decompressed).is_err() {
        return false;
    }

    // Write temporary file (Android's /tmp is writable).
    let temp_path = "/tmp/soul_dict_temp.db";
    if std::fs::write(temp_path, &decompressed).is_err() {
        return false;
    }

    let conn = match Connection::open(temp_path) {
        Ok(c) => c,
        Err(e) => {
            log::error!("Failed to open temporary dictionary DB: {}", e);
            return false;
        }
    };

    // Enable WAL mode for concurrent reads (not strictly needed with Mutex but harmless).
    conn.execute_batch("PRAGMA journal_mode=WAL;").ok();

    DICTIONARY.set(Mutex::new(conn)).is_ok()
}

#[derive(Serialize)]
struct WordEntry {
    word: String,
    word_type: String,
    definitions: Vec<String>,
    synonyms: Vec<String>,
}

/// Look up a word: direct match → lemma → fuzzy fallback.
pub fn lookup(word: &str) -> String {
    let guard = match DICTIONARY.get() {
        Some(m) => m.lock().unwrap(),
        None => return "[]".to_string(),
    };
    let conn = &*guard;

    if let Some(entry) = direct_lookup(conn, word) {
        return serde_json::to_string(&entry).unwrap_or_default();
    }

    let lemma = lemmatize_impl(conn, word);
    if lemma != word {
        if let Some(entry) = direct_lookup(conn, &lemma) {
            return serde_json::to_string(&entry).unwrap_or_default();
        }
    }

    let candidates = fuzzy_impl(conn, word, 1);
    if let Some(candidate) = candidates.first() {
        if let Some(entry) = direct_lookup(conn, candidate) {
            return serde_json::to_string(&entry).unwrap_or_default();
        }
    }

    "[]".to_string()
}

/// Return the lemma (base form) of a given word.
pub fn lemmatize(word: &str) -> String {
    let guard = match DICTIONARY.get() {
        Some(m) => m.lock().unwrap(),
        None => return word.to_string(),
    };
    lemmatize_impl(&*guard, word)
}

/// Fuzzy search: returns up to `max_results` closest matches.
pub fn fuzzy_search(word: &str, max_results: usize) -> String {
    let guard = match DICTIONARY.get() {
        Some(m) => m.lock().unwrap(),
        None => return "[]".to_string(),
    };
    let matches = fuzzy_impl(&*guard, word, max_results);
    serde_json::to_string(&matches).unwrap_or_default()
}

// ---------------------------------------------------------------------------
// Internal helpers (expect a concrete &Connection)
// ---------------------------------------------------------------------------

fn direct_lookup(conn: &Connection, word: &str) -> Option<WordEntry> {
    let mut stmt = conn
        .prepare(
            "SELECT w.word, w.word_type, d.definition, s.synonym
             FROM words w
             LEFT JOIN definitions d ON w.id = d.word_id
             LEFT JOIN synonyms s ON w.id = s.word_id
             WHERE w.word = ?1 COLLATE NOCASE",
        )
        .ok()?;

    let rows = stmt
        .query_map(params![word], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, Option<String>>(1)?,
                row.get::<_, Option<String>>(2)?,
                row.get::<_, Option<String>>(3)?,
            ))
        })
        .ok()?;

    let mut word_name = String::new();
    let mut word_type = String::new();
    let mut definitions: Vec<String> = Vec::new();
    let mut synonyms: Vec<String> = Vec::new();

    for row in rows.flatten() {
        word_name = row.0;
        word_type = row.1.unwrap_or_default();
        if let Some(def) = row.2 {
            if !definitions.contains(&def) {
                definitions.push(def);
            }
        }
        if let Some(syn) = row.3 {
            if syn != word_name && !synonyms.contains(&syn) {
                synonyms.push(syn);
            }
        }
    }

    if word_name.is_empty() {
        return None;
    }

    Some(WordEntry {
        word: word_name,
        word_type,
        definitions,
        synonyms,
    })
}

fn lemmatize_impl(conn: &Connection, word: &str) -> String {
    match conn.query_row(
        "SELECT lemma FROM lemma_map WHERE inflected = ?1",
        params![word],
        |row| row.get::<_, String>(0),
    ) {
        Ok(lemma) => lemma,
        Err(_) => word.to_string(),
    }
}

fn fuzzy_impl(conn: &Connection, word: &str, max_results: usize) -> Vec<String> {
    let first_char = word
        .chars()
        .next()
        .map(|c| format!("{}%", c))
        .unwrap_or_else(|| "%".to_string());

    let mut stmt = conn
        .prepare("SELECT DISTINCT word FROM words WHERE word LIKE ?1 LIMIT 200")
        .unwrap();

    let candidates: Vec<String> = stmt
        .query_map(params![first_char], |row| row.get::<_, String>(0))
        .unwrap()
        .flatten()
        .collect();

    let mut scored: Vec<(f64, String)> = candidates
        .into_iter()
        .map(|candidate| {
            let dist =
                strsim::normalized_levenshtein(&word.to_lowercase(), &candidate.to_lowercase());
            (dist, candidate)
        })
        .collect();

    scored.sort_by(|a, b| b.0.partial_cmp(&a.0).unwrap_or(std::cmp::Ordering::Equal));
    scored.truncate(max_results);
    scored.into_iter().map(|(_, w)| w).collect()
}
