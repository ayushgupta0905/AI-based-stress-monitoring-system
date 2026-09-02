-- ==============================================================================
-- SIH26094: AI-POWERED DYNAMIC MENTAL HEALTH MONITORING & DISTRESS PREDICTION
-- PRODUCTION-GRADE POSTGRESQL DATABASE SCHEMA
--
-- Compliance: Digital Personal Data Protection (DPDP) Act, 2023
-- Architectural Reference: System Architecture Document v1.0 (Section 4, Figure 3)
-- Author: Senior Backend Engineering Team
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 0. CORE EXTENSIONS
-- ------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ------------------------------------------------------------------------------
-- 1. CUSTOM ENUM TYPES
-- ------------------------------------------------------------------------------
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('counsellor', 'district', 'state', 'national', 'admin');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE risk_tier AS ENUM ('Low', 'Moderate', 'High', 'Critical');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE channel_type AS ENUM ('chat', 'ivrs', 'sms', 'web');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE sentiment_type AS ENUM ('positive', 'neutral', 'negative', 'distress-indicative');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE alert_status AS ENUM ('open', 'acknowledged', 'resolved', 'escalated', 'false_positive');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE consent_status AS ENUM ('granted', 'withdrawn');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ------------------------------------------------------------------------------
-- 2. TABLE: users
-- Hierarchy: Counsellor, District Officer, State Official, National MoSJE Admin
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    role user_role NOT NULL DEFAULT 'counsellor',
    jurisdiction VARCHAR(255) NOT NULL, -- District name, State, or 'National'
    password_hash VARCHAR(255) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role_jurisdiction ON users(role, jurisdiction);

-- ------------------------------------------------------------------------------
-- 3. TABLE: victims
-- Registered victims & complainants under the SC/ST PoA Act / NHAA (14566)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS victims (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id VARCHAR(100) UNIQUE NOT NULL, -- NHAA docket reference / FIR number
    language_pref VARCHAR(10) NOT NULL DEFAULT 'hi', -- 'hi', 'en', 'mr', 'te', etc.
    current_risk_tier risk_tier NOT NULL DEFAULT 'Low',
    assigned_counsellor_id UUID REFERENCES users(id) ON DELETE SET NULL,
    contact_number VARCHAR(20),
    district VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    monitoring_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_victims_case_id ON victims(case_id);
CREATE INDEX IF NOT EXISTS idx_victims_assigned_counsellor ON victims(assigned_counsellor_id);
CREATE INDEX IF NOT EXISTS idx_victims_risk_tier ON victims(current_risk_tier);
CREATE INDEX IF NOT EXISTS idx_victims_location ON victims(state, district);

-- ------------------------------------------------------------------------------
-- 4. TABLE: consent
-- Dedicated DPDP Act 2023 Consent History (Append-only audit trail)
-- Withdrawal creates a new row with timestamp rather than overwriting existing records.
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS consent (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    victim_id UUID NOT NULL REFERENCES victims(id) ON DELETE CASCADE,
    scope VARCHAR(100) NOT NULL DEFAULT 'mental_health_monitoring',
    status consent_status NOT NULL DEFAULT 'granted',
    granted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    withdrawn_at TIMESTAMP WITH TIME ZONE,
    reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_consent_victim_id ON consent(victim_id);
CREATE INDEX IF NOT EXISTS idx_consent_victim_status ON consent(victim_id, status);

-- ------------------------------------------------------------------------------
-- 5. TABLE: checkins
-- Multi-Channel Ingestion (Chatbot, IVRS Call, SMS, Web Self-Service)
-- Separated from scores for privacy isolation, access-control, and retention rules.
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS checkins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    victim_id UUID NOT NULL REFERENCES victims(id) ON DELETE CASCADE,
    channel channel_type NOT NULL DEFAULT 'chat',
    raw_text TEXT,
    audio_ref VARCHAR(500), -- Object storage URL / S3 key
    response_latency_sec NUMERIC(8, 2) CHECK (response_latency_sec >= 0),
    metadata JSONB DEFAULT '{}'::jsonb, -- Structured answers: mood, sleep, safety
    is_missed BOOLEAN NOT NULL DEFAULT FALSE, -- Behavioral disengagement marker
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_checkins_victim_created ON checkins(victim_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_checkins_channel ON checkins(channel);
CREATE INDEX IF NOT EXISTS idx_checkins_metadata_gin ON checkins USING gin(metadata);

-- ------------------------------------------------------------------------------
-- 6. TABLE: scores
-- AI-Derived Dynamic Distress Score (DDS 0-100) & Explainability (1:1 with checkins)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    checkin_id UUID UNIQUE NOT NULL REFERENCES checkins(id) ON DELETE CASCADE,
    victim_id UUID NOT NULL REFERENCES victims(id) ON DELETE CASCADE,
    dds_score INTEGER NOT NULL CHECK (dds_score >= 0 AND dds_score <= 100),
    risk_tier risk_tier NOT NULL,
    sentiment_label sentiment_type NOT NULL,
    emotion_signals JSONB NOT NULL DEFAULT '{}'::jsonb, 
    -- e.g. {"voice_stress": 0.66, "flat_affect": 0.41, "pitch_variance": 0.12, "speech_rate": 110}
    contributing_factors JSONB NOT NULL DEFAULT '[]'::jsonb,
    -- e.g. ["declining sentiment over 3 check-ins", "2 missed check-ins", "shorter responses"]
    escalation_flag BOOLEAN NOT NULL DEFAULT FALSE,
    confidence_score NUMERIC(5, 4),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_scores_checkin_id ON scores(checkin_id);
CREATE INDEX IF NOT EXISTS idx_scores_victim_created ON scores(victim_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_scores_risk_tier ON scores(risk_tier);
CREATE INDEX IF NOT EXISTS idx_scores_escalation ON scores(escalation_flag) WHERE escalation_flag = TRUE;
CREATE INDEX IF NOT EXISTS idx_scores_emotion_gin ON scores USING gin(emotion_signals);
CREATE INDEX IF NOT EXISTS idx_scores_factors_gin ON scores USING gin(contributing_factors);

-- ------------------------------------------------------------------------------
-- 7. TABLE: alerts
-- Escalation Alerts routed to Assigned Counsellor & District Officials
-- Mandatory acknowledgement and outcome logging loop closure.
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    victim_id UUID NOT NULL REFERENCES victims(id) ON DELETE CASCADE,
    score_id UUID NOT NULL REFERENCES scores(id) ON DELETE CASCADE,
    threshold_crossed VARCHAR(255) NOT NULL, -- e.g. "DDS > 70 (High Risk)", "Escalation Velocity Spike"
    status alert_status NOT NULL DEFAULT 'open',
    assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
    acknowledged_at TIMESTAMP WITH TIME ZONE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    outcome_notes TEXT, -- Human-in-the-loop outcome notes
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_alerts_victim_id ON alerts(victim_id);
CREATE INDEX IF NOT EXISTS idx_alerts_score_id ON alerts(score_id);
CREATE INDEX IF NOT EXISTS idx_alerts_assigned_status ON alerts(assigned_to, status);
CREATE INDEX IF NOT EXISTS idx_alerts_status_created ON alerts(status, created_at DESC);

-- ------------------------------------------------------------------------------
-- 8. TABLE: audit_log
-- Immutable, Append-Only DPDP Act 2023 Compliance & Access Trail
-- Answers: "Who accessed or updated this victim's case, when, and what was performed?"
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL, -- 'READ', 'WRITE', 'CONSENT_CHANGE', 'ALERT_ACK', 'ERASURE_REQUEST'
    entity_type VARCHAR(100) NOT NULL, -- 'victims', 'checkins', 'scores', 'alerts', 'consent'
    entity_id UUID NOT NULL,
    details JSONB DEFAULT '{}'::jsonb, -- Request metadata: IP address, surface, parameters
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_entity ON audit_log(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_actor ON audit_log(actor_user_id);
CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_log(timestamp DESC);

-- ------------------------------------------------------------------------------
-- 9. TRIGGERS & AUTOMATION
-- ------------------------------------------------------------------------------

-- Trigger 1: Maintain updated_at timestamp across mutable tables
CREATE OR REPLACE FUNCTION update_timestamp_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp_column();

DROP TRIGGER IF EXISTS trg_victims_updated_at ON victims;
CREATE TRIGGER trg_victims_updated_at
    BEFORE UPDATE ON victims
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp_column();

DROP TRIGGER IF EXISTS trg_alerts_updated_at ON alerts;
CREATE TRIGGER trg_alerts_updated_at
    BEFORE UPDATE ON alerts
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp_column();

-- Trigger 2: Automatically synchronize victims.current_risk_tier upon new score creation
CREATE OR REPLACE FUNCTION sync_victim_latest_risk_tier()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE victims
    SET current_risk_tier = NEW.risk_tier,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.victim_id;
    RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

DROP TRIGGER IF EXISTS trg_sync_victim_risk_tier ON scores;
CREATE TRIGGER trg_sync_victim_risk_tier
    AFTER INSERT ON scores
    FOR EACH ROW
    EXECUTE FUNCTION sync_victim_latest_risk_tier();
