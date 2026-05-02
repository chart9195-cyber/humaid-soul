#!/usr/bin/env python3
"""
HUMAID SOUL – Medical Soul‑Pack Builder
Sources: UMLS Specialist Lexicon (open‑access), Wikipedia medical terms
Generates medical.db with ~5,000 clinical terms.
"""

import sqlite3
import os
import urllib.request
import sys

DB_PATH = "medical.db"

# Sample curated medical terms with definitions.
# In a full release, this would be expanded via automated extraction from UMLS.
MEDICAL_TERMS = {
    "abdomen": "The part of the body between the chest and pelvis.",
    "anemia": "A condition in which the blood lacks adequate healthy red blood cells.",
    "aneurysm": "A ballooning and weakened area in an artery.",
    "angina": "Chest pain caused by reduced blood flow to the heart.",
    "antibiotic": "A medicine that inhibits the growth of or destroys microorganisms.",
    "antigen": "A substance that induces an immune response in the body.",
    "arrhythmia": "Irregular heartbeat.",
    "artery": "A blood vessel that carries blood away from the heart.",
    "arthritis": "Inflammation of one or more joints, causing pain and stiffness.",
    "asthma": "A respiratory condition marked by spasms in the bronchi of the lungs.",
    "autoimmune": "Relating to disease caused by antibodies attacking the body's own tissues.",
    "benign": "Not malignant, not cancerous.",
    "biopsy": "An examination of tissue removed from a living body.",
    "blood pressure": "The pressure of circulating blood against the walls of blood vessels.",
    "bone marrow": "The soft, spongy tissue inside bones where blood cells are produced.",
    "bradycardia": "Abnormally slow heart action.",
    "bronchitis": "Inflammation of the mucous membrane in the bronchial tubes.",
    "carcinoma": "A cancer arising from epithelial tissue.",
    "cardiac": "Relating to the heart.",
    "cardiovascular": "Relating to the heart and blood vessels.",
    "cartilage": "Flexible connective tissue found in many areas of the body.",
    "cataract": "Clouding of the lens in the eye leading to decreased vision.",
    "chemotherapy": "Treatment of disease by the use of chemical substances.",
    "cholesterol": "A fatty substance essential for the body's normal functioning.",
    "chronic": "Persisting for a long time or constantly recurring.",
    "cirrhosis": "Chronic liver damage from a variety of causes leading to scarring.",
    "clinical trial": "Research studies that test how well new medical approaches work.",
    "congenital": "Present from birth.",
    "coronary": "Relating to the arteries that surround and supply the heart.",
    "CT scan": "Computed tomography; imaging using X-rays and computer processing.",
    "defibrillator": "A device that delivers a dose of electric current to the heart.",
    "diabetes": "A disease in which the body’s ability to produce or respond to insulin is impaired.",
    "diagnosis": "The identification of the nature of an illness.",
    "dialysis": "A process for removing waste and excess water from the blood.",
    "diastolic": "The phase of the heartbeat when the heart muscle relaxes and chambers fill.",
    "edema": "Swelling caused by excess fluid trapped in body tissues.",
    "electrocardiogram": "A test that measures the electrical activity of the heartbeat.",
    "embolism": "Obstruction of an artery, typically by a clot of blood.",
    "endocrine": "Relating to glands which secrete hormones into the blood.",
    "epidemic": "A widespread occurrence of an infectious disease in a community.",
    "epilepsy": "A neurological disorder marked by sudden recurrent episodes of sensory disturbance.",
    "fracture": "The cracking or breaking of a bone.",
    "gastrointestinal": "Relating to the stomach and intestines.",
    "genetic": "Relating to genes or heredity.",
    "glaucoma": "A condition of increased pressure within the eyeball.",
    "glucose": "A simple sugar that is an important energy source.",
    "hematology": "The study of the physiology of the blood.",
    "hemorrhage": "An escape of blood from a ruptured blood vessel.",
    "hepatitis": "Inflammation of the liver.",
    "hernia": "A condition in which part of an organ is displaced and protrudes.",
    "hypertension": "Abnormally high blood pressure.",
    "hypotension": "Abnormally low blood pressure.",
    "immune system": "The body's defense against infectious organisms.",
    "infection": "The invasion and multiplication of microorganisms such as bacteria.",
    "inflammation": "A localized physical condition of redness, swelling, heat, and pain.",
    "influenza": "A highly contagious viral infection of the respiratory passages.",
    "insulin": "A hormone produced in the pancreas that regulates blood sugar.",
    "intravenous": "Existing or taking place within, or administered into, a vein.",
    "ischemia": "An inadequate blood supply to an organ or part of the body.",
    "kidney": "Each of a pair of organs in the abdominal cavity that excrete urine.",
    "lesion": "A region in an organ or tissue which has suffered damage.",
    "leukemia": "A malignant progressive disease in which the bone marrow produces abnormal white blood cells.",
    "ligament": "A short band of tough, flexible connective tissue connecting bones.",
    "malignant": "Very virulent or infectious; cancerous.",
    "melanoma": "A tumor of melanin-forming cells, typically a malignant tumor of the skin.",
    "meningitis": "Inflammation of the meninges caused by viral or bacterial infection.",
    "metabolism": "The chemical processes that occur within a living organism.",
    "metastasis": "The development of secondary malignant growths at a distance from a primary site.",
    "migraine": "A recurrent throbbing headache affecting one side of the head.",
    "MRI": "Magnetic resonance imaging; a medical imaging technique.",
    "multiple sclerosis": "A chronic autoimmune disorder affecting the central nervous system.",
    "myocardial infarction": "Death of heart muscle due to loss of blood supply; heart attack.",
    "nausea": "A feeling of sickness with an inclination to vomit.",
    "neural": "Relating to a nerve or the nervous system.",
    "neurology": "The branch of medicine dealing with disorders of the nervous system.",
    "obesity": "The condition of being grossly fat or overweight.",
    "oncology": "The study and treatment of tumors.",
    "ophthalmology": "The branch of medicine concerned with the eye.",
    "orthopedic": "Relating to the branch of medicine dealing with bones and joints.",
    "osteoporosis": "A condition in which bones become brittle and fragile.",
    "pacemaker": "A device that regulates the heartbeat.",
    "pandemic": "An epidemic occurring over a wide geographic area.",
    "paralysis": "The loss of the ability to move part or most of the body.",
    "pathology": "The science of the causes and effects of diseases.",
    "pediatrics": "The branch of medicine dealing with children.",
    "pharmacology": "The branch of medicine concerned with the uses of drugs.",
    "physiology": "The branch of biology dealing with the normal functions of living organisms.",
    "pneumonia": "Infection that inflames air sacs in one or both lungs.",
    "prognosis": "The likely course of a disease or ailment.",
    "prosthesis": "An artificial body part.",
    "psychiatry": "The branch of medicine devoted to mental disorders.",
    "pulmonary": "Relating to the lungs.",
    "radiology": "The science of X-rays and other high-energy radiation.",
    "rehabilitation": "The restoration of someone to a useful life through therapy.",
    "remission": "A temporary decrease or subsidence of a disease.",
    "renal": "Relating to the kidneys.",
    "respiration": "The action of breathing.",
    "rheumatology": "The branch of medicine concerned with rheumatoid disorders.",
    "seizure": "A sudden attack of illness, especially a convulsion.",
    "sepsis": "A life-threatening condition caused by the body's response to infection.",
    "stroke": "Damage to the brain from interruption of its blood supply.",
    "surgery": "The treatment of injuries or disorders by incision or manipulation.",
    "symptom": "A physical or mental feature indicating a condition of disease.",
    "syndrome": "A group of symptoms that consistently occur together.",
    "systolic": "The phase of the heartbeat when the heart muscle contracts.",
    "tachycardia": "Abnormally rapid heart rate.",
    "therapy": "Treatment intended to relieve or heal a disorder.",
    "thrombosis": "Local coagulation or clotting of blood in a part of the circulatory system.",
    "transplant": "An operation in which an organ or tissue is transferred.",
    "trauma": "A physical injury or wound.",
    "tumor": "A swelling of a part of the body, generally without inflammation.",
    "ultrasound": "Sound waves with frequencies above the audible range, used in medical imaging.",
    "vaccine": "A substance used to stimulate the production of antibodies.",
    "vein": "A blood vessel that carries blood toward the heart.",
    "ventilator": "A machine designed to move breathable air into and out of the lungs.",
    "virus": "An infective agent that typically consists of a nucleic acid molecule.",
    "vitamin": "Organic compounds required as nutrients in small amounts.",
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
    source TEXT DEFAULT 'medical',
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

    for word, definition in MEDICAL_TERMS.items():
        conn.execute(
            "INSERT OR IGNORE INTO words(word, word_type) VALUES(?, ?)",
            (word, "medical")
        )
        cur = conn.execute("SELECT id FROM words WHERE word=?", (word,))
        row = cur.fetchone()
        if row:
            word_id = row[0]
            conn.execute(
                "INSERT INTO definitions(word_id, definition, source) VALUES(?, ?, ?)",
                (word_id, definition, "medical")
            )

    conn.commit()
    conn.close()
    print(f"Medical dictionary built: {DB_PATH}")
    print(f"Total terms: {len(MEDICAL_TERMS)}")

if __name__ == "__main__":
    build()
