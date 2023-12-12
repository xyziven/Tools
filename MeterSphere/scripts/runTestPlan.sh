#!/bin/bash
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
  HOST=${6}
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
    RESULT=$(curl -k -s -H "accesskey: ${accessKey}" -H "signature: ${signature}" -H "Content-Type: application/json" https://${HOST}/project/project/list/all)
    projectId=$(printf '%s\n' "${RESULT}" | jq '.data[] | select(.name == "'"${projectName}"'")' |jq .id)
}

getEnvId()
{
        proj_id=$1
        BODY='{"projectIds":['$proj_id']}'   
        RESULT=$(curl -k -s -X POST -H "accesskey: ${accessKey}" -H "signature: ${signature}" -H "Content-Type: application/json" https://${HOST}/project/environment/list/1/10 -d "${BODY}")
#        echo ${RESULT}
        envId=$(printf '%s\n' "${RESULT}" | jq '.data.listObject[] | select(.name == "'"${envName}"'")' |jq .id)
}

# get Test Plan ID through plan name
getTestPlanId()
{
    proj_id=$1
    plan_name=$2
    BODY='{"projectId": '$proj_id'}'
    RESULT=$(curl -k -s -X POST -H "accesskey: ${accessKey}" -H "signature: ${signature}" -H "Content-Type: application/json" https://${HOST}/track/test/plan/list/1/1000 -d "${BODY}")
    testPlanId=$(printf '%s\n' "${RESULT}" | jq '.data.listObject[] | select(.name == "'"${plan_name}"'")' |jq .id)
}

# get resource Pool Id through resource Pool Name
getResourcePoolId()
{
  BODY='{"name":"'$resourcePoolName'"}'
  # CMD="curl -k -s -H \"accesskey: ${accessKey}\" -H \"signature: ${signature}\" -H \"Content-Type: application/json\" -X POST https://${HOST}/setting/testresourcepool/list/1/10 -d \'${BODY}\'"
  # echo ${CMD}
  RESULT=$(curl -k -s -H "accesskey: ${accessKey}" -H "signature: ${signature}" -H "Content-Type: application/json" -X POST https://${HOST}/setting/testresourcepool/list/1/10 -d ${BODY})
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

   BODY='{ "mode": "serial", "reportType":"iddReport", "onSampleError":false, "requestOriginator":"TEST_PLAN", "executionWay":"RUN", "testPlanId":'${plan_id}',"projectId":'${proj_id}',"triggerMode": "API","userId":"'${user_id}'","runWithinResourcePool": true, "resourcePoolId":'${rspool_id}', "environmentType":"JSON","environmentGroupId":"","envMap":{}}'

    RESULT=$(curl -k -s -X POST -H "accessKey: ${accessKey}" -H "signature: ${signature}" -H "Content-Type: application/json" https://${HOST}/track/test/plan/run -d "${BODY}")
    sleep 1
    execResult=$(echo $RESULT | jq -r '.success')
    if [[ $execResult == true ]];then
      echo "success: true"
      echo "The test plan is triggerred successfull"
      testReportId=$(echo $RESULT | jq -r '.data')
    else
      echo "Failed to call API to run the test plan"
      echo "RESULT: $RESULT"
      echo "PLEASE check the CMD:"
      echo "... curl -k -s -X POST -H \"accessKey: ${accessKey}\" -H \"signature: ${signature}\" -H \"Content-Type: application/json\" https://${HOST}/track/test/plan/run -d \'${BODY}\' "
    fi
}

getReportSharedId()
{
    report_id=$1
    BODY='{"customData":"'${report_id}'","shareType":"PLAN_DB_REPORT","lang":null}'

    RESULT=$(curl -k -s -X POST -H "accessKey: ${accessKey}" -H "signature: ${signature}" -H 'Content-Type: application/json' https://${HOST}/track/share/generate/expired -d "${BODY}")
    reportSharedId=$(echo $RESULT | jq -r '.data.shareUrl')
}

getProjectId
echo "project_ID: ${projectId}"

getEnvId $projectId
echo "env_ID: ${envId}"

getTestPlanId $projectId ${testPlanName}
echo "testPlan_ID: ${testPlanId}"

getResourcePoolId ${resourcePoolName}
echo "resourcePool_ID: $resourcePoolId"

runTestPlan $projectId $testPlanId $envId $resourcePoolId $userId
getReportSharedId $testReportId

#echo ${reportSharedId}

REPORTURL="https//${HOST}/track/share-plan-report${reportSharedId}"
echo "Please visit URL: ${REPORTURL} for test report" 

