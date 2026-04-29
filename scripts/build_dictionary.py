#!/usr/bin/env python3
"""Build the HUMAID SOUL dictionary from WordNet and GCIDE.

This script runs in GitHub Actions and produces soul_dict.db
which is then Zstandard-compressed for distribution.
"""

def main():
    print("Dictionary builder: not yet implemented.")
    # 1. Download WordNet 3.1
    # 2. Download GCIDE XML
    # 3. Parse and insert into SQLite
    # 4. Apply safe filters
    # 5. Output soul_dict.db
    pass

if __name__ == '__main__':
    main()
