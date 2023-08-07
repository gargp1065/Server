package com.example.server.config;

import org.springframework.stereotype.Component;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.regex.Pattern;

@Component
public class ConfigValidation {

    private static final String FILE_NAME_REGEX = "([a-zA-Z0-9\\s_\\-\\(\\)])+[.]([a-zA-Z0-9])+$";
    private static final Pattern patternFileNameRegex = Pattern.compile(FILE_NAME_REGEX);

    /**
     * Validate the filePath from the config.
     * @param filePath: File path where the file is located.
     * @return boolean value is returned. True if valid file path and false if file path is invalid.
     */
    public boolean validateFilePath(final String filePath) {
        if (filePath == null || filePath.isEmpty()) {
            return false;
        }
        Path path = Paths.get(filePath);
        return Files.exists(path) && Files.isDirectory(path);
    }

    /**
     * check for fileName
     * currently only allows lowercase characters, uppercase characters, brackets (), _, -, followed by extension
     * @param fileName: Name of the file.
     * @return boolean value is returned. True if valid file name and false if file name is invalid.
     */
    public boolean validateFileName(final String fileName) {
        return patternFileNameRegex.matcher(fileName).matches();
    }

    public String validator(final String filePath, final String fileName) {
        if(!validateFilePath(filePath)) {
            return "File Path given is invalid on the server.";
        }
        if(!validateFileName(fileName)) {
            return "File Name given is invalid on the server.";
        }
        return "";
    }

}
