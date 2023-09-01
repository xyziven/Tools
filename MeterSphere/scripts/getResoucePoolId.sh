#!/bin/bash

usage()
{
 echo Usage: sh $0 accessKey secretKy HOST_URL resourcePoolName
 exit 1
}

if [ $# -ne 4 ]; then
  usage
else
  accessKey=${1}
  secretKey=${2}
  HOST=${3}
  resourcePoolName=${4}
fi

resourcePoolId="resourcePoolId"

keySpec=$(echo -n "${secretKey}" | od -A n -t x1 | tr -d ' ')
iv=$(echo -n "${accessKey}" | od -A n -t x1 | tr -d ' ')

currentTimeMillis=$(date +%s000)
seed=${accessKey}\|$currentTimeMillis
signature=$(printf %s "${seed}" | openssl enc -e -aes-128-cbc -base64 -K ${keySpec} -iv ${iv})

# get resource Pool Id through resource pool name

getResourcePoolId()
{
  BODY='{"name":"'$resourcePoolName'"}'
  # CMD="curl -k -s -H \"accesskey: ${accessKey}\" -H \"signature: ${signature}\" -H \"Content-Type: application/json\" -X POST https://${HOST}/setting/testresourcepool/list/1/10 -d \'${BODY}\'"
  # echo ${CMD}
  RESULT=$(curl -k -s -H "accesskey: ${accessKey}" -H "signature: ${signature}" -H "Content-Type: application/json" -X POST https://${HOST}/setting/testresourcepool/list/1/10 -d ${BODY})
#  echo "${RESULT}"
  resourcePoolId=$(printf '%s\n' "${RESULT}" | jq '.data.listObject[] |  select(.name == "'"${resourcePoolName}"'")' |jq .id)
}

getUserId()
{
    RESULT=$(curl -k -s -H "accesskey: ${accessKey}" -H "signature: ${signature}" -H "Content-Type: application/json" https://${HOST}/user/list)
    userId=$(printf '%s\n' "${RESULT}" | jq '.data.id')
    echo "current user Id is: $userId"
}


getResourcePoolId
echo "resourcePool_ID: ${resourcePoolId}"


