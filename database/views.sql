-- SIH26094: HIGH-PERFORMANCE ANALYTICAL & DASHBOARD VIEWS
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. VIEW: v_counsellor_worklist
-- Prioritized worklist for Counsellors (open alerts, latest checkin text, audio, DDS)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_counsellor_worklist AS
SELECT 
    a.id AS alert_id,
    a.status AS alert_status,
    a.threshold_crossed,
    a.created_at AS alert_triggered_at,
    v.id AS victim_id,
    v.case_id,
    v.language_pref,
    v.current_risk_tier,
    v.district,
    v.state,
    u.id AS counsellor_id,
    u.name AS counsellor_name,
    s.id AS score_id,
    s.dds_score,
    s.risk_tier,
    s.sentiment_label,
    s.emotion_signals,
    s.contributing_factors,
    s.escalation_flag,
    c.id AS checkin_id,
    c.channel AS checkin_channel,
    c.raw_text AS checkin_text,
    c.audio_ref AS checkin_audio_ref,
    c.response_latency_sec
FROM alerts a
JOIN victims v ON a.victim_id = v.id
JOIN scores s ON a.score_id = s.id
JOIN checkins c ON s.checkin_id = c.id
LEFT JOIN users u ON a.assigned_to = u.id
ORDER BY 
    CASE 
        WHEN a.status = 'open' THEN 1
        WHEN a.status = 'acknowledged' THEN 2
        ELSE 3
    END,
    s.dds_score DESC,
    a.created_at DESC;

-- ------------------------------------------------------------------------------
-- 2. VIEW: v_victim_distress_trends
-- Longitudinal trend history for charting DDS trajectories and score deltas
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_victim_distress_trends AS
SELECT 
    v.id AS victim_id,
    v.case_id,
    v.current_risk_tier,
    c.id AS checkin_id,
    c.channel,
    c.response_latency_sec,
    s.id AS score_id,
    s.dds_score,
    s.risk_tier,
    s.sentiment_label,
    s.emotion_signals,
    s.contributing_factors,
    s.escalation_flag,
    c.created_at AS checkin_time,
    LAG(s.dds_score, 1) OVER (PARTITION BY v.id ORDER BY c.created_at ASC) AS previous_dds_score,
    s.dds_score - LAG(s.dds_score, 1) OVER (PARTITION BY v.id ORDER BY c.created_at ASC) AS dds_score_delta
FROM victims v
JOIN checkins c ON v.id = c.victim_id
JOIN scores s ON c.id = s.checkin_id
ORDER BY v.id, c.created_at ASC;

-- ------------------------------------------------------------------------------
-- 3. VIEW: v_district_state_summary
-- Aggregated risk KPIs for District, State, and National MoSJE Heatmap Dashboards
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_district_state_summary AS
SELECT 
    v.state,
    v.district,
    COUNT(DISTINCT v.id) AS total_monitored_victims,
    COUNT(DISTINCT CASE WHEN v.current_risk_tier = 'Critical' THEN v.id END) AS critical_cases,
    COUNT(DISTINCT CASE WHEN v.current_risk_tier = 'High' THEN v.id END) AS high_risk_cases,
    COUNT(DISTINCT CASE WHEN v.current_risk_tier = 'Moderate' THEN v.id END) AS moderate_risk_cases,
    COUNT(DISTINCT CASE WHEN v.current_risk_tier = 'Low' THEN v.id END) AS low_risk_cases,
    COUNT(DISTINCT CASE WHEN a.status = 'open' THEN a.id END) AS open_alerts_count,
    COUNT(DISTINCT CASE WHEN a.status = 'acknowledged' THEN a.id END) AS acknowledged_alerts_count,
    ROUND(AVG(s.dds_score), 2) AS average_dds_score
FROM victims v
LEFT JOIN checkins c ON v.id = c.victim_id
LEFT JOIN scores s ON c.id = s.checkin_id
LEFT JOIN alerts a ON v.id = a.victim_id
WHERE v.monitoring_active = TRUE
GROUP BY v.state, v.district;

-- ------------------------------------------------------------------------------
-- 4. VIEW: v_dpdp_victim_audit_trail
-- DPDP Act 2023 Access Trail & Data-Principal Compliance Report
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_dpdp_victim_audit_trail AS
SELECT 
    al.id AS audit_id,
    al.timestamp,
    al.action,
    al.entity_type,
    al.entity_id,
    u.name AS actor_name,
    u.role AS actor_role,
    u.email AS actor_email,
    al.details
FROM audit_log al
LEFT JOIN users u ON al.actor_user_id = u.id
ORDER BY al.timestamp DESC;
