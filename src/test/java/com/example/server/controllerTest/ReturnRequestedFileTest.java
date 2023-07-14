package com.example.server.controllerTest;

import com.example.server.config.AppConfig;
import com.example.server.controller.ReturnRequestedFile;
import lombok.extern.log4j.Log4j2;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.when;

@Log4j2
public class ReturnRequestedFileTest {
    private ReturnRequestedFile returnRequestedFile;

    @Mock
    private AppConfig appConfig;

    @BeforeEach
    public void setup() {
        MockitoAnnotations.openMocks(this);
        returnRequestedFile = new ReturnRequestedFile(appConfig);
    }

    @Test
    public void testFileControllerReturnsFileContent() throws IOException {
        // Set the config values for the test case
        String testFilePath = "src/main/resources/static/";
        String testFileName = "sampleText123.txt";
        Path filePath = Path.of(testFilePath + testFileName);
        File testFile = new File(testFilePath);

        // Create a test file with some content
        String fileContent = "sampletesttest file.";
        Files.writeString(filePath, fileContent, StandardOpenOption.CREATE);

        // Mock the config values using Mockito
        when(appConfig.getPath()).thenReturn(testFilePath);
        when(appConfig.getFileName()).thenReturn(testFileName);

        // Invoke the fileController() method
        ResponseEntity<byte[]> responseEntity = returnRequestedFile.fileController("127.0.0.1", null);
        log.info(responseEntity);
        // Verify the response
        assertEquals(HttpStatus.OK, responseEntity.getStatusCode());
        assertEquals(fileContent.length(), responseEntity.getHeaders().getContentLength());
        assertEquals(testFileName, responseEntity.getHeaders().getContentDisposition().getFilename());

        // Cleanup - Delete the test file
        Files.deleteIfExists(filePath);
    }

    @Test
    public void testFileControllerReturnsNotFound() throws IOException {
        // Set a non-existing path to trigger not found response
        String nonExistingPath = "non-existing-file.txt";
        when(appConfig.getPath()).thenReturn(nonExistingPath);

        // Invoke the fileController() method
        ResponseEntity<byte[]> responseEntity = returnRequestedFile.fileController("127.0.0.1", null);

        // Verify the response
        assertEquals(HttpStatus.NOT_FOUND, responseEntity.getStatusCode());
    }

    @Test
    public void testFileControllerReturnsBadRequestForDirectory() throws IOException {
        // Set a directory path instead of a file to trigger bad request response
        // Cleanup - Delete the test directory
        String directoryPath = "src/test/test-files/";
        // Cleanup - Delete the test directory
        Files.deleteIfExists(Path.of(directoryPath));
        when(appConfig.getPath()).thenReturn(directoryPath);
        when(appConfig.getFileName()).thenReturn("");
        // Create a directory for testing
        Files.createDirectory(Path.of(directoryPath));

        // Invoke the fileController() method
        ResponseEntity<byte[]> responseEntity = returnRequestedFile.fileController("127.0.0.1", null);

        // Verify the response
        assertEquals(HttpStatus.NOT_FOUND, responseEntity.getStatusCode());

        // Cleanup - Delete the test directory
        Files.deleteIfExists(Path.of(directoryPath));
    }
}
