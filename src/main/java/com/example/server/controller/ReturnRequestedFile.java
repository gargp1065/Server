package com.example.server.controller;

import com.example.server.config.AppConfig;
import com.example.server.config.ConfigValidation;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import javax.servlet.http.HttpServletRequest;
import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

@RestController
public class ReturnRequestedFile {

    private final AppConfig appConfig;
    private static final Logger log = LogManager.getLogger(ReturnRequestedFile.class);
    private final ConfigValidation configValidation;
    @Autowired
    public ReturnRequestedFile(final AppConfig appConfig) {
        this.appConfig = appConfig;
        this.configValidation = new ConfigValidation();
    }

    @GetMapping("/download")
    public ResponseEntity<byte[]> fileController(@RequestHeader(value="X-Forwarded-For", required = false)
                                                         String forwardedForHeader, HttpServletRequest request)
            throws IOException {

        String fileName = "";
        String filePath = "";

        try {
             filePath = appConfig.getPath();
             fileName = appConfig.getFileName();
        } catch (Exception exception) {
            String errMessage = exception.getMessage();
            log.error(exception);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errMessage.getBytes(StandardCharsets.UTF_8));
        }
        final String configValidationResult = configValidation.validator(filePath, fileName);
        if(!configValidationResult.equals("")) {
            log.error(configValidationResult);
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(configValidationResult.getBytes(StandardCharsets.UTF_8));
        }

        final File file = new File(Paths.get(filePath + fileName).toString());

        // file doesn't exist on the server
        if(!file.exists()) {
            String errMessage = "File with name " + fileName + " on the path "+ filePath+ " doesn't exist.";
            log.error(errMessage);
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(errMessage.getBytes(StandardCharsets.UTF_8));
        }

        log.info("File Path is " +  filePath);
        log.info("File Name is " + fileName);
        final byte[] fileContent = Files.readAllBytes(Path.of(filePath + fileName));
        final String ipAddress;
        if(forwardedForHeader != null && !forwardedForHeader.isEmpty()) {
            ipAddress = forwardedForHeader.split(",")[0].trim();
        }
        else {
            ipAddress = request.getRemoteAddr();
        }
        log.info("Ip address is = "+ ipAddress);
        final HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.valueOf("application/json"));
        headers.setContentLength(fileContent.length);
        headers.setContentDispositionFormData("attachment", fileName);
        return ResponseEntity.ok()
                .headers(headers)
                .body(fileContent);
    }

}
