# AI Intelligence Layer — SIH Project (Problem Statement 26094)

This microservice powers the machine learning and natural language processing (NLP) backend for the AI-Powered Dynamic Mental Health Monitoring and Distress Prediction System for Victims of Atrocities. 

The system is designed to remove the "black box" nature of AI in crisis management by combining predictive risk modeling with Explainable AI (XAI) and bilingual sentiment analysis.

---

## 🚀 Core Features Implemented

1. **Bilingual Distress NLP (English & Hindi):**
   * Uses serialized `scikit-learn` TF-IDF and classification pipelines (`model_en.pkl`, `model_hi.pkl`) to evaluate incoming check-in text and output precise distress probabilities.
2. **Predictive Risk Modeling & Tiering:**
   * Calculates a Dynamic Distress Score (DDS) ranging from 0 to 100.
   * Factors in NLP distress probability, behavioral risk signals (such as extended response latency), and historical patterns (such as missed check-ins).
   * Automatically assigns risk tiers: `Low`, `Moderate`, `High`, or `Critical`.
3. **Explainable AI (XAI) - Trigger Word Extraction:**
   * Dynamically evaluates user text against model coefficients to isolate and extract the top impactful "trigger words" (e.g., *"threatened"*, *"unsafe"*). 
   * Enables the frontend dashboard to highlight alarming phrases directly in red for human review.
4. **Audio Transcription Pipeline:**
   * Integrates the OpenAI Whisper model via a FastAPI endpoint for speech-to-text conversion, complete with simulated fallbacks to handle local development environment constraints gracefully.
5. **Synthetic Data Engine:**
   * Features a longitudinal data generator (`generate_synthetic.py`) producing 730 realistic victim check-in records (`synthetic_checkins.csv`) for database seeding and longitudinal trend analysis.

---

## 📂 Project Architecture

```text
SIH-project/
│
├── ai-service/
│   ├── main.py                  # FastAPI server containing core endpoints
│   └── __pycache__/
│
├── models/
│   ├── model_en.pkl             # Trained English sentiment classification pipeline
│   └── model_hi.pkl             # Trained Hindi sentiment classification pipeline
│
├── synthetic-data/
│   └── synthetic_checkins.csv   # Longitudinal dataset for database seeding
│
├── generate_synthetic.py        # Script used to generate synthetic victim timelines
├── requirements.txt             # Required Python package dependencies
└── README.md                    # Project documentation & execution guide