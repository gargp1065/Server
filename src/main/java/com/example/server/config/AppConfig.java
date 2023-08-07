package com.example.server.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.PropertySource;

@Configuration
public class AppConfig {
    @Value("${file.path:#{null}}")
    private String path;

    @Value("${file.name:#{null}}")
    private String fileName;

    public String getPath() {
        if(this.path == null || this.path.equals("${file.name}"))
            throw new IllegalArgumentException("File Path must be configured at the server.");
        return path;
    }

    public String getFileName() {
        if(this.fileName == null || this.fileName.equals("${file.name}"))
            throw new IllegalArgumentException("File Name must be configured at the server.");
        return fileName;
    }
}