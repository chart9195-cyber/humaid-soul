#!/usr/bin/env python3
"""
HUMAID SOUL – Reliable Dictionary Builder (v2)

Downloads the WordNet 3.1 database files from Princeton's official site,
parses them, and creates soul_dict.db.
"""

import sqlite3
import os
import urllib.request
import tarfile
import sys
import shutil

# ------------------------------------------------------------
# CONFIG
# ------------------------------------------------------------
WORDNET_URL = "https://wordnetcode.princeton.edu/wn3.1.dict.tar.gz"
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
# DOWNLOAD & EXTRACT
# ------------------------------------------------------------
def download_and_extract(url, dest_dir):
    print(f"Downloading WordNet database from {url}...")
    tar_path = os.path.join(dest_dir, "wn3.1.dict.tar.gz")
    urllib.request.urlretrieve(url, tar_path)
    print("Extracting...")
    with tarfile.open(tar_path, "r:gz") as tar:
        tar.extractall(dest_dir)
    os.remove(tar_path)

# ------------------------------------------------------------
# PARSER
# ------------------------------------------------------------
def parse_wordnet_file(filepath, pos):
    """
    Each line example:
    00001740 03 n 01 entity 0 006 @ 00002098 n 0000 ~ 02153675 n 0000 | that which is perceived...
    We need the words (lemma), definition (gloss after '|'), and synonyms (all lemmas in line).
    """
    entries = []
    with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith(" "):
                continue
            parts = line.split(" | ")
            if len(parts) < 2:
                continue
            gloss = parts[1].strip('" ;')
            meta = parts[0].split()
            if len(meta) < 6:
                continue
            # w_cnt is hex at index 3
            try:
                w_cnt = int(meta[3], 16)
            except ValueError:
                continue
            words = []
            idx = 4
            for _ in range(w_cnt):
                if idx >= len(meta):
                    break
                raw_word = meta[idx]
                # Format: lemma%lex_id (e.g., entity%0)
                lemma = raw_word.split("%")[0]
                words.append(lemma)
                idx += 1
                # Skip optional lex_id after word? Actually meta[idx] is next word or other fields.
            if not words:
                continue
            entries.append({
                "words": words,
                "definition": gloss,
                "pos": pos,
            })
    return entries

# ------------------------------------------------------------
# DATABASE BUILD
# ------------------------------------------------------------
def build_database():
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)

    conn = sqlite3.connect(DB_PATH)
    conn.executescript(SCHEMA)

    # Insert irregulars
    for inf, lem in IRREGULARS.items():
        conn.execute("INSERT OR IGNORE INTO lemma_map(inflected, lemma) VALUES (?,?)", (inf, lem))
    print(f"Inserted {len(IRREGULARS)} irregular lemma mappings.")

    temp_dir = "/tmp/wordnet_build"
    if os.path.exists(temp_dir):
        shutil.rmtree(temp_dir)
    os.makedirs(temp_dir)

    download_and_extract(WORDNET_URL, temp_dir)
    dict_dir = os.path.join(temp_dir, "dict")
    if not os.path.isdir(dict_dir):
        print("Error: dict directory not found after extraction.")
        sys.exit(1)

    files = {
        "data.noun": "noun",
        "data.verb": "verb",
        "data.adj": "adj",
        "data.adv": "adv",
    }

    word_id_cache = {}
    for fname, pos in files.items():
        fpath = os.path.join(dict_dir, fname)
        if not os.path.exists(fpath):
            print(f"Warning: {fpath} missing, skipping.")
            continue
        print(f"Parsing {fname} ({pos})...")
        synsets = parse_wordnet_file(fpath, pos)
        print(f"  Found {len(synsets)} synsets.")
        for syn in synsets:
            # Insert words
            wids = []
            for lemma in syn["words"]:
                if lemma not in word_id_cache:
                    conn.execute("INSERT OR IGNORE INTO words(word, word_type) VALUES (?,?)", (lemma, pos))
                    cur = conn.execute("SELECT id FROM words WHERE word=?", (lemma,))
                    row = cur.fetchone()
                    if row:
                        word_id_cache[lemma] = row[0]
                    else:
                        # duplicate somehow? should not happen
                        continue
                wids.append(word_id_cache[lemma])
            # Insert definition for each word
            if syn["definition"]:
                for wid in wids:
                    conn.execute("INSERT OR IGNORE INTO definitions(word_id, definition) VALUES (?,?)",
                                (wid, syn["definition"]))
            # Synonyms: all other words in the same synset
            for i, wid in enumerate(wids):
                for j, other_lemma in enumerate(syn["words"]):
                    if j != i:
                        conn.execute("INSERT OR IGNORE INTO synonyms(word_id, synonym) VALUES (?,?)",
                                    (wid, other_lemma))
        conn.commit()

    shutil.rmtree(temp_dir)
    conn.close()
    print(f"Dictionary built: {DB_PATH}")
    print(f"Total unique words: {len(word_id_cache)}")

if __name__ == "__main__":
    build_database()
