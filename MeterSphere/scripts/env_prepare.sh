#!/bin/bash
 echo "Installing jq...." 
 apk add --no-cache curl jq openssl
 rm -rf /var/cache/apk/*

 #wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
 #chmod +x ./jq
 #cp jq /usr/bin
 #echo 1 | jq '(.+2)*5'
