package com.example.server.config;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.regex.Pattern;

public class ConfigValidation {

    private static String FILE_NAME_REGEX = "([a-zA-Z0-9\\s_\\-\\(\\)])+[.]([a-zA-Z0-9])+$";
    private static final Pattern patternFileNameRegex = Pattern.compile(FILE_NAME_REGEX);

    public static boolean validateFilePath(final String filePath) {
        if (filePath == null || filePath.isEmpty()) {
            return false;
        }
        Path path = Paths.get(filePath);
        return Files.exists(path) && Files.isDirectory(path);
    }

    // check for fileName
    // currently only allows lowercase characters, uppercase charatcers, brackets (), _, -, followed by extension
    public static boolean validateFileName(final String fileName) {
        return patternFileNameRegex.matcher(fileName).matches();
    }

}
