package com.example.server;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.security.servlet.SecurityAutoConfiguration;
import org.springframework.context.annotation.PropertySource;

@SpringBootApplication(exclude = SecurityAutoConfiguration.class)
public class ServerApplication implements ApplicationRunner {

    @Value("${spring.config.location:}")
    private String configLocation;
    private static final Logger log = LogManager.getLogger(ServerApplication.class);

    public static void main(String[] args) {
        SpringApplication.run(ServerApplication.class, args);
    }

    @Override
    public void run(ApplicationArguments args) throws Exception {
        if (configLocation.isEmpty()) {
            log.error("Error: --spring.config.location parameter is missing.");
            throw new RuntimeException("Spring config file is missing. Server cannot start.");
        }
    }
}
