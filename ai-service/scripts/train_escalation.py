import pandas as pd
import numpy as np
import joblib
from sklearn.linear_model import LogisticRegression
import os

# 1. Generate synthetic sequential data (past 3 check-ins)
np.random.seed(42)

# Stable/Low-Risk Cases
normal_dds_t2 = np.random.randint(10, 50, 700)
normal_dds_t1 = normal_dds_t2 + np.random.randint(-10, 10, 700)
normal_dds_t = normal_dds_t1 + np.random.randint(-5, 10, 700)
normal_missed = np.random.randint(0, 2, 700)
normal_target = np.zeros(700)

# Escalating/High-Risk Cases (Scores climbing rapidly)
esc_dds_t2 = np.random.randint(40, 60, 300)
esc_dds_t1 = esc_dds_t2 + np.random.randint(10, 20, 300)
esc_dds_t = esc_dds_t1 + np.random.randint(10, 25, 300)
esc_missed = np.random.randint(1, 4, 300)
esc_target = np.ones(300) # 1 = Crisis within 48 hours

# Combine and calculate the trend slope
df_normal = pd.DataFrame({'dds_t': normal_dds_t, 'dds_t2': normal_dds_t2, 'missed': normal_missed, 'escalation': normal_target})
df_esc = pd.DataFrame({'dds_t': esc_dds_t, 'dds_t2': esc_dds_t2, 'missed': esc_missed, 'escalation': esc_target})
df = pd.concat([df_normal, df_esc]).sample(frac=1).reset_index(drop=True)

# Feature Engineering: Current Score, Trend Slope, and Missed Check-ins
df['slope'] = df['dds_t'] - df['dds_t2']
X = df[['dds_t', 'slope', 'missed']]
y = df['escalation']

# 2. Train Model
model = LogisticRegression(class_weight='balanced')
model.fit(X, y)

# 3. Save Model to your models folder
os.makedirs('models', exist_ok=True)
joblib.dump(model, 'models/escalation_model.pkl')
print("Escalation model trained and saved successfully.")