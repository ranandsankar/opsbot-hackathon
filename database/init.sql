-- OpsBot Hackathon - Database Schema & Sample Data
-- Target: Cloud SQL PostgreSQL or AlloyDB

DROP TABLE IF EXISTS tasks CASCADE;
DROP TABLE IF EXISTS incidents CASCADE;
DROP TABLE IF EXISTS runbooks CASCADE;
DROP TABLE IF EXISTS on_call_schedule CASCADE;
DROP TABLE IF EXISTS services CASCADE;

CREATE TABLE services (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    team VARCHAR(100) NOT NULL,
    slo_target DECIMAL(5,2) DEFAULT 99.9,
    current_slo DECIMAL(5,2) DEFAULT 99.95,
    status VARCHAR(20) DEFAULT 'healthy',
    tier VARCHAR(10) DEFAULT 'T2',
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE incidents (
    id SERIAL PRIMARY KEY,
    service_id INTEGER REFERENCES services(id),
    severity VARCHAR(5) NOT NULL,
    category VARCHAR(50) NOT NULL,
    subsystem VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(20) DEFAULT 'open',
    root_cause TEXT,
    resolution TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP,
    mttr_minutes INTEGER
);

CREATE TABLE runbooks (
    id SERIAL PRIMARY KEY,
    category VARCHAR(50) NOT NULL,
    subsystem VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    steps TEXT NOT NULL,
    escalation_policy TEXT,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE on_call_schedule (
    id SERIAL PRIMARY KEY,
    team VARCHAR(100) NOT NULL,
    engineer VARCHAR(100) NOT NULL,
    role VARCHAR(50) DEFAULT 'primary',
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    contact_method VARCHAR(50) DEFAULT 'slack'
);

CREATE TABLE tasks (
    id SERIAL PRIMARY KEY,
    incident_id INTEGER REFERENCES incidents(id),
    assignee VARCHAR(100) NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(20) DEFAULT 'open',
    priority VARCHAR(10) DEFAULT 'medium',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    due_date TIMESTAMP,
    completed_at TIMESTAMP
);

-- Services
INSERT INTO services (name, team, slo_target, current_slo, status, tier, description) VALUES
('api-gateway',       'Platform',   99.99, 99.97, 'healthy',  'T0', 'Main API gateway - all external traffic'),
('auth-service',      'Identity',   99.95, 99.92, 'healthy',  'T0', 'Authentication and authorization'),
('payment-service',   'Payments',   99.99, 99.85, 'degraded', 'T0', 'Payment processing and billing'),
('search-service',    'Discovery',  99.9,  99.88, 'healthy',  'T1', 'Full-text and vector search'),
('user-service',      'Identity',   99.95, 99.96, 'healthy',  'T1', 'User profile management'),
('notification-svc',  'Engagement', 99.5,  99.7,  'healthy',  'T2', 'Push, email, SMS notifications'),
('analytics-pipeline','Data',       99.0,  98.5,  'degraded', 'T2', 'Real-time event processing'),
('image-service',     'Media',      99.9,  99.91, 'healthy',  'T1', 'Image upload and CDN'),
('recommendation-engine','ML',      99.5,  99.3,  'degraded', 'T2', 'ML-based recommendations'),
('inventory-service', 'Commerce',   99.95, 99.94, 'healthy',  'T1', 'Real-time inventory tracking');

-- Incidents (open + resolved)
INSERT INTO incidents (service_id, severity, category, subsystem, title, description, status, root_cause, resolution, created_at, resolved_at, mttr_minutes) VALUES
(3, 'P1', 'high_latency', 'database', 'Payment processing latency spike',
 'p99 latency jumped to 12s on /v2/payments/process. Multiple downstream timeouts.', 'investigating', NULL, NULL, NOW() - INTERVAL '2 hours', NULL, NULL),
(7, 'P2', 'data_corruption', 'queue', 'Analytics events dropping in Kafka',
 'Consumer lag growing. ~15% events dropped or out of order.', 'open', NULL, NULL, NOW() - INTERVAL '5 hours', NULL, NULL),
(9, 'P3', 'high_latency', 'cache', 'Recommendation cache miss rate elevated',
 'Redis miss rate from 5% to 40% after deploy. Latency up 3x.', 'open', NULL, NULL, NOW() - INTERVAL '1 hour', NULL, NULL),
(1, 'P1', 'connection_timeout', 'load_balancer', 'API Gateway 502 errors spike',
 '502 errors affecting 30% of requests. Backends report healthy.', 'resolved',
 'Envoy connection pool exhausted', 'Increased pool limits, added circuit breaker',
 NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days' + INTERVAL '47 minutes', 47),
(2, 'P2', 'certificate_expiry', 'auth_service', 'Auth TLS cert expiring in 2 hours',
 'cert-manager renewal failed after cluster migration.', 'resolved',
 'Wrong ACME solver config', 'Fixed ClusterIssuer, forced renewal',
 NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days' + INTERVAL '23 minutes', 23),
(3, 'P1', 'crash_loop', 'kubernetes', 'Payment service CrashLoopBackOff',
 'All v2.4.1 pods in CrashLoopBackOff. Previous version stable.', 'resolved',
 'Missing STRIPE_WEBHOOK_SECRET in ConfigMap', 'Added env var, rolled forward',
 NOW() - INTERVAL '7 days', NOW() - INTERVAL '7 days' + INTERVAL '15 minutes', 15),
(4, 'P2', 'memory_leak', 'search_service', 'Search OOMKilled repeatedly',
 'search-indexer OOMKilled every ~4h. Heap growing linearly.', 'resolved',
 'Lucene segment merge holding deleted doc refs', 'Updated merge config, increased to 8Gi',
 NOW() - INTERVAL '10 days', NOW() - INTERVAL '10 days' + INTERVAL '180 minutes', 180),
(6, 'P3', 'rate_limiting', 'api_gateway', 'Notification hitting SendGrid limits',
 'Bulk email triggered rate limiting. Queue backing up.', 'resolved',
 '500k campaign without coordination', 'Added backoff queue, campaign process',
 NOW() - INTERVAL '14 days', NOW() - INTERVAL '14 days' + INTERVAL '60 minutes', 60),
(10, 'P3', 'high_latency', 'database', 'Inventory slow during flash sale',
 'Queries taking 5s+. Missing composite index.', 'resolved',
 'Missing index on product_id + warehouse_id', 'Added index, added read replica',
 NOW() - INTERVAL '30 days', NOW() - INTERVAL '30 days' + INTERVAL '90 minutes', 90);

-- Runbooks
INSERT INTO runbooks (category, subsystem, title, steps, escalation_policy) VALUES
('high_latency', 'database', 'Database Latency Investigation',
 '1. Check slow queries: SELECT * FROM pg_stat_activity WHERE state != ''idle''
2. Review connection pool in Grafana
3. Check lock contention: SELECT * FROM pg_locks WHERE granted = false
4. Review recent migrations
5. Verify read replicas if read-heavy
6. Check disk I/O metrics',
 'If p99 > 5s for >10 min, page DB on-call'),
('crash_loop', 'kubernetes', 'CrashLoopBackOff Runbook',
 '1. kubectl describe pod <pod> -n <ns>
2. kubectl logs <pod> --previous
3. Check resource limits in pod yaml
4. Check recent ConfigMap/Secret changes
5. Compare with last working deploy
6. Rollback: kubectl rollout undo deployment/<n>',
 'If rollback fails after 15 min, page service owner'),
('memory_leak', 'search_service', 'Memory Leak Investigation',
 '1. kubectl top pods -n <ns> --sort-by=memory
2. Capture heap dump before restart
3. Check GC logs
4. Restart pods: kubectl rollout restart
5. Monitor memory post-restart
6. Analyze heap dump if recurring',
 'If memory climbs back in 30 min, escalate with heap dump'),
('connection_timeout', 'load_balancer', 'Connection Timeout / 502 Errors',
 '1. Check upstream: kubectl get endpoints
2. Verify proxy config and pool settings
3. Test direct: curl -v <pod-ip>:<port>/health
4. Check network policies
5. Review recent proxy changes
6. Temporarily increase pool limits',
 'If 502 > 10% for >5 min, escalate to platform'),
('data_corruption', 'queue', 'Kafka Pipeline Issues',
 '1. Check consumer lag: kafka-consumer-groups --describe
2. Verify topic health
3. Check broker issues
4. Review producer error rates
5. Identify affected time range
6. Replay from last good offset',
 'If data loss confirmed, escalate to data eng immediately'),
('rate_limiting', 'api_gateway', 'Rate Limiting Response',
 '1. Identify traffic source from access logs
2. Determine legit vs malicious
3. If legit: increase limits temporarily
4. If malicious: add WAF rules
5. Enable request queuing
6. Monitor and adjust gradually',
 'If DDoS suspected, escalate to security'),
('config_error', 'kubernetes', 'Config Error Response',
 '1. git log --oneline -10 in config repo
2. diff old vs new config
3. kubectl get configmap -o yaml
4. Verify env injection: kubectl exec -- env
5. Rollback: kubectl rollout undo
6. If GitOps, revert commit',
 'If source unclear, escalate to release eng'),
('certificate_expiry', 'auth_service', 'TLS Cert Emergency Renewal',
 '1. Check expiry: openssl s_client -connect host:443
2. kubectl describe certificate
3. Check cert-manager logs
4. Force renewal: delete and reapply cert
5. Verify new cert in kubectl
6. Confirm propagation to all endpoints',
 'If auto-renewal broken, page platform/security');

-- On-Call Schedule
INSERT INTO on_call_schedule (team, engineer, role, start_date, end_date, contact_method) VALUES
('Platform',   'Alice Chen',    'primary',   CURRENT_DATE, CURRENT_DATE + 7, 'slack'),
('Platform',   'Bob Martinez',  'secondary', CURRENT_DATE, CURRENT_DATE + 7, 'phone'),
('Identity',   'Carol Kim',     'primary',   CURRENT_DATE, CURRENT_DATE + 7, 'slack'),
('Payments',   'Eve Johnson',   'primary',   CURRENT_DATE, CURRENT_DATE + 7, 'phone'),
('Payments',   'Frank Liu',     'secondary', CURRENT_DATE, CURRENT_DATE + 7, 'slack'),
('Discovery',  'Grace Park',    'primary',   CURRENT_DATE, CURRENT_DATE + 7, 'slack'),
('Data',       'Henry Wilson',  'primary',   CURRENT_DATE, CURRENT_DATE + 7, 'phone'),
('ML',         'Iris Nakamura', 'primary',   CURRENT_DATE, CURRENT_DATE + 7, 'slack'),
('Commerce',   'Jack Thompson', 'primary',   CURRENT_DATE, CURRENT_DATE + 7, 'slack');

-- Tasks
INSERT INTO tasks (incident_id, assignee, title, description, status, priority, due_date) VALUES
(1, 'Eve Johnson',  'Investigate payment DB slow queries', 'Run EXPLAIN ANALYZE on top 5 slow queries', 'in_progress', 'critical', NOW() + INTERVAL '2 hours'),
(1, 'Frank Liu',    'Check connection pool saturation',    'Review PgBouncer metrics', 'open', 'high', NOW() + INTERVAL '4 hours'),
(2, 'Henry Wilson', 'Investigate Kafka consumer lag',      'Check consumer group offsets', 'in_progress', 'high', NOW() + INTERVAL '3 hours'),
(2, 'Henry Wilson', 'Verify event ordering',               'Audit partition key strategy', 'open', 'medium', NOW() + INTERVAL '1 day'),
(3, 'Iris Nakamura','Investigate Redis cache miss spike',  'Check eviction policy post-deploy', 'open', 'medium', NOW() + INTERVAL '6 hours');

SELECT 'Services: ' || COUNT(*) FROM services;
SELECT 'Incidents: ' || COUNT(*) FROM incidents;
SELECT 'Runbooks: ' || COUNT(*) FROM runbooks;
SELECT 'On-Call: ' || COUNT(*) FROM on_call_schedule;
SELECT 'Tasks: ' || COUNT(*) FROM tasks;
