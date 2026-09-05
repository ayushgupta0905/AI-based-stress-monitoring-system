import os
import random
import pandas as pd
from datetime import datetime, timedelta

os.makedirs("synthetic-data", exist_ok=True)

# Contextual check-in templates for atrocity victim monitoring[cite: 2]
templates = {
    "Low": {
        "en": [
            "Things are calm today, I attended work without issues.",
            "Spoke to our lawyer, feeling okay about the process.",
            "Family is safe and doing well this week."
        ],
        "hi": [
            "आज सब शांत है, कोई परेशानी नहीं हुई।",
            "वकील साहब से बात हुई, सब ठीक चल रहा है।",
            "परिवार सुरक्षित है और दिन सामान्य रहा।"
        ]
    },
    "Moderate": {
        "en": [
            "Feeling anxious about the court hearing next month.",
            "Trouble sleeping due to village tension, but managing.",
            "People in the neighborhood are avoiding talking to us."
        ],
        "hi": [
            "अगले महीने की पेशी को लेकर थोड़ी चिंता हो रही है।",
            "गाँव के माहौल की वजह से नींद नहीं आ रही है।",
            "आस-पड़ोस के लोग हमसे बात करने से बच रहे हैं।"
        ]
    },
    "High": {
        "en": [
            "Relatives of the accused were seen loitering outside our house.",
            "Received indirect threats in the market to withdraw the FIR.",
            "I feel completely isolated and overwhelmed with fear."
        ],
        "hi": [
            "आरोपियों के रिश्तेदार आज हमारे घर के बाहर घूम रहे थे।",
            "बाज़ार में केस वापस लेने के लिए धमकी दी गई।",
            "मुझे बहुत डर लग रहा है और सब तरफ से अकेलापन महसूस हो रहा है।"
        ]
    },
    "Critical": {
        "en": [
            "They broke our window last night, I fear for our lives.",
            "Direct death threat received today if we testify in court.",
            "I cannot take this harassment anymore, please send help immediately."
        ],
        "hi": [
            "कल रात उन्होंने घर पर हमला करने की कोशिश की, जान को खतरा है।",
            "गवाही देने पर जान से मारने की सीधी धमकी मिली है।",
            "अब सहन नहीं हो रहा, कृपया तुरंत मदद भेजिए।"
        ]
    }
}

channels = ["chat", "ivrs", "sms", "web"]
records = []
start_date = datetime.now() - timedelta(days=60)

# Generate 100 simulated victims with multi-week trajectories[cite: 2]
for victim_idx in range(1, 101):
    victim_id = f"VIC-{victim_idx:04d}"
    lang = random.choice(["en", "hi"])
    
    # Assign trajectory type: 60% Stable, 30% Escalating, 10% Critical Spike[cite: 2]
    traj_type = random.choices(["stable", "escalating", "spike"], weights=[0.6, 0.3, 0.1])[0]
    
    num_checkins = random.randint(5, 10)
    for checkin_num in range(num_checkins):
        checkin_date = start_date + timedelta(days=checkin_num * 6)
        
        if traj_type == "stable":
            tier = random.choice(["Low", "Moderate"])
            missed = 1 if random.random() < 0.1 else 0
        elif traj_type == "escalating":
            progression = checkin_num / num_checkins
            tier = "Low" if progression < 0.3 else ("Moderate" if progression < 0.7 else "High")
            missed = 1 if random.random() < 0.35 else 0
        else:
            tier = "Critical" if checkin_num >= num_checkins - 2 else "Moderate"
            missed = 1 if random.random() < 0.2 else 0

        text = random.choice(templates[tier][lang])
        latency = random.randint(5, 25) if tier in ["Low", "Moderate"] else random.randint(35, 95)
        
        records.append({
            "checkin_id": f"CHK-{victim_idx:04d}-{checkin_num:02d}",
            "victim_id": victim_id,
            "timestamp": checkin_date.strftime("%Y-%m-%d %H:%M:%S"),
            "channel": random.choice(channels),
            "language": lang,
            "raw_text": text,
            "simulated_tier": tier,
            "missed_checkin": missed,
            "response_latency_sec": latency
        })

df_synthetic = pd.DataFrame(records)
df_synthetic.to_csv("synthetic-data/synthetic_checkins.csv", index=False)
print(f"Success! Generated {len(df_synthetic)} longitudinal check-in records in 'synthetic-data/synthetic_checkins.csv'")