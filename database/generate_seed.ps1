# Script to convert synthetic_checkins.csv to database/seed_synthetic.sql
$csvPath = "database/synthetic_checkins.csv"
$outPath = "database/seed_synthetic.sql"

$districts = @(
    @{ District = "South Delhi"; State = "Delhi" },
    @{ District = "Pune District"; State = "Maharashtra" },
    @{ District = "Nagpur"; State = "Maharashtra" },
    @{ District = "Jaipur"; State = "Rajasthan" },
    @{ District = "Lucknow"; State = "Uttar Pradesh" },
    @{ District = "Bhopal"; State = "Madhya Pradesh" },
    @{ District = "Hyderabad"; State = "Telangana" },
    @{ District = "Bengaluru Urban"; State = "Karnataka" },
    @{ District = "Ahmedabad"; State = "Gujarat" },
    @{ District = "Patna"; State = "Bihar" }
)

$counsellorIds = @(
    "11111111-1111-1111-1111-111111111101",
    "11111111-1111-1111-1111-111111111102"
)

$rows = Import-Csv -Path $csvPath

# Group by victim_id to extract victim profiles
$victimGroups = $rows | Group-Object -Property victim_id

$sb = [System.Text.StringBuilder]::new()

[void]$sb.AppendLine("-- ==============================================================================")
[void]$sb.AppendLine("-- SIH26094: SYNTHETIC DATASET SEED SCRIPT (100 VICTIMS, 731 CHECKINS)")
[void]$sb.AppendLine("-- Generated from ML team's synthetic_checkins.csv")
[void]$sb.AppendLine("-- Target Schema: schema.sql (PostgreSQL)")
[void]$sb.AppendLine("-- ==============================================================================")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("TRUNCATE TABLE audit_log, alerts, scores, checkins, consent, victims, users CASCADE;")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("-- ------------------------------------------------------------------------------")
[void]$sb.AppendLine("-- 1. SEED USERS (Staff Hierarchy)")
[void]$sb.AppendLine("-- ------------------------------------------------------------------------------")
[void]$sb.AppendLine("INSERT INTO users (id, name, email, phone, role, jurisdiction, password_hash, is_active) VALUES")
[void]$sb.AppendLine("('11111111-1111-1111-1111-111111111101', 'Pooja Sharma', 'pooja.counsellor@nhaa.gov.in', '+919876543210', 'counsellor', 'South Delhi', '`$2a`$10`$wE4oKzC5jVw9U7XG.oH0ve3nS5JzB12lZ3cQo9L1w2m3o4p5q6r7s', TRUE),")
[void]$sb.AppendLine("('11111111-1111-1111-1111-111111111102', 'Amit Verma', 'amit.counsellor@nhaa.gov.in', '+919876543211', 'counsellor', 'Pune District', '`$2a`$10`$wE4oKzC5jVw9U7XG.oH0ve3nS5JzB12lZ3cQo9L1w2m3o4p5q6r7s', TRUE),")
[void]$sb.AppendLine("('11111111-1111-1111-1111-111111111103', 'Rajesh Patil', 'rajesh.district@nhaa.gov.in', '+919876543212', 'district', 'Pune District', '`$2a`$10`$wE4oKzC5jVw9U7XG.oH0ve3nS5JzB12lZ3cQo9L1w2m3o4p5q6r7s', TRUE),")
[void]$sb.AppendLine("('11111111-1111-1111-1111-111111111104', 'Dr. Meena Iyer', 'meena.state@nhaa.gov.in', '+919876543213', 'state', 'Maharashtra', '`$2a`$10`$wE4oKzC5jVw9U7XG.oH0ve3nS5JzB12lZ3cQo9L1w2m3o4p5q6r7s', TRUE),")
[void]$sb.AppendLine("('11111111-1111-1111-1111-111111111105', 'National MoSJE Admin', 'admin@mosje.gov.in', '+919876543214', 'national', 'National', '`$2a`$10`$wE4oKzC5jVw9U7XG.oH0ve3nS5JzB12lZ3cQo9L1w2m3o4p5q6r7s', TRUE);")
[void]$sb.AppendLine("")

[void]$sb.AppendLine("-- ------------------------------------------------------------------------------")
[void]$sb.AppendLine("-- 2. SEED VICTIMS (100 Cases)")
[void]$sb.AppendLine("-- ------------------------------------------------------------------------------")
[void]$sb.AppendLine("INSERT INTO victims (id, case_id, language_pref, current_risk_tier, assigned_counsellor_id, contact_number, district, state, monitoring_active) VALUES")

$victimSqlLines = @()
$consentSqlLines = @()

foreach ($vg in $victimGroups) {
    $rawVicId = $vg.Name # e.g. VIC-0001
    $numStr = $rawVicId.Replace("VIC-", "")
    $num = [int]$numStr
    $vicUUID = "22222222-2222-2222-0000-" + $num.ToString("D12")
    $consentUUID = "33333333-3333-3333-0000-" + $num.ToString("D12")

    $firstRow = $vg.Group[0]
    $lastRow = $vg.Group[-1]
    $lang = $firstRow.language
    $latestTier = $lastRow.simulated_tier

    $loc = $districts[($num - 1) % $districts.Count]
    $counsellor = $counsellorIds[($num - 1) % $counsellorIds.Count]
    $contact = "+9198100" + $num.ToString("D5")
    $caseId = "NHAA-2026-" + $loc.State.Substring(0, [Math]::Min(2, $loc.State.Length)).ToUpper() + "-" + $num.ToString("D5")

    $victimSqlLines += "('$vicUUID', '$caseId', '$lang', '$latestTier', '$counsellor', '$contact', '$($loc.District)', '$($loc.State)', TRUE)"
    $consentSqlLines += "('$consentUUID', '$vicUUID', 'mental_health_monitoring', 'granted', NOW() - INTERVAL '60 days', NULL, 'Consent captured during NHAA onboarding')"
}

[void]$sb.AppendLine(($victimSqlLines -join ",`n") + ";")
[void]$sb.AppendLine("")

[void]$sb.AppendLine("-- ------------------------------------------------------------------------------")
[void]$sb.AppendLine("-- 3. SEED CONSENT (DPDP Compliance Ledger)")
[void]$sb.AppendLine("-- ------------------------------------------------------------------------------")
[void]$sb.AppendLine("INSERT INTO consent (id, victim_id, scope, status, granted_at, withdrawn_at, reason) VALUES")
[void]$sb.AppendLine(($consentSqlLines -join ",`n") + ";")
[void]$sb.AppendLine("")

[void]$sb.AppendLine("-- ------------------------------------------------------------------------------")
[void]$sb.AppendLine("-- 4. SEED CHECKINS & SCORES (Sequential Longitudinal Data)")
[void]$sb.AppendLine("-- ------------------------------------------------------------------------------")

$checkinSqlLines = @()
$scoreSqlLines = @()
$alertSqlLines = @()

$alertCount = 0

foreach ($r in $rows) {
    # e.g. CHK-0001-00
    $parts = $r.checkin_id.Split("-")
    $vNum = [int]$parts[1]
    $cIdx = [int]$parts[2]

    $chkUUID = "44444444-4444-" + $vNum.ToString("D4") + "-0000-" + $cIdx.ToString("D12")
    $scoreUUID = "55555555-5555-" + $vNum.ToString("D4") + "-0000-" + $cIdx.ToString("D12")
    $vicUUID = "22222222-2222-2222-0000-" + $vNum.ToString("D12")

    $channel = $r.channel
    $tier = $r.simulated_tier
    $isMissed = if ($r.missed_checkin -eq '1') { "TRUE" } else { "FALSE" }
    $latency = [double]$r.response_latency_sec
    $ts = $r.timestamp + "+00"
    $escapedText = $r.raw_text.Replace("'", "''")

    $audioRef = if ($channel -eq "ivrs") { "'s3://nhaa-audio-vault/recordings/$($r.checkin_id).wav'" } else { "NULL" }

    # Realistic metadata based on tier
    $mood = 3
    $sleep = "average"
    $safety = "stable"
    if ($tier -eq "Low") {
        $mood = 4; $sleep = "good"; $safety = "secure"
    } elseif ($tier -eq "Moderate") {
        $mood = 3; $sleep = "poor"; $safety = "anxious"
    } elseif ($tier -eq "High") {
        $mood = 2; $sleep = "interrupted"; $safety = "threatened"
    } elseif ($tier -eq "Critical") {
        $mood = 1; $sleep = "none"; $safety = "in_danger"
    }
    $metaJson = "'{""mood"": $mood, ""sleep_quality"": ""$sleep"", ""safety_feeling"": ""$safety""}'::jsonb"

    $checkinSqlLines += "('$chkUUID', '$vicUUID', '$channel', '$escapedText', $audioRef, $latency, $metaJson, $isMissed, '$ts')"

    # Score calculation
    $baseDds = 20
    $sentiment = "positive"
    $voiceStress = 0.15
    $flatAffect = 0.10
    $pitchVar = 0.70
    $escalationFlag = "FALSE"
    $factors = '["Normal sentiment", "Regular response latency"]'

    if ($tier -eq "Low") {
        $baseDds = 18 + ($cIdx * 2 % 15)
        $sentiment = "positive"
        $voiceStress = 0.15 + ($cIdx * 0.01)
        $flatAffect = 0.12
        $pitchVar = 0.75
        $escalationFlag = "FALSE"
        $factors = '["Positive sentiment expression", "Stable baseline response latency", "No threat indicators detected"]'
    } elseif ($tier -eq "Moderate") {
        $baseDds = 45 + ($cIdx * 3 % 20)
        $sentiment = "neutral"
        $voiceStress = 0.45 + ($cIdx * 0.02)
        $flatAffect = 0.35
        $pitchVar = 0.45
        $escalationFlag = "FALSE"
        $factors = '["Elevated acoustic stress markers", "Anxiety regarding trial proceedings", "Neighborhood social isolation reported"]'
    } elseif ($tier -eq "High") {
        $baseDds = 75 + ($cIdx * 2 % 12)
        $sentiment = "distress-indicative"
        $voiceStress = 0.78
        $flatAffect = 0.65
        $pitchVar = 0.22
        $escalationFlag = "TRUE"
        $factors = '["Explicit threat and harassment keywords", "Steep +20 pt distress trajectory", "Response latency spike >35s", "Acoustic tremor detected"]'
    } elseif ($tier -eq "Critical") {
        $baseDds = 91 + ($cIdx * 2 % 8)
        $sentiment = "distress-indicative"
        $voiceStress = 0.94
        $flatAffect = 0.88
        $pitchVar = 0.08
        $escalationFlag = "TRUE"
        $factors = '["Direct threat to physical life", "Immediate crisis intervention requested", "Acute acoustic vocal tremor and flat affect", "Severe response latency"]'
    }

    $emotionSignals = "'{""voice_stress"": $voiceStress, ""flat_affect"": $flatAffect, ""pitch_variance"": $pitchVar}'::jsonb"
    $factorsJson = "'$factors'::jsonb"
    $conf = 0.94 + ($cIdx * 0.005)
    if ($conf -gt 0.99) { $conf = 0.98 }

    $scoreSqlLines += "('$scoreUUID', '$chkUUID', '$vicUUID', $baseDds, '$tier', '$sentiment', $emotionSignals, $factorsJson, $escalationFlag, $conf, '$ts')"

    # Create alerts for High and Critical
    if ($tier -eq "High" -or $tier -eq "Critical") {
        $alertCount++
        $alertUUID = "66666666-6666-" + $vNum.ToString("D4") + "-0000-" + $cIdx.ToString("D12")
        $threshold = if ($tier -eq "Critical") { "DDS > 90 (Critical Emergency Escalation)" } else { "DDS > 70 (High Risk Detected)" }
        $counsellor = $counsellorIds[($vNum - 1) % $counsellorIds.Count]
        $alertStatus = if ($alertCount % 4 -eq 0) { "acknowledged" } else { "open" }
        $ackAt = if ($alertStatus -eq "acknowledged") { "'$ts'::timestamptz + interval '1 hour'" } else { "NULL" }
        $outcomeNotes = if ($alertStatus -eq "acknowledged") { "'Counsellor contacted victim; verified local support.'"} else { "NULL" }

        $alertSqlLines += "('$alertUUID', '$vicUUID', '$scoreUUID', '$threshold', '$alertStatus', '$counsellor', $ackAt, NULL, $outcomeNotes, '$ts')"
    }
}

# Batch write checkins in chunks of 100 to avoid giant SQL statements
$chunkSize = 100
for ($i = 0; $i -lt $checkinSqlLines.Count; $i += $chunkSize) {
    $chunk = $checkinSqlLines[$i..[Math]::Min($i + $chunkSize - 1, $checkinSqlLines.Count - 1)]
    [void]$sb.AppendLine("INSERT INTO checkins (id, victim_id, channel, raw_text, audio_ref, response_latency_sec, metadata, is_missed, created_at) VALUES")
    [void]$sb.AppendLine(($chunk -join ",`n") + ";`n")
}

for ($i = 0; $i -lt $scoreSqlLines.Count; $i += $chunkSize) {
    $chunk = $scoreSqlLines[$i..[Math]::Min($i + $chunkSize - 1, $scoreSqlLines.Count - 1)]
    [void]$sb.AppendLine("INSERT INTO scores (id, checkin_id, victim_id, dds_score, risk_tier, sentiment_label, emotion_signals, contributing_factors, escalation_flag, confidence_score, created_at) VALUES")
    [void]$sb.AppendLine(($chunk -join ",`n") + ";`n")
}

[void]$sb.AppendLine("-- ------------------------------------------------------------------------------")
[void]$sb.AppendLine("-- 5. SEED ALERTS ($($alertSqlLines.Count) Alerts Generated)")
[void]$sb.AppendLine("-- ------------------------------------------------------------------------------")
for ($i = 0; $i -lt $alertSqlLines.Count; $i += $chunkSize) {
    $chunk = $alertSqlLines[$i..[Math]::Min($i + $chunkSize - 1, $alertSqlLines.Count - 1)]
    [void]$sb.AppendLine("INSERT INTO alerts (id, victim_id, score_id, threshold_crossed, status, assigned_to, acknowledged_at, resolved_at, outcome_notes, created_at) VALUES")
    [void]$sb.AppendLine(($chunk -join ",`n") + ";`n")
}

[System.IO.File]::WriteAllText($outPath, $sb.ToString(), [System.Text.Encoding]::UTF8)
Write-Host "Successfully generated $outPath with $($rows.Count) checkins and $($alertSqlLines.Count) alerts."
