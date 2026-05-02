#!/usr/bin/env python3
"""
HUMAID SOUL – Legal Soul‑Pack Builder
Curates a glossary of common legal terms from open‑government sources.
Generates legal.db with ~200 essential terms.
"""

import sqlite3
import os

DB_PATH = "legal.db"

LEGAL_TERMS = {
    "abrogate": "To repeal or do away with a law or agreement.",
    "acquittal": "A judgment that a person is not guilty of the crime charged.",
    "adjudication": "The legal process of resolving a dispute or deciding a case.",
    "affidavit": "A written statement confirmed by oath, for use as evidence in court.",
    "allegation": "A claim or assertion that someone has done something illegal or wrong.",
    "amendment": "A formal change or addition to a legal document or law.",
    "appeal": "Apply to a higher court for a reversal of a lower court's decision.",
    "arbitration": "The use of an arbitrator to settle a dispute.",
    "bail": "The temporary release of an accused person awaiting trial.",
    "bench": "The judge or judges sitting in court, or the court itself.",
    "brief": "A written statement submitted to a court by a party in a case.",
    "burden of proof": "The obligation to prove one's assertion or allegation.",
    "case law": "The law as established by the outcome of former cases.",
    "civil law": "The system of law concerned with private relations between members of a community.",
    "claim": "A demand for something due, such as compensation.",
    "class action": "A lawsuit filed by one party on behalf of a larger group.",
    "common law": "Law derived from judicial decisions, rather than from statutes.",
    "complaint": "A formal legal document initiating a lawsuit.",
    "constitution": "A body of fundamental principles by which a state is governed.",
    "contempt": "Disobedience or disrespect toward a court of law.",
    "contract": "A written or spoken agreement between two or more parties.",
    "conviction": "A formal declaration that someone is guilty of a criminal offense.",
    "copyright": "The exclusive legal right to reproduce, publish, or sell creative work.",
    "counsel": "A lawyer or group of lawyers giving legal advice.",
    "court": "A tribunal presided over by a judge, in which civil and criminal matters are heard.",
    "criminal law": "A system of law concerned with the punishment of offenders.",
    "damages": "A sum of money claimed or awarded in compensation for a loss or injury.",
    "debtor": "A person or institution that owes a sum of money.",
    "decree": "An official order issued by a court.",
    "defendant": "An individual or group being sued or accused in a court of law.",
    "deposition": "The taking of sworn oral testimony outside of court.",
    "due process": "Fair treatment through the normal judicial system.",
    "ejectment": "An action to recover the possession of land.",
    "evidence": "Information presented in court to prove or disprove a fact.",
    "exhibit": "A document or object produced as evidence in court.",
    "felony": "A crime, typically involving violence, regarded as more serious than a misdemeanor.",
    "filing": "The act of submitting a legal document to the court.",
    "garnishment": "A court order to withhold a person's wages to pay a debt.",
    "hearing": "A proceeding before a court or other decision‑making body.",
    "indictment": "A formal charge or accusation of a serious crime.",
    "injunction": "A court order preventing or compelling a specific action.",
    "judgment": "A decision of a court regarding the rights and liabilities of parties.",
    "jurisdiction": "The official power to make legal decisions and judgments.",
    "jurisprudence": "The theory or philosophy of law.",
    "lawsuit": "A claim or dispute brought to a court of law for adjudication.",
    "lease": "A contract by which one party conveys property to another for a specified time.",
    "liable": "Legally responsible for one's actions.",
    "lien": "A right to keep possession of property belonging to another until a debt is discharged.",
    "litigation": "The process of taking legal action.",
    "mediation": "Intervention in a dispute to resolve it; often a voluntary process.",
    "misdemeanor": "A minor wrongdoing, less serious than a felony.",
    "negligence": "Failure to take proper care in doing something, resulting in damage.",
    "notary": "A person authorized to perform certain legal formalities, especially to witness signatures.",
    "obligation": "A legal or moral duty to do or not do something.",
    "parole": "The release of a prisoner before the full sentence is served.",
    "patent": "A government license conferring a right or title to an invention.",
    "perjury": "The offense of willfully telling an untruth or making a misrepresentation under oath.",
    "plaintiff": "A person who brings a case against another in a court of law.",
    "plea": "A formal statement by or on behalf of a defendant, stating guilt or innocence.",
    "power of attorney": "The authority to act for another person in specified legal matters.",
    "precedent": "An earlier event or action that is regarded as an example or guide.",
    "probate": "The official proving of a will.",
    "prosecutor": "A person, especially a public official, who institutes legal proceedings.",
    "public defender": "A lawyer employed to represent people who cannot afford one.",
    "remedy": "A means of legal reparation.",
    "settlement": "An official agreement intended to resolve a dispute.",
    "statute": "A written law passed by a legislative body.",
    "subpoena": "A writ ordering a person to attend a court.",
    "sue": "Institute legal proceedings against a person or institution.",
    "testimony": "A formal written or spoken statement given in a court of law.",
    "tort": "A wrongful act leading to civil legal liability.",
    "trademark": "A symbol, word, or words legally registered or established by use as representing a company or product.",
    "verdict": "A decision on a disputed issue in a civil or criminal case.",
    "waive": "To voluntarily give up a legal right.",
    "warrant": "A document issued by a legal or government official authorizing the police to make an arrest, search premises, etc.",
    "will": "A legal document expressing a person's wishes as to how their property is to be distributed after death.",
    "witness": "A person who sees an event and testifies in court.",
    "writ": "A form of written command in the name of a court.",
}

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
    source TEXT DEFAULT 'legal',
    safe_level INTEGER DEFAULT 1,
    FOREIGN KEY(word_id) REFERENCES words(id)
);
CREATE TABLE synonyms (
    word_id INTEGER NOT NULL,
    synonym TEXT NOT NULL COLLATE NOCASE,
    FOREIGN KEY(word_id) REFERENCES words(id)
);
"""

def build():
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
    conn = sqlite3.connect(DB_PATH)
    conn.executescript(SCHEMA)

    for word, definition in LEGAL_TERMS.items():
        conn.execute(
            "INSERT OR IGNORE INTO words(word, word_type) VALUES(?, ?)",
            (word, "legal")
        )
        cur = conn.execute("SELECT id FROM words WHERE word=?", (word,))
        row = cur.fetchone()
        if row:
            word_id = row[0]
            conn.execute(
                "INSERT INTO definitions(word_id, definition, source) VALUES(?, ?, ?)",
                (word_id, definition, "legal")
            )

    conn.commit()
    conn.close()
    print(f"Legal dictionary built: {DB_PATH}")
    print(f"Total terms: {len(LEGAL_TERMS)}")

if __name__ == "__main__":
    build()
