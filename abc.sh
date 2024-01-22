# some utility functions to make script more readable
executionStartTime=$(date +%s.%N)
# ------------------------------------------------- Utility Functions For the Script ----------------------------------------------------

function copyFileToCorruptFolder() {
  hlrFileName=$1
  date_time=$(date +%Y%m%d_%H%M%S)
  fileCorruptBackupPath=$fileCorruptBackupPath
  mv $hlrFileName $fileCorruptBackupPath/${hlrFileName}_${date_time}
  gzip $fileCorruptBackupPath/${hlrFileName}_${date_time}
  echo "Copied the dump to Corrupt Folder."
}

function generateAlert() {
  id=$1
  echo "Start alert"
  alertId=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbPassword} -se "select alert_id from cfg_feature_alert where alert_id='$id'")
  alertMessage=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbPassword} -se "select description from cfg_feature_alert where alert_id='$id'")
  echo "$(date +%F_%H-%M-%S) : alertMessage=$alertMessage , alertId=$alertId"
  mysql -h$dbIp -P$dbPort -u$dbUsername -p${dbPassword} $appdbName <<EOFMYSQL
    insert into sys_generated_alert (alert_id,description,STATUS,USER_ID,USERNAME) values('$alertId','$alertMessage',0,0,'NA');
EOFMYSQL
}

function updateAuditEntry() {
#  echo "Hello"
  msgTag=$1
  echo $msgTag
#  count=$2
#  failureCount=$3
  executionStartTime=$2
  echo $executionStartTime
  executionFinishTime=$(date +%s.%N);
  executionTime=$(echo "$executionFinishTime - $executionStartTime" | bc)
  secondDivision=1000
  finalExecutionTime=`echo "$executionTime * $secondDivision" | bc`
  echo $finalExecutionTime
  hlrFileProcessModuleLogPathNotFound=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbPassword} -se "select value from msg_cfg where tag='$msgTag'")
  echo $hlrFileProcessModulePathNotFound
  mysql -h$dbIp -P$dbPort -u$dbUsername -p${dbPassword} $auddbName <<EOFMYSQL
  update modules_audit_trail set status_code='501',status='FAIL',error_message='$hlrFileProcessModuleLogPathNotFound',feature_name='HLR Dump Script Process',info='NA',count='0',action='HLR Dump Script',server_name='$serverName',execution_time='$finalExecutionTime',module_name='HLR Dump File Processor' ,count2='0', failure_count='0',modified_on=CURRENT_TIMESTAMP where module_name='HLR Dump File Processor' and feature_name='HLR Dump Script Process' order by id desc limit 1;
EOFMYSQL
}

# ------------------------------------- End of the functions ------------------------------------------------------------

### 1. HLR Dump Processor Script Start
source ~/.bash_profile
var=''
int_value=0
echo "$(date +%F_%H-%M-%S): server name = $serverName"
commonConfiguration=$commonConfigurationFilePath
HLRScriptConfiguration=$HLRScriptConfiguration
source $commonConfiguration
source $HLRScriptConfiguration

if [ ! -e "$HLRScriptConfiguration" ] || [ ! -e "$commonConfiguration" ]
  then
    echo "$(date +%F_%H-%M-%S): file not found (once NMS tool finalisze we will explore raising alarm from this script) ,now script is terminated."
      exit 1;
fi



# Reading password from the config file.
echo "Retrieving password for database connection."
dbPassword=$(java -jar  /u01/eirapp/encryption-utility/PasswordDecryptor-0.1.jar spring.datasource.password)

if [ -z "$dbIp" ] || [ -z "$dbPort" ] || [ -z "$dbUsername" ] || [ -z "$dbPassword" ] ;
  then
    echo "$(date +%F_%H-%M-%S): DB details missing(once NMS tool finalisze we will explore raising alarm from this script) ,now script is terminated."
          exit 1;
fi

hlrTime=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbPassword} -se "select value from sys_param where tag='hlrTime'")
hlrDay=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbPassword} -se "select value from sys_param where tag='hlrDay'")

current_day=$(date +%u)
# Calculate the number of days to subtract to reach the previous target weekday
if [ "$(date +%A)" == "$hlrDay" ]; then
    # If today is the target weekday, do not subtract any days to get today's date
    previous_target_day=$(date +%F)
else
    # Calculate the number of days to subtract to reach the previous target weekday
    days_to_subtract=$((current_day - $(date -d "$hlrDay" +%u)))
    if [ $days_to_subtract -lt 0 ]; then
        days_to_subtract=$((days_to_subtract + 7))
    fi

    # Calculate the date of the previous target weekday
    previous_target_day=$(date -d "$days_to_subtract days ago" +%F)
fi

# Print the result
echo "Current day of the week: $(date +%A)"
echo "Previous $target_weekday's date: $previous_target_day"




status=$(-h$dbIp -P$dbPort -u$dbUsername -p${dbPassword} $auddbName  -se "select status_code from modules_audit_trail where module_name LIKE %HLR% and expected_date LIKE ('')");
if [ "$status" -eq 200 ]; then
  echo "File already processed for the week. Exiting the process."
fi

echo "Entry in modules audit trail to start the script."
hlrFileScriptInitialMsg=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername -p${dbPassword} -se "select value from msg_cfg where tag='hlrFileScriptInitialMsg'")
mysql -h$dbIp -P$dbPort -u$dbUsername -p${dbPassword} $auddbName <<EOFMYSQL
                insert into modules_audit_trail (status_code,status,error_message,feature_name,info,count,action,server_name,execution_time,module_name,count2,failure_count) values( 201,'$hlrFileScriptInitialMsg' ,'NA','HLR Dump Script Process' ,'HLR Dump File' , 0 ,'HLR Dump Script','$serverName',0,'HLR Dump File Processor',0,0);
EOFMYSQL

# --------------------------------Validation of the configuration present in properties file ----------------------------------------

#5. Validate the configuration.
if [ ! -e "$fileProcessModulePath" ] || [ ! -d "$fileProcessModulePath" ] ;
                then
      echo "$(date +%F_%H-%M-%S) : $fileProcessModulePath  not exists. Terminating the process."
      updateAuditEntry 'hlrFileProcessModulePathNotFound' $executionStartTime
      generateAlert 'alert1009'
      exit 3;
fi

if [ ! -e "$processLogPath" ] || [ ! -d "$processLogPath" ];
                then
      echo "$(date +%F_%H-%M-%S) : $processLogPath log path not exists. Terminating the process."
      updateAuditEntry 'hlrFileProcessModuleLogPathNotFound' $executionStartTime
      generateAlert 'alert1010'
exit 3;
fi

if [ ! -e "$fileScriptProcessPath" ] || [ ! -d "$fileScriptProcessPath" ];
                then
      echo "$(date +%F_%H-%M-%S) : $fileScriptProcessPath path not exists. Terminating the process."
      updateAuditEntry 'hlrFileScriptProcessPathNotFound' $executionStartTime
      generateAlert 'alert1014'
exit 3;
fi

if [ ! -e "$fileCorruptBackupPath" ] || [ ! -d "$fileCorruptBackupPath" ];
                then
      echo "$(date +%F_%H-%M-%S) : $fileCorruptBackupPath path not exists. Terminating the process."
      updateAuditEntry '$hlrFileCorruptPathNotFound' $executionStartTime
      generateAlert 'alert1013'
exit 3;
fi

if [ ! -e "$deltaFileBackupPath" ] || [ ! -d "$deltaFileBackupPath" ];
                then
      echo "$(date +%F_%H-%M-%S) : $deltaFileBackupPath path not exists. Terminating the process."
      updateAuditEntry 'hlrDeltaFileBackupPathNotFound' $executionStartTime
      generateAlert 'alert1015'
exit 3;
fi

if [ ! -e "$fileBackupPath" ] || [ ! -d "$fileBackupPath" ];
                then
      echo "$(date +%F_%H-%M-%S) : $fileBackupPath path not exists. Terminating the process."
      updateAuditEntry 'hlrCompleteFileBackupPathNotFound' $executionStartTime
      generateAlert 'alert1016'
exit 3;
fi

# ---------------------------------------validation ends----------------------------------------------------------------

#2 read configuration value of file  download url from MySQL database table system_configuration_db


echo $hlrTime
echo $hlrDay

##3. Check if the configs are fetched from db or not.
if [ -z "$hlrTime" ] || [ -z "$hlrDay" ] ;
                then
                        echo "$(date +%F_%H-%M-%S):The configuration values for date and time cannot be fetched."
                        generateAlert '1008'
      exit 3;
fi
echo "---$(date +%F)"

currentWeekday=$(date +"%A")
currentTime=$(date +"%H:%M:%S")
currentDate=$(date +"%Y%m%d")
extension=".csv";
hlrFileName="${hlrFileName}_${currentDate}${extension}";
## check if file exist then rename.
file=$(ls -1 "$hlrFilePath")
if [ -n "$file" ]; then
  timestamp=$(stat -c "%Y" "$hlrFilePath/$file")  # Get the modification timestamp
  timestamp_formatted=$(date -d "@$timestamp" +"%H:%M")
  echo "File found in $hlrFilePath: $file (Timestamp: $timestamp_formatted)"
  echo "Renaming the file."
  mv "$hlrFilePath/$file" "$hlrFilePath/$hlrFileName"
  echo "File renamed and continue the process."

elif [ "$hlrDay" = "$currentWeekday" ]; then
    echo "File not uploaded at decided time. Raising an alert and exiting from the system."
    executionFinishTime=$(date +%s.%N);
    ExecutionTime=$(echo "$executionFinishTime - $executionStartTime" | bc)
    secondDivision=1000
    finalExecutionTime=`echo "$ExecutionTime * $secondDivision" | bc`
    echo $finalExecutionTime
    ## write sql query
    hlrDumpFileNotAvailable=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbPassword} -se "select value from msg_cfg where tag='hlrDumpFileNotAvailable'")
    mysql -h$dbIp -P$dbPort -u$dbUsername -p${dbPassword} $auddbName <<EOFMYSQL
    update modules_audit_trail set status_code='501',status='FAIL',error_message='hlrDumpFileNotAvailable',feature_name='HLR Dump Script Process', info='NA',count='0',action='HLR Dump Script',server_name='$serverName',execution_time='$finalExecutionTime',module_name='HLR Dump File Processor' ,count2='0', failure_count='0',modified_on=CURRENT_TIMESTAMP where module_name='HLR Dump File Processor' and feature_name='HLR Dump Script Process' order by id desc limit 1;
EOFMYSQL
    alertId=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbPassword} -se "select alert_id from cfg_feature_alert where alert_id='alert1012'")
    alertMessage=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbPassword} -se "select description from cfg_feature_alert where alert_id='alert1012'")
    echo "$(date +%F_%H-%M-%S) : alertMessage=$alertMessage , alertId=$alertId"
    mysql -h$dbIp -P$dbPort -u$dbUsername -p${dbPassword} $appdbName <<EOFMYSQL
    insert into sys_generated_alert (alert_id,description,STATUS,USER_ID,USERNAME) values('$alertId','$alertMessage',0,0,'NA');
EOFMYSQL
    exit 2;
fi

### If HLR Dump Exist
## hlrFileName && hlrFilePath
#extension=".csv";
#hlrFileName="${hlrFileName}_${currentDate}${extension}";
hlrFilePath=$hlrFilePath

fullPath="$hlrFilePath/$hlrFileName"
###4. Check if the file is uploaded on the decided time and day or not.
#if [ ! -f "$fullPath" ]; then
#  if [ "$hlrTime" = "$currentTime" ] && [ "$hlrDay" = "$currentWeekday" ]; then
#    echo "File not uploaded at decided time. Raising an alert and exiting from the system."
#    executionFinishTime=$(date +%s.%N);
#    ExecutionTime=$(echo "$executionFinishTime - $executionStartTime" | bc)
#    secondDivision=1000
#    finalExecutionTime=`echo "$ExecutionTime * $secondDivision" | bc`
#    echo $finalExecutionTime
#    ## write sql query
#    hlrDumpFileNotAvailable=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbPassword} -se "select value from msg_cfg where tag='hlrDumpFileNotAvailable'")
#    mysql -h$dbIp -P$dbPort -u$dbUsername -p${dbPassword} $auddbName <<EOFMYSQL
#    update modules_audit_trail set status_code='501',status='FAIL',error_message='hlrDumpFileNotAvailable',feature_name='HLR Dump Script Process', info='NA',count='0',action='HLR Dump Script',server_name='$serverName',execution_time='$finalExecutionTime',module_name='HLR Dump File Processor' ,count2='0', failure_count='0',modified_on=CURRENT_TIMESTAMP where module_name='HLR Dump File Processor' and feature_name='HLR Dump Script Process' order by id desc limit 1;
#EOFMYSQL
#    alertId=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbPassword} -se "select alert_id from cfg_feature_alert where alert_id='alert1012'")
#    alertMessage=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbPassword} -se "select description from cfg_feature_alert where alert_id='alert1012'")
#    echo "$(date +%F_%H-%M-%S) : alertMessage=$alertMessage , alertId=$alertId"
#    mysql -h$dbIp -P$dbPort -u$dbUsername -p${dbPassword} $appdbName <<EOFMYSQL
#    insert into sys_generated_alert (alert_id,description,STATUS,USER_ID,USERNAME) values('$alertId','$alertMessage',0,0,'NA');
#EOFMYSQL
#    exit 2;
#  else
#    echo "HLR Dump file not found."
#    exit 2;
#  fi
#fi

## file exist then now do file validation

headers=$(head -n 1 "$fullPath" | tr -d '[:space:]')
imsi_header_name="IMSI";
msisdn_header_name="MSISDN";
imsi_column_number=$(echo "$headers" | awk -v target="$imsi_header_name" -F',' 'BEGIN {IGNORECASE=1} {
  for(i = 1; i<= NF; i++) {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i);
    if(tolower($i) == tolower(target)) {
      print i
      exit
    }
  }
}')

msisdn_column_number=$(echo "$headers" | awk -v target="$msisdn_header_name" -F',' 'BEGIN {IGNORECASE=1} {
  for(i = 1; i<= NF; i++) {
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i);
    if(tolower($i) == tolower(target)) {
      print i
      exit
    }
  }
}')

echo "IMSI column number in new dump $imsi_column_number"
echo "MSISDN column number in new dump $msisdn_column_number"
if [ -z "$imsi_column_number" ] ;
  then
    echo "IMSI does not exist."
    updateAuditEntry 'hlrCorruptedFile' $executionStartTime
    copyFileToCorruptFolder $hlrFileName
    generateAlert 'alert1006'
    exit 1;
  else
    echo "IMSI exists."
fi

if [ -z "$msisdn_column_number" ] ;
  then
    echo "MSISDN does not exist."
    updateAuditEntry 'hlrCorruptedFile' $executionStartTime
    copyFileToCorruptFolder $hlrFileName
    generateAlert 'alert1006'
    exit 1;
  else
    echo "MSISDN exists."
fi

processedFile="$fileScriptProcessPath/HLRDumpProcessed.csv"
total_number_of_imsi=$(cat "$fullPath" | wc -l);
echo " Total Number of records in new dump is $total_number_of_imsi"

if [ -f "$processedFile" ] ;
  then
    total_number_of_previous_file_records=$(cat "$processedFile" | wc -l)
    echo "Total number of records from previous processedFile. "$total_number_of_previous_file_records". "
    if [ "$total_number_of_previous_file_records" -gt 0 ] ;
      then
        difference_of_records=$((total_number_of_previous_file_records-total_number_of_imsi));
        #echo "difference_of_records $difference_of_records"
        difference_of_records=$(expr $difference_of_records : '-\?\([0-9]*\)')
        #echo "difference_of_records $difference_of_records"
        #percentage_difference=$((difference_of_records/total_number_of_previous_file_records))
        percentage_difference=$(echo "scale=2; ($difference_of_records) / $total_number_of_previous_file_records" | bc)
        #echo "$percentage_difference"
        result2="$errorRecordPercent"
        echo "Percentage difference is: "
        echo $(echo "$percentage_difference >= $result2" | bc -l)

        if (( $(echo "$percentage_difference >= $result2" | bc -l) )); then
          echo "percentage_difference is greater than "$result2"."
          updateAuditEntry 'hlrCorruptedFile' $executionStartTime
          copyFileToCorruptFolder $hlrFileName
          generateAlert 'alert1006'
          exit 2
        fi
    fi
fi

# checking unique count of imsi
start_time=$(date +%s%3N)
number_of_unique_imsi=$(cut -d ',' -f"$imsi_column_number" "$fullPath" | sort | uniq | wc -l);
echo "Number of unique imsi is $number_of_unique_imsi";
end_time=$(date +%s%3N)  # Get end time in milliseconds
execution_time=$((end_time - start_time))
echo "Unique imsi checking execution time: $execution_time ms"
if [ "$number_of_unique_imsi" != "$total_number_of_imsi" ] ;
  then
    echo "IMSI is duplicate in the dump";
    #raise alert
    updateAuditEntry 'hlrCorruptedFile' $executionStartTime
    copyFileToCorruptFolder $hlrFileName
    generateAlert 'alert1006'
    exit 2
fi

# checking unique count of msisdn
start_time=$(date +%s%3N)
number_of_unique_msisdn=$(cut -d ',' -f"$msisdn_column_number" "$fullPath" | sort | uniq | wc -l);
echo "Number of unique msisdn is $number_of_unique_msisdn";
end_time=$(date +%s%3N)  # Get end time in milliseconds
execution_time=$((end_time - start_time))
echo "Unique msisdn checking execution time: $execution_time ms"
if [ "$number_of_unique_msisdn" != "$total_number_of_imsi" ] ;
  then
    echo "MSISDN is duplicate in the dump";
    updateAuditEntry 'hlrCorruptedFile' $executionStartTime
    copyFileToCorruptFolder $hlrFileName
    generateAlert 'alert1006'
    exit 2
fi

# creating a temp file with imsi and msisdn only for processing.
tempFile="$fileScriptProcessPath/tempFile.csv"
start_time=$(date +%s%3N)
t=$(awk -F',' -v var1="$imsi_column_number" -v var2="$msisdn_column_number" 'NF>0 {gsub(/^[ \t]+|[ \t]+$/, "", $var1); gsub(/^[ \t]+|[ \t]+$/, "", $var2); print $var1","$var2}' "$fullPath" > "$tempFile")
echo $t
end_time=$(date +%s%3N)  # Get end time in milliseconds
execution_time=$((end_time - start_time))
echo "Creating a temp file execution time: $execution_time ms"

output_file_deletion="$fileProcessModulePath/HLRDumpDeltaDeletion.csv"
output_file_addition="$fileProcessModulePath/HLRDumpDeltaAddition.csv"
touch "$output_file_deletion" "$output_file_addition"
#headers=$(head -n 1 "$tempFile")

# If processed file is empty just copy the content to delta files.
if [ -s "$processedFile" ];
        then
#taking diff
         start_time=$(date +%s%3N)
         #diff_output=$(diff "$processedFile" "$tempFile" | grep '>' | cut -c 3-)
         diff_output_deletion=$(diff -B --changed-group-format='%<' --unchanged-group-format='' "$processedFile" "$tempFile")
         diff_output_addition=$(diff -B --changed-group-format='%>' --unchanged-group-format='' "$processedFile" "$tempFile")
         #echo "$headers" > "$output_file"
         echo "$diff_output_deletion" > "$output_file_deletion"
         echo "$diff_output_addition" >  "$output_file_addition"
         end_time=$(date +%s%3N)  # Get end time in milliseconds
         execution_time=$((end_time - start_time))
         echo "Diff file creation execution time: $execution_time ms"

         else
           echo "Processed File is empty copying the temp file to delta files."
           cp "$tempFile" "$output_file_addition"

fi

#check if diff file is empty or contains entries.
#if [ -s "$output_file_deletion" ] || [ -s "output_file_addition" ];
 # then
  #  echo "$(date +%F_%H-%M-%S) : HLR Delta Files is not empty process will continue."
 # else
#    echo "$(date +%F_%H-%M-%S) : HLR Delta Files is empty going to stop this process here."
          # success entry updateAuditEntry
 #   exit 1
#fi

#6. Start the java process to create and process the diff file.
start_time=$(date +%s%3N)
cd $fileProcessModulePath
java -jar HLRDumpProcessor-0.0.1-SNAPSHOT.jar --spring.config.location=./configuration.properties  1> $processLogPath/HLRFileProcessLog_$(date +%Y%m%d%H%M%S).log 2>&1
jarStatusCode=$?
end_time=$(date +%s%3N)
execution_time=$((end_time-start_time))
echo "Jar took time for execution: $execution_time ms"
#echo $jarStatusCode


cd $fileScriptProcessPath
fileProcessUtiltyStatusCode=$(mysql -h$dbIp -P$dbPort $auddbName -u$dbUsername -p${dbPassword} -se "select status_code from modules_audit_trail where created_on LIKE '%$(date +%F)%' and feature_name IN ('HLR Dump File Process')  order by created_on desc limit 1");
echo "$(date +%F_%H-%M-%S) : fileProcessUtiltyStatusCode  = $fileProcessUtiltyStatusCode";


#7. Check if the file process completed successfully or not.
if [ "$jarStatusCode" -eq 0 ] && [ "$fileProcessUtiltyStatusCode" -eq 200 ] ;
                then
                        date_time=$(date +%y%m%d_%H%M%S)
                        cp      ${tempFile} HLRDumpProcessed.csv
                        echo "$(date +%F_%H-%M-%S) :Copied file ${tempFile} to HLRDumpProcessed.csv "

                        mv $fullPath $fileBackupPath/${hlrFileName}_${date_time}
                        echo "Moved $fullPath to complete file backup folder path."
                        gzip $fileBackupPath/${hlrFileName}_${date_time}
                        echo "Gzipped the $hlrFileName in complete backup folder path."

                        mv $fileProcessModulePath/HLRDumpDeltaAddition.csv $deltaFileBackupPath/HLRDumpDeltaAddition_${date_time}.csv
                        echo "Moved HLRDumpDeltaAddition to delta file backup folder path."
                        gzip $deltaFileBackupPath/HLRDumpDeltaAddition_${date_time}.csv
                        echo "Gzipped the HLRDumpDeltaAddition in delta backup folder path."

                        mv $fileProcessModulePath/HLRDumpDeltaDeletion.csv $deltaFileBackupPath/HLRDumpDeltaDeletion_${date_time}.csv
                        echo "Moved HLRDumpDeltaDeletion to delta backup folder path."
                        gzip $deltaFileBackupPath/HLRDumpDeltaDeletion_${date_time}.csv
                        echo "Gzipped the HLRDumpDeltaDeletion file in delta backup folder path."

                        echo "$(date +%F_%H-%M-%S) : Moved ${hlrFileName} to ${fileBackupPath} folder and moved file HLRDumpDeltaAddition.csv, HLRDumpDeltaDeletion.csv to ${deltaFileBackupPath} folder.";
                        cd $fileScriptProcessPath

   else
      echo "$(date +%F_%H-%M-%S) : 200 status  not found , File process utility not complete successfully. "
      alertId=$(mysql -h$dbIp -P$dbPort  $appdbName -u$dbUsername  -p${dbPassword} -se "select alert_id from cfg_feature_alert where alert_id='alert1011'")
      alertMessage=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbPassword} -se "select description from cfg_feature_alert where alert_id='alert1011'")
      echo "$(date +%F_%H-%M-%S) : alertMessage=$alertMessage , alertId=$alertMessage"
      executionFinishTime=$(date +%s.%N);
      ExecutionTime=$(echo "$executionFinishTime - $executionStartTime" | bc)
      secondDivision=1000
      finalExecutionTime=`echo "$ExecutionTime * $secondDivision" | bc`
      hlrFileProcessNotComplete=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbPassword} -se "select value from msg_cfg where tag='hlrFileProcessNotComplete'")
      mysql -h$dbIp -P$dbPort -u$dbUsername -p${dbPassword} $auddbName <<EOFMYSQL

      update modules_audit_trail set status_code='501',status='FAIL',error_message='$hlrFileProcessNotComplete',feature_name='HLR Dump Script Process',info='NA',count='0',action='HLR Dump Script',server_name='$serverName',execution_time='$finalExecutionTime',module_name='HLR Dump File Processor' ,count2='0', failure_count='0' ,modified_on=CURRENT_TIMESTAMP where module_name='HLR Dump File Processor' and feature_name='HLR Dump Script Process' order by id desc limit 1;
EOFMYSQL
      mysql -h$dbIp -P$dbPort -u$dbUsername -p${dbPassword} $appdbName <<EOFMYSQL
                  insert into sys_generated_alert (alert_id,description,STATUS,USER_ID,USERNAME) values('$alertId','$alertMessage',0,0,'NA');
EOFMYSQL
    exit 1
fi

#8. Success entry in audit table.
executionFinishTime=$(date +%s.%N);
ExecutionTime=$(echo "$executionFinishTime - $executionStartTime" | bc)
secondDivision=1000
finalExecutionTime=`echo "$ExecutionTime * $secondDivision" | bc`
echo $finalExecutionTime
updatedCount=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbPassword} -se "select count(*) from device_sync_request where  request_date LIKE '%$(date +%F)%' and operation='DEL' and identity='HLR_DATA'");
insertCount=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbPassword} -se "select count(*) from device_sync_request where request_date LIKE '%$(date +%F)%' and operation='ADD' and identity='HLR_DATA'");
totalCount=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbPassword} -se "select count(*) from device_sync_request where identity='HLR_DATA'");
failure_count=$(mysql -h$dbIp -P$dbPort $auddbName -u$dbUsername  -p${dbPassword} -se "select failure_count from modules_audit_trail where module_name='HLR Dump File Processor' and feature_name='HLR Dump File Process' order by id desc limit 1");
echo "$(date +%F_%H-%M-%S) : total number of record failed=$failure_count"
echo "$(date +%F_%H-%M-%S) : total number of record deleted=$updatedCount"
echo "$(date +%F_%H-%M-%S) : total number of record inserted=$insertCount"
echo "$(date +%F_%H-%M-%S) : total number of record =$totalCount"
hlrFileScriptSuccessMsg=$(mysql -h$dbIp -P$dbPort $appdbName -u$dbUsername  -p${dbPassword} -se "select value from msg_cfg where tag='hlrFileScriptSuccessMsg'")
mysql -h$dbIp -P$dbPort -u$dbUsername -p${dbPassword} $auddbName <<EOFMYSQL
update  modules_audit_trail set status_code='200',status='$hlrFileScriptSuccessMsg',error_message='NA',feature_name='HLR Dump Script Process',info='',count='$totalCount',action='HLR Dump Script',server_name='$serverName',execution_time='$finalExecutionTime',module_name='HLR Dump File Processor' ,count2='0', failure_count='$failure_count' ,modified_on=CURRENT_TIMESTAMP where module_name='HLR Dump File Processor' and feature_name='HLR Dump Script Process' order by id desc limit 1;
update modules_audit_trail set info='${hlrFileName}' where module_name='HLR Dump File Processor' and feature_name='HLR Dump Script Process' order by id desc limit 1;
EOFMYSQL
echo "$(date +%F_%H-%M-%S) : HLR Dump File Processor completed successfully."
exit 0;
