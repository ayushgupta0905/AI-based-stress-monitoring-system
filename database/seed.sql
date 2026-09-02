-- ==============================================================================
-- SIH26094: SYNTHETIC SEED DATASET & SIMULATION SCENARIOS
-- Modeled on realistic distress patterns across Low, Moderate, High, Critical tiers
-- ==============================================================================

TRUNCATE TABLE audit_log, alerts, scores, checkins, consent, victims, users CASCADE;

-- ------------------------------------------------------------------------------
-- 1. SEED USERS (Staff Hierarchy)
-- ------------------------------------------------------------------------------
INSERT INTO users (id, name, email, phone, role, jurisdiction, password_hash, is_active) VALUES
('11111111-1111-1111-1111-111111111101', 'Pooja Sharma', 'pooja.counsellor@nhaa.gov.in', '+919876543210', 'counsellor', 'South Delhi', '$2a$10$wE4oKzC5jVw9U7XG.oH0ve3nS5JzB12lZ3cQo9L1w2m3o4p5q6r7s', TRUE),
('11111111-1111-1111-1111-111111111102', 'Amit Verma', 'amit.counsellor@nhaa.gov.in', '+919876543211', 'counsellor', 'Pune District', '$2a$10$wE4oKzC5jVw9U7XG.oH0ve3nS5JzB12lZ3cQo9L1w2m3o4p5q6r7s', TRUE),
('11111111-1111-1111-1111-111111111103', 'Rajesh Patil', 'rajesh.district@nhaa.gov.in', '+919876543212', 'district', 'Pune District', '$2a$10$wE4oKzC5jVw9U7XG.oH0ve3nS5JzB12lZ3cQo9L1w2m3o4p5q6r7s', TRUE),
('11111111-1111-1111-1111-111111111104', 'Dr. Meena Iyer', 'meena.state@nhaa.gov.in', '+919876543213', 'state', 'Maharashtra', '$2a$10$wE4oKzC5jVw9U7XG.oH0ve3nS5JzB12lZ3cQo9L1w2m3o4p5q6r7s', TRUE),
('11111111-1111-1111-1111-111111111105', 'National MoSJE Admin', 'admin@mosje.gov.in', '+919876543214', 'national', 'National', '$2a$10$wE4oKzC5jVw9U7XG.oH0ve3nS5JzB12lZ3cQo9L1w2m3o4p5q6r7s', TRUE);

-- ------------------------------------------------------------------------------
-- 2. SEED VICTIMS
-- ------------------------------------------------------------------------------
INSERT INTO victims (id, case_id, language_pref, current_risk_tier, assigned_counsellor_id, contact_number, district, state, monitoring_active) VALUES
-- Longitudinal Escalating Case
('22222222-2222-2222-2222-222222222201', 'NHAA-2026-DL-00101', 'hi', 'Critical', '11111111-1111-1111-1111-111111111101', '+919811111101', 'South Delhi', 'Delhi', TRUE),
-- High Risk Case
('22222222-2222-2222-2222-222222222202', 'NHAA-2026-MH-00452', 'mr', 'High', '11111111-1111-1111-1111-111111111102', '+919811111102', 'Pune District', 'Maharashtra', TRUE),
-- Moderate Case
('22222222-2222-2222-2222-222222222203', 'NHAA-2026-MH-00388', 'en', 'Moderate', '11111111-1111-1111-1111-111111111102', '+919811111103', 'Pune District', 'Maharashtra', TRUE),
-- Low Risk (Stable) Case
('22222222-2222-2222-2222-222222222204', 'NHAA-2026-DL-00089', 'hi', 'Low', '11111111-1111-1111-1111-111111111101', '+919811111104', 'South Delhi', 'Delhi', TRUE);

-- ------------------------------------------------------------------------------
-- 3. SEED CONSENT (DPDP Compliance Ledger)
-- ------------------------------------------------------------------------------
INSERT INTO consent (id, victim_id, scope, status, granted_at, withdrawn_at, reason) VALUES
('33333333-3333-3333-3333-333333333301', '22222222-2222-2222-2222-222222222201', 'mental_health_monitoring', 'granted', NOW() - INTERVAL '30 days', NULL, 'Consent captured upon NHAA case registration via IVRS voice opt-in'),
('33333333-3333-3333-3333-333333333302', '22222222-2222-2222-2222-222222222202', 'mental_health_monitoring', 'granted', NOW() - INTERVAL '20 days', NULL, 'Explicit consent given via mobile check-in app'),
('33333333-3333-3333-3333-333333333303', '22222222-2222-2222-2222-222222222203', 'mental_health_monitoring', 'granted', NOW() - INTERVAL '15 days', NULL, 'Consent signed during counsellor intake interview'),
('33333333-3333-3333-3333-333333333304', '22222222-2222-2222-2222-222222222204', 'mental_health_monitoring', 'granted', NOW() - INTERVAL '40 days', NULL, 'Web portal onboarding consent checkbox');

-- ------------------------------------------------------------------------------
-- 4. SEED CHECK-INS & SCORES (Longitudinal Escalating Trajectory for Victim 1)
-- ------------------------------------------------------------------------------

-- T-14 days: Low Risk (DDS = 22)
INSERT INTO checkins (id, victim_id, channel, raw_text, audio_ref, response_latency_sec, metadata, is_missed, created_at) VALUES
('44444444-4444-4444-4444-444444444401', '22222222-2222-2222-2222-222222222201', 'chat', 'नमस्ते, आज ठीक लग रहा है। परिवार साथ है और सब सामान्य है।', NULL, 3.2, '{"mood": 4, "sleep_quality": "good", "safety_feeling": "secure"}'::jsonb, FALSE, NOW() - INTERVAL '14 days');

INSERT INTO scores (id, checkin_id, victim_id, dds_score, risk_tier, sentiment_label, emotion_signals, contributing_factors, escalation_flag, confidence_score, created_at) VALUES
('55555555-5555-5555-5555-555555555501', '44444444-4444-4444-4444-444444444401', '22222222-2222-2222-2222-222222222201', 22, 'Low', 'positive', '{"voice_stress": 0.15, "flat_affect": 0.10, "pitch_variance": 0.75}'::jsonb, '["Normal positive sentiment", "Good sleep reported", "Stable response latency"]'::jsonb, FALSE, 0.96, NOW() - INTERVAL '14 days');

-- T-7 days: Moderate Risk (DDS = 54)
INSERT INTO checkins (id, victim_id, channel, raw_text, audio_ref, response_latency_sec, metadata, is_missed, created_at) VALUES
('44444444-4444-4444-4444-444444444402', '22222222-2222-2222-2222-222222222201', 'ivrs', 'अदालत की तारीख आने वाली है, थोड़ी चिंता हो रही है और नींद नहीं आ रही।', 's3://nhaa-audio-vault/recordings/audio_00101_wk1.wav', 6.8, '{"mood": 2, "sleep_quality": "poor", "safety_feeling": "anxious"}'::jsonb, FALSE, NOW() - INTERVAL '7 days');

INSERT INTO scores (id, checkin_id, victim_id, dds_score, risk_tier, sentiment_label, emotion_signals, contributing_factors, escalation_flag, confidence_score, created_at) VALUES
('55555555-5555-5555-5555-555555555502', '44444444-4444-4444-4444-444444444402', '22222222-2222-2222-2222-222222222201', 54, 'Moderate', 'negative', '{"voice_stress": 0.48, "flat_affect": 0.35, "pitch_variance": 0.45}'::jsonb, '["Court hearing anticipation anxiety", "Sleep disturbances", "Increased latency"]'::jsonb, FALSE, 0.92, NOW() - INTERVAL '7 days');

-- T-3 days: High Risk (DDS = 78)
INSERT INTO checkins (id, victim_id, channel, raw_text, audio_ref, response_latency_sec, metadata, is_missed, created_at) VALUES
('44444444-4444-4444-4444-444444444403', '22222222-2222-2222-2222-222222222201', 'chat', 'धमकी भरे फोन आ रहे हैं। मैं बहुत डरा हुआ हूँ, घर से बाहर नहीं निकल पा रहा।', NULL, 12.4, '{"mood": 1, "sleep_quality": "none", "safety_feeling": "threatened"}'::jsonb, FALSE, NOW() - INTERVAL '3 days');

INSERT INTO scores (id, checkin_id, victim_id, dds_score, risk_tier, sentiment_label, emotion_signals, contributing_factors, escalation_flag, confidence_score, created_at) VALUES
('55555555-5555-5555-5555-555555555503', '44444444-4444-4444-4444-444444444403', '22222222-2222-2222-2222-222222222201', 78, 'High', 'distress-indicative', '{"voice_stress": 0.72, "flat_affect": 0.60, "pitch_variance": 0.20}'::jsonb, '["Threats reported in text", "Sharp +24 pt DDS increase in 4 days", "Severe insomnia"]'::jsonb, TRUE, 0.95, NOW() - INTERVAL '3 days');

-- Today: Critical Emergency Trigger (DDS = 92)
INSERT INTO checkins (id, victim_id, channel, raw_text, audio_ref, response_latency_sec, metadata, is_missed, created_at) VALUES
('44444444-4444-4444-4444-444444444404', '22222222-2222-2222-2222-222222222201', 'ivrs', 'मेरी मदद करो, मुझे नहीं पता मैं क्या करूँ... अब बर्दाश्त नहीं होता।', 's3://nhaa-audio-vault/recordings/audio_00101_crisis.wav', 18.2, '{"mood": 1, "sleep_quality": "none", "safety_feeling": "in_danger"}'::jsonb, FALSE, NOW() - INTERVAL '2 hours');

INSERT INTO scores (id, checkin_id, victim_id, dds_score, risk_tier, sentiment_label, emotion_signals, contributing_factors, escalation_flag, confidence_score, created_at) VALUES
('55555555-5555-5555-5555-555555555504', '44444444-4444-4444-4444-444444444404', '22222222-2222-2222-2222-222222222201', 92, 'Critical', 'distress-indicative', '{"voice_stress": 0.94, "flat_affect": 0.88, "pitch_variance": 0.08, "speech_rate": 65}'::jsonb, '["Explicit crisis call for help", "Extreme acoustic vocal tremor & flat affect", "Consecutive 3-checkin steep distress trajectory", "Response latency spike >18s"]'::jsonb, TRUE, 0.98, NOW() - INTERVAL '2 hours');

-- ------------------------------------------------------------------------------
-- 5. SEED ALERTS
-- ------------------------------------------------------------------------------
INSERT INTO alerts (id, victim_id, score_id, threshold_crossed, status, assigned_to, acknowledged_at, resolved_at, outcome_notes, created_at) VALUES
('66666666-6666-6666-6666-666666666601', '22222222-2222-2222-2222-222222222201', '55555555-5555-5555-5555-555555555504', 'DDS > 90 (Critical Escalation Threshold)', 'open', '11111111-1111-1111-1111-111111111101', NULL, NULL, NULL, NOW() - INTERVAL '2 hours'),
('66666666-6666-6666-6666-666666666602', '22222222-2222-2222-2222-222222222201', '55555555-5555-5555-5555-555555555503', 'DDS > 70 (High Risk)', 'acknowledged', '11111111-1111-1111-1111-111111111101', NOW() - INTERVAL '2 days', NULL, 'Counsellor acknowledged alert. Sent distress safety guideline via SMS.', NOW() - INTERVAL '3 days');

-- ------------------------------------------------------------------------------
-- 6. SEED AUDIT LOGS (DPDP Compliance Trail)
-- ------------------------------------------------------------------------------
INSERT INTO audit_log (id, actor_user_id, action, entity_type, entity_id, details, timestamp) VALUES
('77777777-7777-7777-7777-777777777701', '11111111-1111-1111-1111-111111111101', 'READ', 'victims', '22222222-2222-2222-2222-222222222201', '{"surface": "Counsellor Dashboard", "ip_address": "10.0.4.12", "action_detail": "Viewed DDS trend sparkline"}'::jsonb, NOW() - INTERVAL '2 days'),
('77777777-7777-7777-7777-777777777702', '11111111-1111-1111-1111-111111111101', 'ALERT_ACK', 'alerts', '66666666-6666-6666-6666-666666666602', '{"acknowledged_by": "Pooja Sharma", "status": "acknowledged"}'::jsonb, NOW() - INTERVAL '2 days'),
('77777777-7777-7777-7777-777777777703', NULL, 'WRITE', 'scores', '55555555-5555-5555-5555-555555555504', '{"origin": "AI Scoring Engine", "model_version": "v1.0.4", "computed_dds": 92}'::jsonb, NOW() - INTERVAL '2 hours');
