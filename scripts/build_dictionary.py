#!/usr/bin/env python3
"""
HUMAID SOUL – Reliable Dictionary Builder

Downloads WordNet 3.1 database files directly, parses them,
and creates soul_dict.db with:
  words(word, word_type)
  definitions(word_id, definition)
  synonyms(word_id, synonym)
  lemma_map(inflected, lemma) – basic irregulars
"""

import sqlite3
import os
import urllib.request
import shutil
import sys

# ------------------------------------------------------------
# CONFIG
# ------------------------------------------------------------
WORDNET_URL = "https://github.com/globalwordnet/english-wordnet/raw/refs/heads/main/src/wn31/"
FILES = {
    "data.noun": "noun",
    "data.verb": "verb",
    "data.adj": "adj",
    "data.adv": "adv",
}

DB_PATH = "soul_dict.db"

# ------------------------------------------------------------
# SCHEMA
# ------------------------------------------------------------
SCHEMA = """
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
"""

# Common irregular forms (English) – just enough to get started
IRREGULARS = {
    "children": "child", "went": "go", "better": "good", "best": "good",
    "ran": "run", "running": "run", "took": "take", "taken": "take",
    "mice": "mouse", "geese": "goose", "feet": "foot", "teeth": "tooth",
    "sang": "sing", "sung": "sing", "written": "write", "wrote": "write",
    "broken": "break", "broke": "break", "spoke": "speak", "spoken": "speak",
    "driven": "drive", "drove": "drive", "eaten": "eat", "ate": "eat",
    "given": "give", "men": "man", "women": "woman",
}

# ------------------------------------------------------------
# PARSERS
# ------------------------------------------------------------
def download_file(url, dest):
    print(f"  Downloading {url} ...")
    try:
        urllib.request.urlretrieve(url, dest)
    except Exception as e:
        print(f"  ERROR: {e}")
        sys.exit(1)

def parse_wordnet_file(filepath, pos):
    """
    Parse WordNet data file.
    Each line starting with a synset offset.
    Format: offset  lex_filenum  ss_type  w_cnt  words  ...  |  gloss
    We'll extract: words (lemma), synonyms, and definition (after |).
    """
    data = []
    with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith(" "):
                continue
            # Split at gloss separator
            parts = line.split(" | ")
            if len(parts) < 2:
                gloss = ""
                meta = parts[0]
            else:
                meta = parts[0]
                gloss = parts[1]

            # Parse meta part
            fields = meta.split()
            if len(fields) < 6:
                continue
            synset_offset = fields[0]
            lex_filenum = fields[1]
            ss_type = fields[2]
            w_cnt = int(fields[3], 16)  # hex word count
            # Next w_cnt fields are words (space separated)
            idx = 4
            words = []
            for _ in range(w_cnt):
                if idx >= len(fields):
                    break
                word = fields[idx]
                # Word may be followed by lex_id
                # Remove _suffix if any (e.g., "lemma%1")
                lemma = word.split("%")[0] if "%" in word else word
                words.append(lemma)
                idx += 1

            if not words:
                continue

            data.append({
                "words": words,
                "definition": gloss.strip('" ').split(";")[0].strip(),
                "pos": pos,
                "synonyms": words,  # all words in synset are synonyms
            })
    return data

# ------------------------------------------------------------
# DATABASE BUILD
# ------------------------------------------------------------
def build_database():
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)

    conn = sqlite3.connect(DB_PATH)
    conn.executescript(SCHEMA)

    # Insert irregular lemma mappings
    for inflected, lemma in IRREGULARS.items():
        conn.execute(
            "INSERT OR IGNORE INTO lemma_map(inflected, lemma) VALUES (?, ?)",
            (inflected, lemma)
        )
    print(f"Inserted {len(IRREGULARS)} irregular lemma mappings.")

    # Download & parse each file
    temp_dir = "/tmp/wordnet_build"
    os.makedirs(temp_dir, exist_ok=True)

    word_id_cache = {}  # word -> id
    for fname, pos in FILES.items():
        print(f"Processing {fname} ({pos})...")
        local_path = os.path.join(temp_dir, fname)
        download_file(WORDNET_URL + fname, local_path)
        entries = parse_wordnet_file(local_path, pos)
        print(f"  Found {len(entries)} synsets.")

        for entry in entries:
            # Insert words
            word_ids = []
            for lemma in entry["words"]:
                if lemma not in word_id_cache:
                    conn.execute(
                        "INSERT OR IGNORE INTO words(word, word_type) VALUES (?, ?)",
                        (lemma, pos)
                    )
                    c = conn.execute("SELECT id FROM words WHERE word=?", (lemma,))
                    row = c.fetchone()
                    if row:
                        word_id_cache[lemma] = row[0]
                    else:
                        continue
                word_ids.append(word_id_cache[lemma])

            # Insert definition
            if entry["definition"]:
                for wid in word_ids:
                    conn.execute(
                        "INSERT INTO definitions(word_id, definition) VALUES (?, ?)",
                        (wid, entry["definition"])
                    )

            # Insert synonyms (all words in synset)
            if len(word_ids) > 1:
                for wid in word_ids:
                    for other_lemma, other_wid in zip(entry["words"], word_ids):
                        if other_wid != wid:
                            conn.execute(
                                "INSERT OR IGNORE INTO synonyms(word_id, synonym) VALUES (?, ?)",
                                (wid, entry["words"][word_ids.index(other_wid)])
                            )

        conn.commit()

    # Cleanup temporary files
    shutil.rmtree(temp_dir, ignore_errors=True)
    conn.close()
    print(f"Dictionary built successfully: {DB_PATH}")
    print(f"Total unique words: {len(word_id_cache)}")

if __name__ == "__main__":
    build_database()
