package com.example.server.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.PropertySource;

@Configuration
@PropertySource("classpath:config.properties")
public class AppConfig {
    @Value("${file.path}")
    private String path;

    @Value("${file.name}")
    private String fileName;

    public String getPath() {
        return path;
    }

    public String getFileName() {
        return fileName;
    }
}