package com.example.server.alert;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.io.BufferedReader;
import java.io.InputStreamReader;


public class Alert {


    final private static Logger logger = LogManager.getLogger(Alert.class);


    public void raiseAnAlert(String alertCode, String alertMessage, String alertProcess, int userId) {
        try {   // <e>  alertMessage    //      <process_name> alertProcess
            String path = System.getenv("APP_HOME") + "alert/start.sh";
            ProcessBuilder pb = new ProcessBuilder(path, alertCode, alertMessage, alertProcess, String.valueOf(userId));
            Process p = pb.start();
            logger.error(p);
            BufferedReader reader = new BufferedReader(new InputStreamReader(p.getInputStream()));
            String line = null;
            String response = null;
            while ((line = reader.readLine()) != null) {
                response += line;
            }
            logger.info("Alert is generated :response " + response);
        } catch (Exception ex) {
            logger.error("Not able to execute Alert management jar ", ex.getLocalizedMessage() + " ::: " + ex.getMessage());
        }
    }

}
