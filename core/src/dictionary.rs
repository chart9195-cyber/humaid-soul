use once_cell::sync::OnceCell;
use rusqlite::{params, Connection};
use serde::Serialize;
use std::io::Read;
use std::path::Path;
use std::sync::Mutex;

static DICTIONARY: OnceCell<Mutex<Connection>> = OnceCell::new();
static DOMAIN_DICTIONARY: OnceCell<Mutex<Option<Connection>>> = OnceCell::new();

/// Load primary (WordNet) dictionary from compressed .zst file.
pub fn load_dictionary(path_zst: &str) -> bool {
    let conn = decompress_and_open(path_zst);
    match conn {
        Some(c) => {
            c.execute_batch("PRAGMA journal_mode=WAL;").ok();
            DICTIONARY.set(Mutex::new(c)).is_ok()
        }
        None => false,
    }
}

/// Load a secondary domain dictionary (Medical, Legal, etc.).
/// Call with an empty string or invalid path to unload.
pub fn load_domain_dictionary(path_zst: &str) -> bool {
    if path_zst.is_empty() {
        // Unload domain dictionary
        if let Some(mutex) = DOMAIN_DICTIONARY.get() {
            if let Ok(mut opt) = mutex.lock() {
                *opt = None;
            }
        }
        return true;
    }

    let conn = decompress_and_open(path_zst);
    match conn {
        Some(c) => {
            c.execute_batch("PRAGMA journal_mode=WAL;").ok();
            if DOMAIN_DICTIONARY.get().is_none() {
                DOMAIN_DICTIONARY.set(Mutex::new(Some(c))).is_ok()
            } else {
                if let Some(mutex) = DOMAIN_DICTIONARY.get() {
                    if let Ok(mut opt) = mutex.lock() {
                        *opt = Some(c);
                        true
                    } else {
                        false
                    }
                } else {
                    false
                }
            }
        }
        None => false,
    }
}

fn decompress_and_open(path_zst: &str) -> Option<Connection> {
    let mut file = std::fs::File::open(path_zst).ok()?;
    let mut compressed = Vec::new();
    file.read_to_end(&mut compressed).ok()?;
    let mut decoder = zstd::stream::Decoder::new(&compressed[..]).ok()?;
    let mut decompressed = Vec::new();
    decoder.read_to_end(&mut decompressed).ok()?;

    let zst_path = Path::new(path_zst);
    let dir = zst_path.parent().unwrap_or_else(|| Path::new("."));
    let db_path = dir.join(format!("{}_temp.db", zst_path.file_stem()?.to_str()?));

    std::fs::write(&db_path, &decompressed).ok()?;
    let conn = Connection::open(&db_path).ok()?;
    Some(conn)
}

#[derive(Serialize)]
struct WordEntry {
    word: String,
    word_type: String,
    definitions: Vec<String>,
    synonyms: Vec<String>,
}

pub fn lookup(word: &str) -> String {
    // Check domain dictionary first
    let domain_result = if let Some(mutex) = DOMAIN_DICTIONARY.get() {
        if let Ok(opt) = mutex.lock() {
            if let Some(conn) = opt.as_ref() {
                direct_lookup(conn, word)
            } else {
                None
            }
        } else {
            None
        }
    } else {
        None
    };

    if let Some(entry) = domain_result {
        return serde_json::to_string(&entry).unwrap_or_default();
    }

    // Fall back to main dictionary
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

pub fn lemmatize(word: &str) -> String {
    let guard = match DICTIONARY.get() {
        Some(m) => m.lock().unwrap(),
        None => return word.to_string(),
    };
    lemmatize_impl(&*guard, word)
}

pub fn fuzzy_search(word: &str, max_results: usize) -> String {
    let guard = match DICTIONARY.get() {
        Some(m) => m.lock().unwrap(),
        None => return "[]".to_string(),
    };
    let matches = fuzzy_impl(&*guard, word, max_results);
    serde_json::to_string(&matches).unwrap_or_default()
}

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
    if let Ok(lemma) = conn.query_row(
        "SELECT lemma FROM lemma_map WHERE inflected = ?1",
        params![word],
        |row| row.get::<_, String>(0),
    ) {
        return lemma;
    }
    let lower = word.to_lowercase();
    let stemmed = english_regular_stem(&lower);
    if stemmed != lower {
        let exists: bool = conn
            .query_row(
                "SELECT COUNT(*) FROM words WHERE word = ?1",
                params![stemmed],
                |row| row.get::<_, i64>(0),
            )
            .map(|c| c > 0)
            .unwrap_or(false);
        if exists {
            return stemmed;
        }
    }
    word.to_string()
}

fn english_regular_stem(word: &str) -> String {
    let suffixes = [
        ("nesses", ""),
        ("ingly", ""),
        ("ations", "ate"),
        ("tions", "t"),
        ("sses", "ss"),
        ("ships", "ship"),
        ("ments", "ment"),
        ("ness", ""),
        ("ing", ""),
        ("ed", ""),
        ("s", ""),
        ("ied", "y"),
        ("ves", "f"),
    ];
    for (suffix, replacement) in suffixes.iter() {
        if word.ends_with(suffix) && word.len() > suffix.len() + 1 {
            return format!("{}{}", &word[..word.len() - suffix.len()], replacement);
        }
    }
    word.to_string()
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
            let dist = strsim::normalized_levenshtein(
                &word.to_lowercase(),
                &candidate.to_lowercase(),
            );
            (dist, candidate)
        })
        .collect();
    scored.sort_by(|a, b| b.0.partial_cmp(&a.0).unwrap_or(std::cmp::Ordering::Equal));
    scored.truncate(max_results);
    scored.into_iter().map(|(_, w)| w).collect()
}
