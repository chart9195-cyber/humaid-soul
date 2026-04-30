#!/usr/bin/env python3
"""
HUMAID SOUL Dictionary Forge – NLTK WordNet edition
Generates soul_dict.db with definitions, synonyms, word types, and lemma mapping.
Caches NLTK data in ~/nltk_data (GitHub Actions cache will keep it).
"""

import sqlite3, os, sys

# Ensure NLTK and data are available
try:
    import nltk
except ImportError:
    print("Installing NLTK…")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "nltk"])
    import nltk

# Set NLTK data path to a cacheable location
NLTK_DATA = os.path.expanduser("~/nltk_data")
os.makedirs(NLTK_DATA, exist_ok=True)
nltk.data.path.insert(0, NLTK_DATA)

# Download WordNet once
try:
    nltk.download('wordnet', download_dir=NLTK_DATA, quiet=False)
except Exception as e:
    print(f"Failed to download WordNet: {e}")
    sys.exit(1)

try:
    nltk.download('omw-1.4', download_dir=NLTK_DATA, quiet=True)
except:
    pass  # optional

from nltk.corpus import wordnet as wn

DB_PATH = "soul_dict.db"

IRREGULARS = {
    "children": "child", "went": "go", "better": "good", "best": "good",
    "ran": "run", "running": "run", "took": "take", "taken": "take",
    "mice": "mouse", "geese": "goose", "feet": "foot", "teeth": "tooth",
    "sang": "sing", "sung": "sing", "written": "write", "wrote": "write",
    "broken": "break", "broke": "break", "spoke": "speak", "spoken": "speak",
    "driven": "drive", "drove": "drive", "eaten": "eat", "ate": "eat",
    "given": "give", "men": "man", "women": "woman",
}

def safe_level(definition: str) -> int:
    low = definition.lower()
    if any(bad in low for bad in ["vulgar", "obscene", "offensive slang", "sexual intercourse"]):
        return 3  # skip entirely
    if "sexual" in low or "erotic" in low:
        return 2
    return 1

def build():
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)

    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.executescript("""
        CREATE TABLE words (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word TEXT NOT NULL COLLATE NOCASE,
            word_type TEXT
        );
        CREATE UNIQUE INDEX idx_word ON words(word);
        CREATE TABLE definitions (
            word_id INTEGER NOT NULL,
            definition TEXT NOT NULL,
            source TEXT DEFAULT 'wordnet',
            safe_level INTEGER DEFAULT 1,
            FOREIGN KEY(word_id) REFERENCES words(id)
        );
        CREATE TABLE synonyms (
            word_id INTEGER NOT NULL,
            synonym TEXT NOT NULL COLLATE NOCASE,
            FOREIGN KEY(word_id) REFERENCES words(id)
        );
        CREATE TABLE lemma_map (
            inflected TEXT PRIMARY KEY,
            lemma TEXT NOT NULL
        ) WITHOUT ROWID;
    """)

    # Irregular lemma map
    for inf, lem in IRREGULARS.items():
        conn.execute("INSERT OR IGNORE INTO lemma_map(inflected, lemma) VALUES(?,?)", (inf, lem))

    word_ids = {}
    synsets = list(wn.all_synsets())
    total = len(synsets)
    for i, synset in enumerate(synsets):
        pos = synset.pos()  # n, v, a, r, s
        if pos == 's':
            pos = 'a'  # satellite adjective -> adjective
        gloss = synset.definition()
        sl = safe_level(gloss)
        if sl == 3:
            continue  # skip inappropriate

        for lemma in synset.lemmas():
            word = lemma.name().replace('_', ' ')
            if word not in word_ids:
                conn.execute("INSERT OR IGNORE INTO words(word, word_type) VALUES(?,?)", (word, pos))
                cur = conn.execute("SELECT id FROM words WHERE word=?", (word,))
                row = cur.fetchone()
                if row:
                    word_ids[word] = row[0]
                else:
                    continue
            wid = word_ids[word]

            conn.execute("INSERT OR IGNORE INTO definitions(word_id, definition, source, safe_level) VALUES(?,?,?,?)",
                         (wid, gloss, 'wordnet', sl))

            # synonyms: all other lemmas in same synset
            for other in synset.lemmas():
                other_name = other.name().replace('_', ' ')
                if other_name != word:
                    conn.execute("INSERT OR IGNORE INTO synonyms(word_id, synonym) VALUES(?,?)", (wid, other_name))

        if i % 5000 == 0:
            print(f"Progress: {i}/{total} synsets")
            conn.commit()

    conn.commit()
    conn.close()
    print(f"Dictionary built: {DB_PATH}")
    print(f"Unique words: {len(word_ids)}")

if __name__ == "__main__":
    build()
