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

    @Autowired
    public ReturnRequestedFile(AppConfig appConfig) {
        this.appConfig = appConfig;
    }

    @GetMapping("/download")
    public ResponseEntity<byte[]> fileController(@RequestHeader(value="X-Forwarded-For", required = false)
                                                         String forwardedForHeader, HttpServletRequest request)
            throws IOException {

        String filePath = appConfig.getPath();
        String fileName = appConfig.getFileName();
        System.out.println("FilePath address is: " + filePath);
        System.out.println("FileName is: " + fileName);

        if(!ConfigValidation.validateFilePath(filePath)) {
            return ResponseEntity.notFound().build();
        }

        if(!ConfigValidation.validateFileName(fileName)) {
            return ResponseEntity.notFound().build();
        }

        File file = new File(Paths.get(filePath + fileName).toString());

        // file doesn't exists on the server
        if(!file.exists()) {
            return ResponseEntity.notFound().build();
        }

        // the resource is not a file.
        if (!file.isFile()) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).build();
        }

        byte[] fileContent = Files.readAllBytes(Path.of(filePath + fileName));
        String ipAddress;
        if(forwardedForHeader != null && !forwardedForHeader.isEmpty()) {
            ipAddress = forwardedForHeader.split(",")[0].trim();
        }
        else {
            ipAddress = request.getRemoteAddr();
        }
        System.out.println("Ip address is: " + ipAddress);
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.valueOf("application/json"));
        headers.setContentLength(fileContent.length);
        headers.setContentDispositionFormData("attachment", fileName);
        return ResponseEntity.ok()
                .headers(headers)
                .body(fileContent);
    }

}
