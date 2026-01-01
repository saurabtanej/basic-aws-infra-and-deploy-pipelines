# New Relic Monitoring & Observability

This document describes the New Relic Java Agent integration for APM monitoring.

## Table of Contents

- [Overview](#overview)
- [Setup](#setup)
- [How It Works](#how-it-works)
- [Configuration](#configuration)
- [Alerts](#alerts)
- [Custom Dashboard](#custom-dashboard)
- [Troubleshooting](#troubleshooting)

## Overview

We use the **New Relic Java Agent** (recommended approach) which provides:

| Feature | Description |
|---------|-------------|
| **Transaction Tracing** | End-to-end request traces with method-level detail |
| **APM Metrics** | Response time, throughput, error rates |
| **Code-level Insights** | Slow methods, database queries, external calls |
| **Error Tracking** | Stack traces, error grouping |
| **Distributed Tracing** | Cross-service request tracing |
| **Custom Metrics** | Via `@Trace` annotations and API |

## Setup

### 1. Create New Relic Account

1. Sign up for a [New Relic free trial](https://newrelic.com/signup)
2. Navigate to **Account Settings** → **API Keys**
3. Copy your **License Key** (INGEST - LICENSE type)

### 2. Store License Key in AWS Secrets Manager

```bash
aws secretsmanager create-secret \
  --name "java-api-dev/newrelic" \
  --description "New Relic License Key" \
  --secret-string "YOUR_LICENSE_KEY_HERE"
```

### 3. Configure Terragrunt/Terraform

In your environment's `terragrunt.hcl`:

```hcl
inputs = {
  newrelic_license_key_secret_arn = "arn:aws:secretsmanager:me-south-1:ACCOUNT_ID:secret:java-api-dev/newrelic-XXXXXX"
  newrelic_app_name = "java-api-dev"
}
```

## How It Works

The Java agent is embedded in the Docker image:

```dockerfile
# Stage 2: Download New Relic Agent
FROM amazoncorretto:21-alpine AS newrelic
RUN curl -O https://download.newrelic.com/newrelic/java-agent/newrelic-agent/8.8.0/newrelic-java-8.8.0.zip

# Stage 3: Runtime - Include agent
COPY --from=newrelic /newrelic/newrelic /app/newrelic

# Run with agent
CMD ["java", "-javaagent:/app/newrelic/newrelic.jar", "org.springframework.boot.loader.launch.JarLauncher"]
```

The agent is configured via environment variables set in ECS:

| Variable | Source |
|----------|--------|
| `NEW_RELIC_LICENSE_KEY` | AWS Secrets Manager |
| `NEW_RELIC_APP_NAME` | Terraform variable |
| `NEW_RELIC_DISTRIBUTED_TRACING_ENABLED` | Set to `true` |

## Configuration

### Agent Configuration File

Located at `src/main/resources/newrelic.yml`:

```yaml
common: &default_settings
  license_key: '<%= ENV["NEW_RELIC_LICENSE_KEY"] %>'
  app_name: '<%= ENV["NEW_RELIC_APP_NAME"] %>'
  
  distributed_tracing:
    enabled: true
  
  transaction_tracer:
    enabled: true
    record_sql: obfuscated
  
  error_collector:
    enabled: true
    ignore_status_codes: 404
```

### Custom Instrumentation

Use the `@Trace` annotation for custom instrumentation:

```java
import com.newrelic.api.agent.Trace;

@Trace(dispatcher = true)
public void myMethod() {
    // This method will appear in transaction traces
}
```

Add custom metrics:

```java
import com.newrelic.api.agent.NewRelic;

// Increment counter
NewRelic.incrementCounter("Custom/MyMetric/Count");

// Add custom attribute
NewRelic.addCustomParameter("userId", userId);
```

## Alerts

### Recommended Alert Policies

Create these in New Relic → Alerts & AI → Alert Conditions:

#### 1. High Error Rate

```
SELECT percentage(count(*), WHERE error IS true) 
FROM Transaction 
WHERE appName = 'java-api-dev'
```
- Threshold: > 5% for 5 minutes
- Severity: Critical

#### 2. Slow Response Time

```
SELECT percentile(duration, 95) 
FROM Transaction 
WHERE appName = 'java-api-dev'
```
- Threshold: > 2 seconds for 5 minutes
- Severity: Warning

#### 3. Low Apdex Score

```
SELECT apdex(duration, 0.5) 
FROM Transaction 
WHERE appName = 'java-api-dev'
```
- Threshold: < 0.7 for 5 minutes
- Severity: Warning

## Custom Dashboard

### Create Dashboard

1. Go to **Dashboards** → **Create a dashboard**
2. Add widgets with these queries:

```nrql
-- Throughput
SELECT rate(count(*), 1 minute) as 'Requests/min' 
FROM Transaction WHERE appName = 'java-api-dev' TIMESERIES

-- Response Time
SELECT average(duration) as 'Avg Response Time' 
FROM Transaction WHERE appName = 'java-api-dev' TIMESERIES

-- Error Rate
SELECT percentage(count(*), WHERE error IS true) as 'Error Rate' 
FROM Transaction WHERE appName = 'java-api-dev' TIMESERIES

-- Top Transactions
SELECT count(*) FROM Transaction 
WHERE appName = 'java-api-dev' 
FACET name LIMIT 10
```

## Troubleshooting

### Agent Not Reporting

1. **Check license key**: Verify secret exists in Secrets Manager
   ```bash
   aws secretsmanager get-secret-value --secret-id java-api-dev/newrelic
   ```

2. **Check ECS logs**: Look for agent startup messages
   ```bash
   aws logs get-log-events --log-group-name /ecs/java-api-dev
   ```

3. **Verify connectivity**: ECS tasks need outbound HTTPS to `collector.newrelic.com`

### Missing Transactions

1. Check `NEW_RELIC_APP_NAME` environment variable is set correctly
2. Look for "Connected to New Relic" in application logs
3. Wait 2-3 minutes for data to appear in New Relic

### High Overhead

If the agent causes performance issues:

1. Increase transaction threshold:
   ```yaml
   transaction_tracer:
     transaction_threshold: 2.0  # Only trace slow transactions
   ```

2. Reduce SQL recording:
   ```yaml
   transaction_tracer:
     record_sql: off
   ```

## Additional Resources

- [New Relic Java Agent Documentation](https://docs.newrelic.com/docs/apm/agents/java-agent/)
- [Java Agent Configuration](https://docs.newrelic.com/docs/apm/agents/java-agent/configuration/java-agent-configuration-config-file/)
- [Custom Instrumentation](https://docs.newrelic.com/docs/apm/agents/java-agent/custom-instrumentation/java-custom-instrumentation/)
