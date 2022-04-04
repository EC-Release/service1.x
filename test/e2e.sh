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

cat << EOF

-------------------------------------
[i] environment setting
-------------------------------------
EOF
source <(wget -q -O - https://raw.githubusercontent.com/EC-Release/sdk/disty/scripts/libs/db.sh)

SVC_PORT=443
EC_SVC_ID="my-test-id"
#enable svc tls
EC_SVC_URL="https://localhost:${SVC_PORT}"
EC_PRVT_PWD="$EC_PRVT_PWD"
ADMIN_USR="admin"
ADMIN_TKN="my-legacy-admin-token"

SAC_MST_PORT=7991
SAC_SLV_PORT=7992
SAC_TYPE_MST="master"
SAC_TYPE_SLV="slave"
SAC_URL_MST="http://localhost:${SAC_MST_PORT}"
SAC_URL_SLV="http://localhost:${SAC_SLV_PORT}"

GTW_PORT=7993
GTW_URL="http://localhost:${GTW_PORT}"

#build info
crdj=$(getCredJson "cred.json" "$EC_GITHUB_TOKEN")
EC_CID=$(echo $crdj | jq -r ".svc1_1DkrTest.devId")
EC_CSC=$(echo $crdj | jq -r ".svc1_1DkrTest.ownerHash")
AGT_HS=$(echo $crdj | jq -r ".svc1_1DkrTest.pps4agt1")
PRNT_KEY=$(echo $crdj | jq -r ".svc1_1DkrTest.dataParentKey")

JWT_TKN=$(getJwtTkn "$COGNITO_CID" "$COGNITO_CSC" "$COGNITO_URL")

cat << EOF

-------------------------------------
[ii] mockup legacy setting
-------------------------------------
EOF

#EC_SETTING=$(printf '{"%s":{"ids":["my-aid-1","my-aid-2"],"trustedIssuerIds":["legacy-cf-uaa-url"]}}' "$EC_SVC_ID" | jq -aRs . | base64 -w0)      
EC_SETTING=$(printf '{"%s":{"ids":["my-aid-1","my-aid-2"],"trustedIssuerIds":["legacy-cf-uaa-url"]}}' "$EC_SVC_ID" | base64 -w0)      

cat << EOF

-------------------------------------
[iii] launch sac master
-------------------------------------
EOF

SHR_DIR="$(pwd)/pv"
LIC_DIR="$SHR_DIR/oauth/license"
MOD_DIR="$SHR_DIR/sac-mstr/license"
mkdir -p "$LIC_DIR"
EC_CID=$(trimStr "$EC_CID")
CRT_FIL="${LIC_DIR}/${EC_CID}.cer"  

getPublicCrt "$EC_CID" "$EC_GITHUB_TOKEN" > "$CRT_FIL"
PID=$(getCsrId "$CRT_FIL")
PVK_FIL="${LIC_DIR}/${PID}.key"
getPrivateKey "$PID" "$EC_GITHUB_TOKEN" > "$PVK_FIL"
    
docker run \
--network=host \
--name="$SAC_TYPE_MST" \
-e SAC_TYPE="$SAC_TYPE_MST" \
-e SAC_URL="$SAC_URL_MST" \
-e EC_CID="$EC_CID" \
-e EC_CSC="$EC_CSC" \
-e EC_PORT=":$SAC_MST_PORT" \
-v "$SHR_DIR":/root/.ec \
-p "$SAC_MST_PORT:$SAC_MST_PORT" \
-d \
ghcr.io/ec-release/sac:"$SAC_TYPE_MST" &> /dev/null

: 'sk=$(getSdcTkn "$EC_API_DEV_ID" "$CA_PPRS" "$EC_API_OA2")  
x=1; count=20
while [ $x -le "$count" ]
do  
    sleep 0.5
    #echo - connecting log host: "$EC_SEED_HOST"
    loggerUp "$EC_SEED_HOST" "$sk" "$INST_LOG"'

#exit 1

sleep 10
 
cat << EOF

-------------------------------------
[iv] launch sac slave
-------------------------------------
EOF

curl -s -o $(pwd)/.db https://${EC_GITHUB_TOKEN}@raw.githubusercontent.com/EC-Release/data-storage/main/seederAdm.db

docker run \
--network=host \
--name="$SAC_TYPE_SLV" \
-e SAC_TYPE="$SAC_TYPE_SLV" \
-e SAC_URL_MST="$SAC_URL_MST" \
-e SAC_URL="$SAC_URL_SLV" \
-e EC_CID="$EC_CID" \
-e EC_CSC="$EC_CSC" \
-e EC_PORT=":$SAC_SLV_PORT" \
-v $(pwd)/.db:/root/.ec/.db \
-p "$SAC_SLV_PORT:$SAC_SLV_PORT" \
-d \
ghcr.io/ec-release/sac:"$SAC_TYPE_SLV" &> /dev/null

sleep 10

cat << EOF

-------------------------------------
[v] launch service instance
-------------------------------------
EOF

mkdir -p ./svcs

#
# EC_TLS, EC_PVTKEY, EC_PUBCRT used only when enable tls in svc v1.1 (in this test)
# EC_SVC_ID, EC_SVC_URL, EC_SETTING, ADMIN_USR, ADMIN_TKN, EC_PRVT_PWD all are legacy setting
#

docker run \
--network=host \
--name=svc \
-e EC_SVC_ID="$EC_SVC_ID" \
-e EC_SVC_URL="$EC_SVC_URL" \
-e EC_SETTING="$EC_SETTING" \
-e ADMIN_USR="$ADMIN_USR" \
-e ADMIN_TKN="$ADMIN_TKN" \
-e EC_PRVT_PWD="$EC_PRVT_PWD" \
-e EC_SAC_MSTR_URL="$SAC_URL_MST" \
-e EC_SAC_SLAV_URL="$SAC_URL_SLV" \
-e EC_CID="$EC_CID" \
-e EC_CSC="$EC_CSC" \
-e EC_PORT=":$SVC_PORT" \
-e EC_TLS=true \
-e EC_PVTKEY="$(cat ${MOD_DIR}/${PID}.key|base64 -w0)" \
-e EC_PUBCRT="$(cat ${MOD_DIR}/${EC_CID}.cer|base64 -w0)" \
-v "$(pwd)/svcs:/root/svcs" \
-p "$SVC_PORT:$SVC_PORT" \
-d \
ghcr.io/ec-release/svc:1.1 &> /dev/null

cat << EOF

-------------------------------------
[vii] initialising test
-------------------------------------

EOF

sleep 10

cat << EOF

-------------------------------------
[viii] verify serialised service setting 
-------------------------------------

EOF

tree ./svcs
cat ./svcs/$EC_SVC_ID.json

cat << EOF

-------------------------------------
[viv] endpoints checking
-------------------------------------

EOF

count=1

cat << EOF


 - cert retrieval (gateway agt)
 - Auth Basic
 - /v1/certs/service
 - /v1.1/certs/service
 
EOF

x=1
while [ $x -le "$count" ]
do
  if (( "$x" == 1 )); then
    echo - sample response
    curl -k -u "$ADMIN_USR:$ADMIN_TKN" -sS "${EC_SVC_URL}/v1/certs/service" > ./~crt
    #curl -k -u "admin:$EC_ADM_TKN" -sS "${EC_SVC_URL}/v1/api/pubkey" > ./~crt
    cat ~crt | base64 -w0
    sleep 0.5
  fi
  
  curl -k -u "$ADMIN_USR:$ADMIN_TKN" -sS -w "\n[$x] total time taken: %{time_total}s (v1)" -o /dev/null "${EC_SVC_URL}/v1/certs/service"
  sleep 0.5
  curl -k -u "$ADMIN_USR:$ADMIN_TKN" -sS -w "\n[$x] total time taken: %{time_total}s (v1.1)" -o /dev/null "${EC_SVC_URL}/v1.1/certs/service"
  x=$(( $x + 1 ))
  sleep 0.5
done

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
    curl -k -u "$ADMIN_USR:$ADMIN_TKN" -sS "${EC_SVC_URL}/v1/index/"
    sleep 0.5
  fi
  
  curl -k -u "$ADMIN_USR:$ADMIN_TKN" -sS -w "\n[$x] time taken: %{time_total}s (v1)" -o /dev/null "${EC_SVC_URL}/v1/index/"
  sleep 0.5
  curl -k -u "$ADMIN_USR:$ADMIN_TKN" -sS -w "\n[$x] time taken: %{time_total}s (v1.1)" -o /dev/null "${EC_SVC_URL}/v1.1/index/swagger.json"
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
    curl -k -u "$ADMIN_USR:$ADMIN_TKN" -sS "${EC_SVC_URL}/v1/health/memory"
    sleep 0.5
  fi
  
  curl -k -u "$ADMIN_USR:$ADMIN_TKN" -sS -w "\n[$x] time taken: %{time_total}s (v1)" -o /dev/null "${EC_SVC_URL}/v1/health/memory"
  sleep 0.5
  curl -k -u "$ADMIN_USR:$ADMIN_TKN" -sS -w "\n[$x] time taken: %{time_total}s (v1.1)" -o /dev/null "${EC_SVC_URL}/v1.1/health/memory"
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
    
    ts1=$(curl -k -X POST -sS \
-H "Authorization: Bearer ${JWT_TKN}" \
-H "Predix-Zone-Id: ${EC_SVC_ID}" \
-H "Content-Type: application/json" \
-d "$jsnBdy" "${EC_SVC_URL}/v1/api/gateways")
    sleep 0.5
  fi
  
  ts1=$(curl -k -X POST -sS \
-H "Authorization: Bearer ${JWT_TKN}" \
-H "Predix-Zone-Id: ${EC_SVC_ID}" \
-H "Content-Type: application/json" \
-d "$jsnBdy" \
-w "%{time_total}" \
-o /dev/null "${EC_SVC_URL}/v1/api/gateways")

  sleep 0.5
  
  ts2=$(curl -k -X POST -sS \
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
    curl -k -X POST -sS -H "Authorization: Bearer ${JWT_TKN}" "${EC_SVC_URL}/v1/api/token/validate"
    sleep 0.5
  fi
  
  ts1=$(curl -k -X POST -sS -H "Authorization: Bearer ${JWT_TKN}" -w "%{time_total}" -o /dev/null "${EC_SVC_URL}/v1/api/token/validate")
  sleep 0.5
  ts2=$(curl -k -X POST -sS -H "Authorization: Bearer ${JWT_TKN}" -w "%{time_total}" -o /dev/null "${EC_SVC_URL}/v1.1/api/token/validate")
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
[vi] launch agent instance
-------------------------------------
EOF

AGT_TKN=$(printf "$ADMIN_USR:$ADMIN_TKN"|base64 -w0)

timeout -k 15 15 \
docker run \
--network=host \
-e AGENT_REV=v1.hokkaido.213 \
-e EC_PPS="$AGT_HS" \
-p "$GTW_PORT:$GTW_PORT" \
ghcr.io/ec-release/agt:1 \
-mod gateway \
-dbg \
-gpt "$GTW_PORT" \
-zon "$EC_SVC_ID" \
-grp "$EC_SVC_ID" \
-sst "$EC_SVC_URL" \
-tkn "$AGT_TKN" \
-hst "$GTW_URL"

: 'GTW_TKN=$(printf "admin:%s" "$SvcTkn" | base64 -w0)
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
[vv] logs dump & qa data sync
-------------------------------------
EOF
docker logs svc --tail 500
sleep 10
