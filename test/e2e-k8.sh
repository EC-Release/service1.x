#!/bin/bash
#
#  Copyright (c) 2020 General Electric Company. All rights reserved.
#
#  The copyright to the computer software herein is the property of
#  General Electric Company. The software may be used and/or copied only
#  with the written permission of General Electric Company or in accordance
#  with the terms and conditions stipulated in the agreement/contract
#  under which the software has been supplied.
#
#  author: apolo.yasuda@ge.com
#
# developer note:
# this test is to demonstrate the resiliency of the upgraded EC service v1.1, sac, and its-
# service-2-sac integration, with the goals [1]avoiding potential human error/silos during a manual-
# tests, [2]migrating current EC service instances deployed in cloud foundry to a targeted K8 inst-
# [3]providing data to enable benchmark/performance analysis.
#

source <(wget -q -O - https://raw.githubusercontent.com/EC-Release/sdk/disty/scripts/libs/db.sh)

#build info
crdj=$(getCredJson "cred.json" "$EC_GITHUB_TOKEN")
EC_CID=$(echo $crdj | jq -r ".svc1_1Test.devId")
EC_CSC=$(echo $crdj | jq -r ".svc1_1Test.ownerHash")
AGT_HS=$(echo $crdj | jq -r ".svc1_1Test.pps4agt1")
PRNT_KEY=$(echo $crdj | jq -r ".svc1_1Test.dataParentKey")

EC_ADM_TKN="my-legacy-admin-token"
EC_SVC_ID="my-test-id"

JWT_TKN=$(getJwtTkn "$COGNITO_CID" "$COGNITO_CSC" "$COGNITO_URL")

SAC_URL_MST=http://sac-mstr.default.svc.cluster.local
SAC_URL_SLV=http://sac-slav.default.svc.cluster.local
EC_SVC_URL=http://svc.default.svc.cluster.local

source <(wget -q -O - https://raw.githubusercontent.com/ayasuda-ge/sac/main/scripts/mk-installation.sh) \
"$EC_CID" \
"$EC_CSC" \
"$EC_ADM_TKN" \
"$EC_SVC_ID"

sleep 10

: 'cat << EOF

-------------------------------------
[vi] launch agent instance
-------------------------------------
EOF

docker run \
--network=host \
-e AGENT_REV=v1.hokkaido.213 \
-e EC_PPS="$AGT_HS" ghcr.io/ec-release/agt:1 -ver

GTW_TKN=$(printf "admin:%s" "$SvcTkn" | base64 -w0)
GTW_PRT="7991"
GTW_URL="http://localhost:$GTW_PRT"
SVC_URL="http://localhost:$PORT"

agent \
-tkn "$GTW_TKN" \
-sst "$SVC_URL" \
-hst "$GTW_URL" \
-mod "gateway" \
-prt "$GTW_PRT"

agent \
-cid "my-cognito-client-id" \
-csc "my-cognito-client-secret" \
-oa2 "my-cognito-tkn-url" \
-sst "$SVC_URL" \
-hst "$GTW_URL" \
-mod "server" \
-dbg'


cat << EOF

-------------------------------------
[vii] bash-in cont. for test
-------------------------------------

EOF

kubectl exec --stdin --tty agt -- /bin/bash

cat << EOF

-------------------------------------
[viv] endpoints checking
-------------------------------------

EOF

count=1

cat << EOF


 - content delivery (admin)
 - Auth Basic
 - /v1/index/
 - /v1.1/index/swagger.json
 
EOF

x=1
while [ $x -le "$count" ]
do
  if (( "$x" == 1 )); then
    echo - sample response
    curl -u "admin:$EC_ADM_TKN" -sS "${EC_SVC_URL}/v1/index/"
    sleep 0.5
  fi
  
  curl -u "admin:$EC_ADM_TKN" -sS -w "\n[$x] time taken: %{time_total}s (v1)" -o /dev/null "${EC_SVC_URL}/v1/index/"
  sleep 0.5
  curl -u "admin:$EC_ADM_TKN" -sS -w "\n[$x] time taken: %{time_total}s (v1.1)" -o /dev/null "${EC_SVC_URL}/v1.1/index/swagger.json"
  x=$(( $x + 1 ))
  sleep 0.5
done

cat << EOF


 - memory profiling (admin)
 - Auth Basic
 - /v1/health/memory
 - /v1.1/health/memory
 
EOF

x=1
while [ $x -le "$count" ]
do
  if (( "$x" == 1 )); then
    echo - sample response
    curl -u "admin:$EC_ADM_TKN" -sS "${EC_SVC_URL}/v1/health/memory"
    sleep 0.5
  fi
  
  curl -u "admin:$EC_ADM_TKN" -sS -w "\n[$x] time taken: %{time_total}s (v1)" -o /dev/null "${EC_SVC_URL}/v1/health/memory"
  sleep 0.5
  curl -u "admin:$EC_ADM_TKN" -sS -w "\n[$x] time taken: %{time_total}s (v1.1)" -o /dev/null "${EC_SVC_URL}/v1.1/health/memory"
  x=$(( $x + 1 ))
  sleep 0.5
done

cat << EOF


 - cert retrieval (gateway agt)
 - Auth Basic
 - /v1/api/pubkey
 - /v1.1/api/pubkey
 
EOF

x=1
while [ $x -le "$count" ]
do
  if (( "$x" == 1 )); then
    echo - sample response
    curl -u "admin:$EC_ADM_TKN" -sS "${EC_SVC_URL}/v1/api/pubkey" > ./~crt
    cat ~crt | base64 -w0
    sleep 0.5
  fi
  
  curl -u "admin:$EC_ADM_TKN" -sS -w "\n[$x] total time taken: %{time_total}s (v1)" -o /dev/null "${EC_SVC_URL}/v1/api/pubkey"
  sleep 0.5
  curl -u "admin:$EC_ADM_TKN" -sS -w "\n[$x] total time taken: %{time_total}s (v1.1)" -o /dev/null "${EC_SVC_URL}/v1.1/api/pubkey"
  x=$(( $x + 1 ))
  sleep 0.5
done

cat << EOF


 - gateway list exchange (server agt)
 - Auth: Bearer 
 - /v1/api/gateways
 - /v1.1/api/gateways
  - the flow:
   |_ generate encrypted data
     |_ <cognito-url>/oauth/token               |
       |_ <sac-master>/**/**/<ec-cid>/reg       v
         |_ <sac-slave>/**/**/<svc-id>/vfy
           |_ /v1/api/gateways                  | 
           |_ /v1.1/api/gateways                v
             |_ comparing decrypted data   
EOF

#todo: get service cert
docker run \
-e AGENT_REV=v1.hokkaido.213 \
-e EC_PPS="$AGT_HS" \
-v $(pwd)/~crt:/root/.ec/svc.cer \
ghcr.io/ec-release/agt:1 \
-enc -pth .ec/svc.cer -dat "my-random-data" > ~dat
dat=$(cat ~dat | tail -1)

jsnBdy=$(echo '{}' | \
jq ". += {\"data\":\"${dat}\"}" | 
jq '. += {"glist":[]}' | \
jq -c \
--arg timeCreated "$(date +%s%3N)" \
--arg cfURL "$GTW_URL" \
--arg EC_SVC_ID "$EC_SVC_ID" \
'.glist[0] += {"gtwId":"gtw-cf-app-id","zone":$EC_SVC_ID,"refId":"0","timeCreated":$timeCreated,"active":true,"cfRoutingURL":$cfURL,"cfURL":$cfURL}')

x=1; y1=0; y2=0
while [ "$x" -le "$count" ]
do
  if (( "$x" == 1 )); then
    echo the json body: "$jsnBdy"
    echo - sample response
    
    ts1=$(curl -X POST -sS \
-H "Authorization: Bearer ${JWT_TKN}" \
-H "Predix-Zone-Id: ${EC_SVC_ID}" \
-H "Content-Type: application/json" \
-d "$jsnBdy" "${EC_SVC_URL}/v1/api/gateways")
    sleep 0.5
  fi
  
  ts1=$(curl -X POST -sS \
-H "Authorization: Bearer ${JWT_TKN}" \
-H "Predix-Zone-Id: ${EC_SVC_ID}" \
-H "Content-Type: application/json" \
-d "$jsnBdy" \
-w "%{time_total}" \
-o /dev/null "${EC_SVC_URL}/v1/api/gateways")

  sleep 0.5
  
  ts2=$(curl -X POST -sS \
-H "Authorization: Bearer ${JWT_TKN}" \
-H "Predix-Zone-Id: ${EC_SVC_ID}" \
-H "Content-Type: application/json" \
-d "$jsnBdy" \
-w "%{time_total}" \
-o /dev/null "${EC_SVC_URL}/v1.1/api/gateways")

  printf "\n[%s] total time taken: %ss (v1)" "$x" "$ts1"
  printf "\n[%s] total time taken: %ss (v1.1)" "$x" "$ts2"
  x=$(( $x + 1 ))
  y1=$(awk "BEGIN{print $y1+$ts1}")
  y2=$(awk "BEGIN{print $y2+$ts2}")
  sleep 0.5
done

y1=$(awk "BEGIN{print $y1/$count}")
y2=$(awk "BEGIN{print $y2/$count}")

btkn=$(getSdcTkn "$EC_CID" "$EC_CSC" "$SAC_URL_MST")
tdat=$(printf '{"parent":"%s","averagedTimeV1":"%s","averagedTimeV2":"%s","numOfRuns":"%s","objective":"integration service endpoints","pathV1":"/v1/api/gateways","pathV2":"/v1.1/api/gateways","logs":"https://github.com/ayasuda-ge/service1.x/actions/runs/%s"}' "$PRNT_KEY" "$y1" "$y2" "$count" "$GITHUB_RUN_ID")
#echo $tdat
#temp
ref=$(insertData "$SAC_URL_SLV" "service e2e build [$EC_BUILD_ID]" "$btkn" "$tdat")
printf "\n%s" "$ref"

cat << EOF


 - cognito token validation (svc-2-sac)
 - Auth: Bearer
 - the flow:
   |_ <cognito-url>/oauth/token               |
     |_ <sac-master>/**/**/<ec-cid>/reg       v
       |_ <sac-slave>/**/**/<svc-id>/vfy
         |_ /v1/api/token/validate            | 
         |_ /v1.1/api/token/validate          v
 
EOF

x=1; y1=0; y2=0;
while [ "$x" -le "$count" ]
do
  if (( "$x" == 1 )); then
    echo - sample response
    curl -X POST -sS -H "Authorization: Bearer ${JWT_TKN}" "${EC_SVC_URL}/v1/api/token/validate"
    sleep 0.5
  fi
  
  ts1=$(curl -X POST -sS -H "Authorization: Bearer ${JWT_TKN}" -w "%{time_total}" -o /dev/null "${EC_SVC_URL}/v1/api/token/validate")
  sleep 0.5
  ts2=$(curl -X POST -sS -H "Authorization: Bearer ${JWT_TKN}" -w "%{time_total}" -o /dev/null "${EC_SVC_URL}/v1.1/api/token/validate")
  #cat ./tmp && rm ./tmp
  printf "\n[%s] total time taken: %ss (v1)" "$x" "$ts1"
  printf "\n[%s] total time taken: %ss (v1.1)" "$x" "$ts2"
  x=$(( $x + 1 ))
  y1=$(awk "BEGIN{print $y1+$ts1}")
  y2=$(awk "BEGIN{print $y2+$ts2}")
  sleep 0.5
done

y1=$(awk "BEGIN{print $y1/$count}")
y2=$(awk "BEGIN{print $y2/$count}")

btkn=$(getSdcTkn "$EC_CID" "$EC_CSC" "$SAC_URL_MST")
tdat=$(printf '{"parent":"%s","averagedTimeV1":"%s","averagedTimeV2":"%s","numOfRuns":"%s","objective":"integration service endpoints","pathV1":"/v1/api/token/validate","pathV2":"/v1.1/api/token/validate","logs":"https://github.com/ayasuda-ge/service1.x/actions/runs/%s"}' "$PRNT_KEY" "$y1" "$y2" "$count" "$GITHUB_RUN_ID")
#echo $tdat
ref=$(insertData "$SAC_URL_SLV" "service e2e build [$EC_BUILD_ID]" "$btkn" "$tdat")
printf "\n%s" "$ref"

cat << EOF

-------------------------------------
[vv] logs dump & qa data sync
-------------------------------------
EOF
kubectl get pods | grep -e "master"
sleep 10
