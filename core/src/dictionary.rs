use once_cell::sync::OnceCell;
use rusqlite::{params, Connection};
use serde::Serialize;
use std::io::Read;
use std::path::Path;

static DICTIONARY: OnceCell<Connection> = OnceCell::new();

/// Load the dictionary from a Zstd‑compressed SQLite file.
/// Decompresses into memory (or temp file) and opens the SQLite database.
pub fn load_dictionary(path_zst: &str) -> bool {
    // Read the compressed file
    let mut reader = match std::fs::File::open(path_zst) {
        Ok(f) => f,
        Err(e) => {
            log::error!("Failed to open dictionary file: {}", e);
            return false;
        }
    };
    let mut compressed = Vec::new();
    if reader.read_to_end(&mut compressed).is_err() {
        return false;
    }

    // Decompress Zstd
    let mut decoder = zstd::Decoder::new(&compressed[..]).unwrap();
    let mut decompressed = Vec::new();
    if decoder.read_to_end(&mut decompressed).is_err() {
        return false;
    }

    // Open in‑memory SQLite connection
    let conn = match Connection::open_in_memory() {
        Ok(c) => c,
        Err(e) => {
            log::error!("Failed to create in‑memory DB: {}", e);
            return false;
        }
    };

    // Restore the decompressed database into memory
    // Use SQLite backup API (rusqlite doesn't expose direct backup, we can use a workaround)
    // Alternative: write decompressed to temp file and open; simpler.
    let temp_path = "/tmp/soul_dict_temp.db"; // Android has writable tmp
    if std::fs::write(temp_path, &decompressed).is_err() {
        return false;
    }
    let conn = match Connection::open(temp_path) {
        Ok(c) => c,
        Err(e) => {
            log::error!("Failed to open temp DB: {}", e);
            return false;
        }
    };

    // Enable WAL mode for concurrency
    conn.execute_batch("PRAGMA journal_mode=WAL;").ok();

    DICTIONARY.set(conn).is_ok()
}

#[derive(Serialize)]
struct WordEntry {
    word: String,
    word_type: String,
    definitions: Vec<String>,
    synonyms: Vec<String>,
}

/// Look up a word – first direct, then lemma, then fuzzy.
pub fn lookup(word: &str) -> String {
    let conn = match DICTIONARY.get() {
        Some(c) => c,
        None => return "[]".to_string(),
    };

    // 1. Direct lookup
    if let Some(entry) = direct_lookup(conn, word) {
        return serde_json::to_string(&entry).unwrap_or_default();
    }

    // 2. Lemmatize
    let lemma = lemmatize_impl(conn, word);
    if lemma != word {
        if let Some(entry) = direct_lookup(conn, &lemma) {
            return serde_json::to_string(&entry).unwrap_or_default();
        }
    }

    // 3. Fuzzy fallback
    let candidates = fuzzy_impl(conn, word, 1);
    if let Some(candidate) = candidates.first() {
        if let Some(entry) = direct_lookup(conn, candidate) {
            return serde_json::to_string(&entry).unwrap_or_default();
        }
    }

    "[]".to_string()
}

/// Return lemma of a word.
pub fn lemmatize(word: &str) -> String {
    let conn = match DICTIONARY.get() {
        Some(c) => c,
        None => return word.to_string(),
    };
    lemmatize_impl(conn, word)
}

/// Fuzzy search returning up to max_results close matches.
pub fn fuzzy_search(word: &str, max_results: usize) -> String {
    let conn = match DICTIONARY.get() {
        Some(c) => c,
        None => return "[]".to_string(),
    };
    let matches = fuzzy_impl(conn, word, max_results);
    serde_json::to_string(&matches).unwrap_or_default()
}

// ---- Internal helpers ----

fn direct_lookup(conn: &Connection, word: &str) -> Option<WordEntry> {
    let mut stmt = conn.prepare(
        "SELECT w.word, w.word_type, d.definition, s.synonym
         FROM words w
         LEFT JOIN definitions d ON w.id = d.word_id
         LEFT JOIN synonyms s ON w.id = s.word_id
         WHERE w.word = ?1 COLLATE NOCASE"
    ).ok()?;

    let rows = stmt.query_map(params![word], |row| {
        Ok((
            row.get::<_, String>(0)?,
            row.get::<_, Option<String>>(1)?,
            row.get::<_, Option<String>>(2)?,
            row.get::<_, Option<String>>(3)?,
        ))
    }).ok()?;

    let mut word_name = String::new();
    let mut word_type = String::new();
    let mut definitions = Vec::new();
    let mut synonyms = Vec::new();

    for row in rows.flatten() {
        word_name = row.0;
        word_type = row.1.unwrap_or_default();
        if let Some(def) = row.2 {
            if !definitions.contains(&def) { definitions.push(def); }
        }
        if let Some(syn) = row.3 {
            if syn != word_name && !synonyms.contains(&syn) { synonyms.push(syn); }
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
    // Check lemma_map table
    let mut stmt = conn.prepare("SELECT lemma FROM lemma_map WHERE inflected = ?1").ok();
    if let Some(s) = stmt {
        if let Ok(lemma) = s.query_row(params![word], |row| row.get::<_, String>(0)) {
            return lemma;
        }
    }
    // If not found, attempt a simple suffix‑based stem (university → univers) – too aggressive,
    // so return original word. We rely on lemma_map for now.
    word.to_string()
}

fn fuzzy_impl(conn: &Connection, word: &str, max_results: usize) -> Vec<String> {
    // Fetch up to 200 candidate words starting with the same first letter for performance.
    let first_char = word.chars().next().map(|c| format!("{}%", c)).unwrap_or("%".to_string());
    let mut stmt = conn.prepare(
        "SELECT DISTINCT word FROM words WHERE word LIKE ?1 LIMIT 200"
    ).unwrap();
    let candidates: Vec<String> = stmt
        .query_map(params![first_char], |row| row.get::<_, String>(0))
        .unwrap()
        .flatten()
        .collect();

    let mut scored: Vec<(f64, String)> = candidates
        .into_iter()
        .map(|candidate| {
            // Use normalized Levenshtein distance (1 - normalised) for similarity
            let dist = strsim::normalized_levenshtein(&word.to_lowercase(), &candidate.to_lowercase());
            (dist, candidate)
        })
        .collect();

    scored.sort_by(|a, b| b.0.partial_cmp(&a.0).unwrap());
    scored.truncate(max_results);
    scored.into_iter().map(|(_, w)| w).collect()
}
