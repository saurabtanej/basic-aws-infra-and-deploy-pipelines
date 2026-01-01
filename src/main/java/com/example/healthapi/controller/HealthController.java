package com.example.healthapi.controller;

import com.newrelic.api.agent.NewRelic;
import com.newrelic.api.agent.Trace;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

/**
 * REST Controller providing health check and status endpoints.
 * 
 * Endpoints:
 * - GET /health - Simple health check (used by ALB)
 * - GET /       - Welcome message
 * - GET /info   - Application information
 */
@RestController
public class HealthController {

    @Value("${spring.application.name:health-api}")
    private String applicationName;

    @Value("${app.version:1.0.0}")
    private String appVersion;

    @Value("${ENVIRONMENT:local}")
    private String environment;

    /**
     * Health check endpoint for ALB and container health checks.
     * Returns a simple status response.
     */
    @GetMapping("/health")
    @Trace(dispatcher = true)
    public ResponseEntity<Map<String, Object>> health() {
        // Record custom metric in New Relic
        NewRelic.incrementCounter("Custom/HealthCheck/Count");
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "ok");
        response.put("timestamp", Instant.now().toString());
        
        return ResponseEntity.ok(response);
    }

    /**
     * Root endpoint with welcome message.
     */
    @GetMapping("/")
    @Trace(dispatcher = true)
    public ResponseEntity<Map<String, String>> root() {
        Map<String, String> response = new HashMap<>();
        response.put("message", "Welcome to " + applicationName);
        response.put("version", appVersion);
        response.put("environment", environment);
        
        return ResponseEntity.ok(response);
    }

    /**
     * Info endpoint providing application details.
     */
    @GetMapping("/info")
    @Trace(dispatcher = true)
    public ResponseEntity<Map<String, Object>> info() {
        Map<String, Object> response = new HashMap<>();
        response.put("application", applicationName);
        response.put("version", appVersion);
        response.put("environment", environment);
        response.put("java_version", System.getProperty("java.version"));
        response.put("timestamp", Instant.now().toString());
        
        // Add custom attribute to New Relic transaction
        NewRelic.addCustomParameter("environment", environment);
        NewRelic.addCustomParameter("app_version", appVersion);
        
        return ResponseEntity.ok(response);
    }
}

