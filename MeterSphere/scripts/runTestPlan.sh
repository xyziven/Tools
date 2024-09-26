#!/bin/bash
######################################################
#### This script is to trigger MeterSphere Test Plan #
####                                                 #
#### Author xyziven                                  #
#### 2024.8.30                                       #
####                                                 #
#### modified on Aug. 29, 2024                       #
#### replace HOST with HOST URL                      #
####                                                 #
#### modified on Sep. 26, 2024                       #
#### check report status & retrieve report data      #
####                                                 #
#### Copyright @2024                                 # 
######################################################

usage()
{
 echo Usage: sh $0 accessKey secretKy projectName envName testPlanName HOST_URL resourcePoolName userId
 exit 1
}

if [ $# -ne 8 ]; then
  usage
else
  accessKey=${1}
  secretKey=${2}
  projectName=${3}
  envName=${4}
  testPlanName=${5}
  HOST_URL=${6}
  resourcePoolName=${7}
  userId=${8}
fi

projectId="projectId"
envId="environmentId"
testPlanId="testPlanId"
reportURL="reportURL"
testReportId="retrieveReportId"
resourcePoolId="resourcePoolId"

keySpec=$(echo -n "${secretKey}" | od -A n -t x1 | tr -d ' ')
iv=$(echo -n "${accessKey}" | od -A n -t x1 | tr -d ' ')

currentTimeMillis=$(date +%s000)
seed=${accessKey}\|$currentTimeMillis
signature=$(printf %s "${seed}" | openssl enc -e -aes-128-cbc -base64 -K ${keySpec} -iv ${iv})

# get Project ID through project name
getProjectId()
{
    RESULT=$(curl -k -s -H "accesskey: ${accessKey}" -H "signature: ${signature}" -H "Content-Type: application/json" ${HOST_URL}/project/project/list/all)
    projectId=$(printf '%s\n' "${RESULT}" | jq '.data[] | select(.name == "'"${projectName}"'")' |jq .id)
}

getEnvId()
{
        proj_id=$1
        BODY='{"projectIds":['$proj_id']}'   
        RESULT=$(curl -k -s -X POST -H "accesskey: ${accessKey}" -H "signature: ${signature}" -H "Content-Type: application/json" ${HOST_URL}/project/environment/list/1/10 -d "${BODY}")
#        echo ${RESULT}
        envId=$(printf '%s\n' "${RESULT}" | jq '.data.listObject[] | select(.name == "'"${envName}"'")' |jq .id)


}

# get Test Plan ID through plan name
getTestPlanId()
{
    proj_id=$1
    plan_name=$2
    BODY='{"projectId": '$proj_id'}'
    RESULT=$(curl -k -s -X POST -H "accesskey: ${accessKey}" -H "signature: ${signature}" -H "Content-Type: application/json" ${HOST_URL}/track/test/plan/list/1/1000 -d "${BODY}")
    testPlanId=$(printf '%s\n' "${RESULT}" | jq '.data.listObject[] | select(.name == "'"${plan_name}"'")' |jq .id)
}

# get resource Pool Id through resource Pool Name
getResourcePoolId()
{
  BODY='{"name":"'$resourcePoolName'"}'
  # CMD="curl -k -s -H \"accesskey: ${accessKey}\" -H \"signature: ${signature}\" -H \"Content-Type: application/json\" -X POST ${HOST_URL}/setting/testresourcepool/list/1/10 -d \'${BODY}\'"
  # echo ${CMD}
  RESULT=$(curl -k -s -H "accesskey: ${accessKey}" -H "signature: ${signature}" -H "Content-Type: application/json" -X POST ${HOST_URL}/setting/testresourcepool/list/1/10 -d ${BODY})
  # echo "${RESULT}"
  resourcePoolId=$(printf '%s\n' "${RESULT}" | jq '.data.listObject[] |  select(.name == "'"${resourcePoolName}"'")' |jq .id)
}



#Execute the Test Plan which associated the api test scenarios
runTestPlan()
{
    proj_id=$1
    plan_id=$2
    env_id=$3
    rspool_id=$4
    user_id=$5

   BODY='{ "mode": "serial", "reportType":"iddReport", "onSampleError":false, "requestOriginator":"TEST_PLAN", "executionWay":"RUN", "testPlanId":'${plan_id}',"projectId":'${proj_id}',"triggerMode": "API","userId":"'${user_id}'","runWithinResourcePool": true, "resourcePoolId":'${rspool_id}', "environmentType":"JSON","environmentGroupId":"","envMap":{'${proj_id}':'${env_id}'}}'

#    echo "CMD is: curl -k -s -X POST -H \"accessKey: ${accessKey}\" -H \"signature: ${signature}\" -H \"Content-Type: application/json\" ${HOST_URL}/track/test/plan/run -d \'${BODY}\' "
    RESULT=$(curl -k -s -X POST -H "accessKey: ${accessKey}" -H "signature: ${signature}" -H "Content-Type: application/json" ${HOST_URL}/track/test/plan/run -d "${BODY}")
    #echo "Result: $RESULT "
    execResult=$(echo $RESULT | jq -r '.success')
    if [[ $execResult == true ]];then
      echo "Triggerred success: true"
      echo "The test plan is triggerred successfully"
      testReportId=$(echo $RESULT | jq -r '.data')
      echo "Test Report ID for this running: $testReportId"
    else
      echo "Failed to call API to run the test plan"
      echo "RESULT: $RESULT"
      echo "PLEASE check the CMD:"
      echo "... curl -k -s -X POST -H \"accessKey: ${accessKey}\" -H \"signature: ${signature}\" -H \"Content-Type: application/json\" ${HOST_URL}/track/test/plan/run -d \'${BODY}\' "
    fi
}

getReportSharedId()
{
    report_id=$1
    BODY='{"customData":"'${report_id}'","shareType":"PLAN_DB_REPORT","lang":null}'

    getReportShareIDCMD="curl -k -s -H \"accesskey: ${accessKey}\" -H \"signature: ${signature}\" -H \"Content-Type: application/json\" -X POST ${HOST_URL}/track/share/generate/expired -d \'${BODY}\'"
    #echo "getReportShareIDCMD is: ${getReportShareIDCMD}"
    RESULT=$(curl -k -s -X POST -H "accessKey: ${accessKey}" -H "signature: ${signature}" -H 'Content-Type: application/json' ${HOST_URL}/track/share/generate/expired -d "${BODY}")
    reportSharedId=$(echo $RESULT | jq -r '.data.shareUrl')
}

chkReportStatus()
{
    report_id=$1
    chkStatusCMD="curl -k -s -X GET -H \"accesskey: ${accessKey}\" -H \"signature: ${signature}\" -H \"Content-Type: application/json\" ${HOST_URL}/track/test/plan/report/status/${report_id} "
    #echo "check status CMD is: ${chkStatusCMD}"
    RESULT=$(curl -k -s -X GET -H "accesskey: ${accessKey}" -H "signature: ${signature}" -H "Content-Type: application/json" ${HOST_URL}/track/test/plan/report/status/${report_id})
    #echo "Status Result: ${RESULT}"
    STATUS=$(echo $RESULT |jq -r ".data")

    while [ "$STATUS"x == "RUNNING"x ]
    do
      echo "STATUS: $STATUS"
      echo "The TestPlan ${testPlanName} is still RUNNING, waiting for 5 seconds. "
      sleep 5
      STATUS=$(curl -k -s -X GET -H "accesskey: ${accessKey}" -H "signature: ${signature}" -H "Content-Type: application/json" ${HOST_URL}/track/test/plan/report/status/${report_id} | jq -r ".data")
    done    
    echo "The running of testPlan ${testPlanName} completed with $STATUS."

  #  STATE=$(echo $RESULT |jq -r ".data")
}

getReportData()
{
   report_id=$1
   getReportDataCMD="curl -k -s -X GET -H \"accesskey: ${accessKey}\" -H \"signature: ${signature}\" -H \"Content-Type: application/json\" ${HOST_URL}/track/test/plan/report/db/${report_id}"
  # echo "get Report Data CMD is: ${getReportDataCMD}"
  # sleep 2
   REPORT=$(curl -k -s -X GET -H "accesskey: ${accessKey}" -H "signature: ${signature}" -H "Content-Type: application/json" ${HOST_URL}/track/test/plan/report/db/${report_id})
  # echo "Report Data: ${REPORT}"
   totalCase=$(echo $REPORT |jq -r ".data.caseCount")   ### Get Total Case Number
   passCount=$(echo $REPORT |jq -r ".data.passCount")   ### Get Passed Case Number
   execRate=$(echo $REPORT |jq -r ".data.executeRate")  ### Get execution Rate
   passRate=$(echo $REPORT |jq -r ".data.passRate")     ### Get Pass Rate
   percent_execRate=`awk 'BEGIN{printf "%d%%\n",('$execRate')*100}'`
   percent_passRate=`awk 'BEGIN{printf "%d%%\n",('$passRate')*100}'`
 
   caseLen=$(echo $REPORT | jq ".data.apiResult.apiCaseData |length")  ## check whether or not there's api case result
   sceLen=$(echo $REPORT | jq ".data.apiResult.apiScenarioData |length")  ## check whether or not there's api scenario result
   sceStepDataLen=$(echo $REPORT | jq ".data.apiResult.apiScenarioStepData |length")  ## check whether or not there's api scenario result

   #echo "caseLen is: $caseLen"
   #echo "sceLen is: $sceLen"

   ### Get API Case execution numbers
   if [[ $caseLen -gt 0 ]];then
     for ((i=0;i<$caseLen;i++))
     do
       sts=$(echo $REPORT |jq -r ".data.apiResult.apiCaseData[$i].status")
       num=$(echo $REPORT |jq -r ".data.apiResult.apiCaseData[$i].count")
    #   echo "sts = $sts"
    #   echo "num: $num"
       if [ $sts = "ERROR"  ];then
          apiCaseFailed=$num
       fi
       if [ $sts = "SUCCESS"  ];then
          apiCaseSuccess=$num
       fi
     done 
   fi
   
   ### Get API Scenario execution numbers
   if [[ $sceLen -gt 0 ]];then
     apiScenarioSteps=$(echo $REPORT |jq -r ".data.apiResult.apiScenarioStepData[0].count")
     for ((i=0;i<$sceLen;i++))
     do
       sts=$(echo $REPORT |jq -r ".data.apiResult.apiScenarioData[$i].status")
       num=$(echo $REPORT |jq -r ".data.apiResult.apiScenarioData[$i].count")
       if [ $sts = "ERROR"  ];then
          apiScenarioFailed=$(echo $REPORT |jq -r ".data.apiResult.apiScenarioData[$i].count")
       fi
       if [ $sts = "SUCCESS"  ];then
          apiScenarioSuccess=$(echo $REPORT |jq -r ".data.apiResult.apiScenarioData[$i].count")
       fi
     done 
   fi

  ### Get API Scenario Steps numbers
   if [[ $sceStepDataLen -gt 0 ]];then
     apiScenarioSteps=$(echo $REPORT |jq -r ".data.apiResult.apiScenarioStepData[0].count")
     for ((i=0;i<$sceLen;i++))
     do
       sts=$(echo $REPORT |jq -r ".data.apiResult.apiScenarioStepData[$i].status")
       num=$(echo $REPORT |jq -r ".data.apiResult.apiScenarioStepData[$i].count")
       if [ $sts = "ERROR"  ];then
          apiScenarioFailedSteps=$(echo $REPORT |jq -r ".data.apiResult.apiScenarioStepData[$i].count")
       fi
       if [ $sts = "SUCCESS"  ];then
          apiScenarioSuccessSteps=$(echo $REPORT |jq -r ".data.apiResult.apiScenarioStepData[$i].count")
       fi
     done
   fi
  
  echo "    "
  echo "#################################################################"
  echo "Tocal Case Number (测试总数): $totalCase "
  echo "Passed Case Number (通过用例数): $passCount "
  echo "Execution Rate (执行完成率): $percent_execRate "
  echo "Pass Rate (通过率): $percent_passRate "
  echo "Number of Failed API Case (失败CASE数): ${apiCaseFailed:-0} "
  echo "Number of Success API Case (成功CASE数): ${apiCaseSuccess:-0} "
  echo "Number of Failed API Scenario (失败场景数): ${apiScenarioFailed:-0} "
  echo "Number of Success API Scenario (成功场景数): ${apiScenarioSuccess:-0} "
  echo "Success Steps of API Scenario (成功的场景请求数): ${apiScenarioSuccessSteps:-0} "
  echo "Failed Steps of API Scenario (失败的场景请求数): ${apiScenarioFailedSteps:-0} "
  echo "#################################################################"
  echo "    "
}

getProjectId
echo "PROJECT_ID: ${projectId}"

getEnvId $projectId
echo "Env_ID: ${envId}"

getTestPlanId $projectId ${testPlanName}
echo "TestPlanId: ${testPlanId}"

getResourcePoolId ${resourcePoolName}
echo "resource pool Id: $resourcePoolId"

runTestPlan $projectId $testPlanId $envId $resourcePoolId $userId
#getReportSharedId $testReportId

chkReportStatus $testReportId

#Retrieve Report Data and print
echo "Retrieve Report Data for testPlan ${testPlanName} with its testReportId: $testReportId"
getReportData $testReportId

getReportSharedId $testReportId
 #echo ${reportSharedId}
REPORTURL="${HOST_URL}/track/share-plan-report${reportSharedId}"
echo "        "
echo "#########################################################"
echo "Please visit URL: ${REPORTURL} for test report"
echo "#########################################################"
echo "        "
