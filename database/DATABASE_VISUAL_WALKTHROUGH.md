# Visual Walkthrough: PostgreSQL Database Architecture (SIH26094)
## AI-Powered Dynamic Mental Health Monitoring and Distress Prediction System

---

## 1. Complete Entity-Relationship (ER) Architecture

```mermaid
erDiagram
    USERS ||--o{ VICTIMS : "assigned_counsellor_id"
    USERS ||--o{ ALERTS : "assigned_to"
    USERS ||--o{ AUDIT_LOG : "actor_user_id"
    VICTIMS ||--o{ CONSENT : "victim_id (1:N audit)"
    VICTIMS ||--o{ CHECKINS : "victim_id"
    VICTIMS ||--o{ SCORES : "victim_id (trends)"
    VICTIMS ||--o{ ALERTS : "victim_id"
    CHECKINS ||--|| SCORES : "checkin_id (1:1 UNIQUE)"
    SCORES ||--o{ ALERTS : "score_id"

    USERS {
        uuid id PK
        varchar name
        varchar email UK
        varchar phone
        user_role role "counsellor, district, state, national, admin"
        varchar jurisdiction "South Delhi, Pune, National"
        varchar password_hash
        boolean is_active
        timestamp created_at
        timestamp updated_at
    }

    VICTIMS {
        uuid id PK
        varchar case_id UK "NHAA Docket / FIR Ref"
        varchar language_pref "hi, en, mr, te"
        risk_tier current_risk_tier "Low, Moderate, High, Critical"
        uuid assigned_counsellor_id FK
        varchar contact_number
        varchar district
        varchar state
        boolean monitoring_active
        timestamp created_at
        timestamp updated_at
    }

    CONSENT {
        uuid id PK
        uuid victim_id FK
        varchar scope "mental_health_monitoring"
        consent_status status "granted, withdrawn"
        timestamp granted_at
        timestamp withdrawn_at
        text reason
        timestamp created_at
    }

    CHECKINS {
        uuid id PK
        uuid victim_id FK
        channel_type channel "chat, ivrs, sms, web"
        text raw_text
        varchar audio_ref "Object storage key / S3 URL"
        numeric response_latency_sec
        jsonb metadata "Structured prompt answers"
        boolean is_missed "Disengagement marker"
        timestamp created_at
    }

    SCORES {
        uuid id PK
        uuid checkin_id FK "1:1 UNIQUE"
        uuid victim_id FK
        integer dds_score "0 - 100"
        risk_tier risk_tier "Low, Moderate, High, Critical"
        sentiment_type sentiment_label "positive, neutral, negative, distress-indicative"
        jsonb emotion_signals "voice_stress, flat_affect, pitch_variance"
        jsonb contributing_factors "SHAP explainability factors"
        boolean escalation_flag
        numeric confidence_score
        timestamp created_at
    }

    ALERTS {
        uuid id PK
        uuid victim_id FK
        uuid score_id FK
        varchar threshold_crossed "e.g. DDS > 90 (Critical Escalation)"
        alert_status status "open, acknowledged, resolved, false_positive"
        uuid assigned_to FK
        timestamp acknowledged_at
        timestamp resolved_at
        text outcome_notes
        timestamp created_at
        timestamp updated_at
    }

    AUDIT_LOG {
        uuid id PK
        uuid actor_user_id FK
        varchar action "READ, WRITE, CONSENT_CHANGE, ALERT_ACK"
        varchar entity_type
        uuid entity_id
        jsonb details
        timestamp timestamp
    }
```

---

## 2. Check-in to Alert Lifecycle Sequence Diagram

```mermaid
sequenceDiagram
    autonumber
    actor Victim as Victim / Complainant
    participant Backend as Backend Service
    participant DB as PostgreSQL Database
    participant AI as AI Scoring Engine
    actor Counsellor as Assigned Counsellor

    Victim->>Backend: Submit Check-in (Chat / IVRS voice)
    Backend->>DB: Query active consent from `consent` table
    DB-->>Backend: Consent is active
    Backend->>DB: INSERT INTO checkins (victim_id, channel, raw_text, audio_ref, latency)
    DB-->>Backend: Return checkin_id
    Backend-->>Victim: Immediate response ("Thanks, noted")

    Backend->>AI: POST /ai/v1/score (checkin_id, text, audio_ref, history)
    AI-->>Backend: Return DDS score (92), risk_tier ('Critical'), emotion_signals, factors
    
    Backend->>DB: INSERT INTO scores (checkin_id, victim_id, dds_score, risk_tier, emotion_signals, factors, escalation_flag)
    Note over DB: Trigger automatically updates victims.current_risk_tier = 'Critical'
    
    rect rgb(255, 230, 230)
    Note over Backend,DB: Threshold Evaluation (DDS >= 90)
    Backend->>DB: INSERT INTO alerts (victim_id, score_id, threshold_crossed, status, assigned_to)
    end

    Backend->>Counsellor: Live Alert Notification (WebSocket / Dashboard)
    Counsellor->>DB: Query `v_counsellor_worklist`
    Counsellor->>DB: UPDATE alerts SET status='acknowledged', outcome_notes='Contacted victim', acknowledged_at=NOW()
    DB->>DB: INSERT INTO audit_log (actor_user_id, action='ALERT_ACK', entity_type='alerts', entity_id=...)
```

---

## 3. DPDP Act 2023 Consent Lifecycle State Diagram

```mermaid
stateDiagram-v2
    [*] --> ConsentGranted: Onboarding / Voice Opt-in
    ConsentGranted --> ActiveMonitoring: Regular Monitoring
    ActiveMonitoring --> ActiveMonitoring: Periodic Check-ins Ingested & Scored
    ActiveMonitoring --> ConsentWithdrawn: Victim Opts Out (Any Channel)
    
    state ConsentWithdrawn {
        [*] --> IngestHalted: Immediate Halt to Scoring
        IngestHalted --> CasePreserved: Case Records Retained for Legal Tracking
    }
    
    ConsentWithdrawn --> ConsentGranted: Re-consent Captured
```

---

## 4. Key Performance Indexes & Optimization Strategy

```
  TABLE: checkins
  └── idx_checkins_victim_created: (victim_id, created_at DESC) -> B-tree for fast trend history
  └── idx_checkins_channel: (channel)                            -> B-tree for channel analytics
  └── idx_checkins_metadata_gin: (metadata)                      -> GIN index for JSONB prompt filters

  TABLE: scores
  └── idx_scores_checkin_id: (checkin_id) UNIQUE                 -> B-tree for 1:1 lookups
  └── idx_scores_victim_created: (victim_id, created_at DESC)   -> B-tree for longitudinal graphs
  └── idx_scores_risk_tier: (risk_tier)                          -> B-tree for tier filtering
  └── idx_scores_escalation: (escalation_flag) WHERE TRUE        -> Partial index for rapid alert audits
  └── idx_scores_emotion_gin: (emotion_signals)                  -> GIN index for acoustic signal queries
  └── idx_scores_factors_gin: (contributing_factors)             -> GIN index for explainability queries

  TABLE: alerts
  └── idx_alerts_assigned_status: (assigned_to, status)          -> B-tree for counsellor worklist
  └── idx_alerts_status_created: (status, created_at DESC)       -> B-tree for active alert sorting
```

---

## 5. Verification & Query Execution Guide

### A. Counsellor Worklist (Prioritized Active Alerts)
```sql
SELECT 
    alert_id,
    case_id,
    current_risk_tier,
    dds_score,
    sentiment_label,
    contributing_factors,
    checkin_channel,
    checkin_text
FROM v_counsellor_worklist
WHERE alert_status = 'open';
```

### B. Victim Longitudinal Trajectory (Dashboard Sparkline)
```sql
SELECT 
    checkin_time,
    channel,
    dds_score,
    risk_tier,
    dds_score_delta,
    emotion_signals->>'voice_stress' AS voice_stress
FROM v_victim_distress_trends
WHERE case_id = 'NHAA-2026-DL-00101'
ORDER BY checkin_time ASC;
```

### C. District & National Summary View
```sql
SELECT * FROM v_district_state_summary;
```
