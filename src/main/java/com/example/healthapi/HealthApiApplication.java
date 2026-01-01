package com.example.healthapi;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Main Spring Boot Application class.
 * 
 * This is a simple REST API designed for the DevOps take-home exercise.
 * It provides health check endpoints and demonstrates New Relic integration.
 */
@SpringBootApplication
public class HealthApiApplication {

    public static void main(String[] args) {
        SpringApplication.run(HealthApiApplication.class, args);
    }
}

