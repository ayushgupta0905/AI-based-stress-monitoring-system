import os
import joblib
import numpy as np
import google.generativeai as genai
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional

app = FastAPI(
    title="SIH26094 Intelligence Layer API",
    version="1.1.0",
    description="Dynamic Distress Scoring and Escalation Prediction Service"
)

# --- 1. Load Models at Startup ---
MODEL_EN_PATH = os.path.join("models", "model_en.pkl")
MODEL_HI_PATH = os.path.join("models", "model_hi.pkl")
MODEL_MR_PATH = os.path.join("models", "model_mr.pkl")
MODEL_ESC_PATH = os.path.join("models", "escalation_model.pkl")

model_en = joblib.load(MODEL_EN_PATH) if os.path.exists(MODEL_EN_PATH) else None
model_hi = joblib.load(MODEL_HI_PATH) if os.path.exists(MODEL_HI_PATH) else None
model_mr = joblib.load(MODEL_MR_PATH) if os.path.exists(MODEL_MR_PATH) else None
escalation_model = joblib.load(MODEL_ESC_PATH) if os.path.exists(MODEL_ESC_PATH) else None


# --- 2. Define Request Payloads ---
class ScoreRequest(BaseModel):
    checkin_id: str
    text: str
    language: Optional[str] = "en"
    recent_history: Optional[List[str]] = []
    previous_dds_scores: Optional[List[int]] = []
    response_latency_sec: Optional[int] = 0

class TranscribeRequest(BaseModel):
    audio_ref: str


# --- 3. The Scoring Endpoint (Explainable AI & Predictive Trend) ---
@app.post("/ai/v1/score")
def score_checkin(req: ScoreRequest):
    try:
        # 0. Route to requested language model
        if req.language == "mr":
            clf = model_mr
        elif req.language == "hi":
            clf = model_hi
        else:
            clf = model_en
            
        if clf is None:
            raise HTTPException(status_code=500, detail=f"Requested language model '{req.language}' is not loaded.")

        # 1. NLP Sentiment & Distress Probability
        distress_prob = float(clf.predict_proba([req.text])[0][1])
        nlp_points = distress_prob * 70  

        # 2. Explainable AI: Extract Trigger Words
        feature_names = clf.named_steps['tfidf'].get_feature_names_out()
        coefficients = clf.named_steps['clf'].coef_[0]
        
        words = req.text.lower().split()
        word_weights = {}
        
        # Match user words against the model's distress vocabulary
        for word in words:
            if word in feature_names:
                idx = list(feature_names).index(word)
                if coefficients[idx] > 0:
                    word_weights[word] = float(coefficients[idx])
        
        # Grab the top 3 most impactful words
        trigger_words = sorted(word_weights, key=word_weights.get, reverse=True)[:3]

        # 3. Behavioural Signal Penalties
        missed_count = req.recent_history.count("missed")
        missed_penalty = min(missed_count * 10, 20)
        latency_penalty = 10 if req.response_latency_sec > 60 else 0

        # 4. Dynamic Distress Score Calculation (0-100)
        dds_score = int(min(100, max(0, nlp_points + missed_penalty + latency_penalty)))

        # 5. Risk Tiering
        if dds_score < 40:
            risk_tier = "Low"
        elif dds_score < 70:
            risk_tier = "Moderate"
        elif dds_score < 85:
            risk_tier = "High"
        else:
            risk_tier = "Critical"

        # 6. Predictive Escalation (ML Trend Model)
        # Calculates trend slope from past check-in scores vs current score
        past_score = req.previous_dds_scores[-1] if req.previous_dds_scores else dds_score
        slope = dds_score - past_score

        if escalation_model:
            # Features must match training: [current_dds, slope, missed_count]
            pred_features = np.array([[dds_score, slope, missed_count]])
            escalation_flag = bool(escalation_model.predict(pred_features)[0] == 1)
        else:
            # Fallback heuristic if ML model fails to load
            escalation_flag = risk_tier in ["High", "Critical"]

        # 7. Explainability Factors for the Dashboard
        factors = [f"Text distress probability: {distress_prob:.2f}"]
        if trigger_words:
            factors.append(f"Trigger words detected: {', '.join(trigger_words)}")
        if missed_count > 0:
            factors.append(f"{missed_count} missed check-ins in recent history")
        if latency_penalty > 0:
            factors.append(f"Extended response latency ({req.response_latency_sec}s)")
        if slope > 15:
            factors.append(f"Rapid distress increase (+{slope} pts trend slope)")

        return {
            "dds_score": dds_score,
            "risk_tier": risk_tier,
            "sentiment_label": "distress" if distress_prob >= 0.5 else "neutral/positive",
            "emotion_signals": {
                "voice_stress": round(min(1.0, distress_prob * 0.9), 2),
                "flat_affect": round(min(1.0, (latency_penalty / 10.0) * 0.5), 2)
            },
            "contributing_factors": factors,
            "trigger_words": trigger_words, 
            "escalation_flag": escalation_flag
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# --- 4. The Transcription Endpoint (Lightweight Simulated Fallback) ---
@app.post("/ai/v1/transcribe")
def transcribe_audio(req: TranscribeRequest):
    try:
        return {
            "transcript_text": "Simulated audio transcript: I am feeling anxious about the trial.",
            "language_detected": "en",
            "confidence": 0.85
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

class ChatRequest(BaseModel):
    message: str
    language: Optional[str] = "en"

@app.post("/ai/v1/chat")
def chat_counselor(req: ChatRequest):
    try:
        # Pulls the secret API key securely from the cloud environment
        api_key = os.environ.get("GEMINI_API_KEY")
        if not api_key:
            raise HTTPException(status_code=500, detail="Gemini API Key is missing on the server.")
        
        genai.configure(api_key=api_key)
        
        # The hidden prompt that enforces the counselor persona and bilingual safety
        system_instruction = (
            "You are a trauma-informed crisis counselor AI supporting victims of atrocities. "
            "Your tone must be highly empathetic, non-judgmental, grounding, and concise. "
            "Never provide legal or medical advice, but strictly focus on emotional de-escalation. "
            f"Respond to the user strictly in this language code: {req.language}."
        )
        
       # Initializing Gemini 3.6 Flash for high-speed conversational responses
        model = genai.GenerativeModel(
            model_name="gemini-3.6-flash",
            system_instruction=system_instruction
        )
        
        response = model.generate_content(req.message)
        
        return {
            "reply": response.text,
            "language_used": req.language
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)