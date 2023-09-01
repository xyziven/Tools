#!/bin/bash

usage()
{
 echo Usage: sh $0 accessKey secretKy projectName envName HOST_URL
 exit 1
}

if [ $# -ne 5 ]; then
  usage
else
  accessKey=${1}
  secretKey=${2}
  projectName=${3}
  envName=${4}
  HOST=${5}
fi

keySpec=$(echo -n "${secretKey}" | od -A n -t x1 | tr -d ' ')
iv=$(echo -n "${accessKey}" | od -A n -t x1 | tr -d ' ')

currentTimeMillis=$(date +%s000)
seed=${accessKey}\|$currentTimeMillis
signature=$(printf %s "${seed}" | openssl enc -e -aes-128-cbc -base64 -K ${keySpec} -iv ${iv})


getProjectId()
{
    RESULT=$(curl -k -s -H "accesskey: ${accessKey}" -H "signature: ${signature}" -H "Content-Type: application/json" https://${HOST}/project/project/list/all)
    projectId=$(printf '%s\n' "${RESULT}" | jq '.data[] | select(.name == "'"${projectName}"'")' |jq .id)
}


getEnvId()
{
    proj_id=$1
    BODY='{"projectIds":['$proj_id']}'
    RESULT=$(curl -k -s -H "accesskey: ${accessKey}" -H "signature: ${signature}" -H "Content-Type: application/json" https://${HOST}/project/environment/list/1/10 -d "${BODY}")
#    echo ${RESULT}
    envId=$(printf '%s\n' "${RESULT}" | jq '.data.listObject[] | select(.name == "'"${envName}"'")' |jq .id)
}

getProjectId
echo "PROJECT_ID: $projectId"


getEnvId $projectId
echo "Env_ID: ${envId}"


