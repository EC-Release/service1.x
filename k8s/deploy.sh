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

#functional interface to be implemented
# function name: int_a
#
# param1: a base64 string of a custom json object (custom-obj) from script api
# param2: a base64 string of a custom json object during sac instantiation. format: {\"region1-userpool1\":[\"service1\":\"service2\"],\"region1-userpool2\":[\"service1\":\"service2\"]}
# 
# return: stdout. 
# i.e. printf "%s" "{\"decision\":\"PERMIT\"}";return 0;
# i.e. printf "%s" "{\"error\":\"error from aws token verification.\"}";return -1;
# ex: int_a "$EXEC_DAT" "$EXEC_MAP"
 
function int_a() {
  
  echo " [+] install dep pkgs"
  pip --version > /dev/null 2>&1 && echo " [!] pkg pip exists" || apt-get -y install python3-pip
  pip list | grep -i pyyaml && echo " [!] pkg pyyaml exists" || pip install pyyaml
  git --version > /dev/null 2>&1 && echo " [!] pkg git exists" || apt-get -y install git
  
  #printf "{\"req\":%s,\"env\":%s,\"hello\":\"world\"}" "$1" "$2"
  #echo "$2" | jq -r '.CT_GHB_TKN'
  echo " [+] acquiring scripts/assets"
  mkdir -p tmp && cd tmp
  wget -q -O ./dpl.yaml https://raw.githubusercontent.com/ayasuda-ge/service1.x/1.1/k8s/tmpl/dpl_red.yaml 
  wget -q -O ./svc.yaml https://raw.githubusercontent.com/ayasuda-ge/service1.x/1.1/k8s/tmpl/svc_red.yaml 
  wget -q -O ./igs.yaml https://raw.githubusercontent.com/ayasuda-ge/service1.x/1.1/k8s/tmpl/igs.yaml
  wget -q -O ./apps.yaml https://raw.githubusercontent.com/ayasuda-ge/service1.x/1.1/k8s/tmpl/apps.yaml
  wget -q -O ./svc-argocd-app.yaml https://raw.githubusercontent.com/ayasuda-ge/service1.x/1.1/k8s/tmpl/svc-argocd-app.yaml
  
  #sid=$(echo "$1" | jq -r '.SVC_ID')  
  #sed -i "" "s|{{SVC_ID}}|$sid|g" dpl.yaml
  EC_CID=$(echo "$2" | jq -r '.EC_CID')
  EC_CSC=$(echo "$2" | jq -r '.EC_CSC')
  EC_NOD=$(echo "$2" | jq -r '.EC_NOD')
  #TMP_TKN=$(echo "$2" | jq -r '.TMP_TKN')
  
  #OWNER_INF=$(curl -X GET "$EC_NOD" -H "accept: application/json" -H "Authorization: Bearer ${TMP_TKN}")
  
  #echo "OWNER_INF: $OWNER_INF"
  CT_GHB_TKN=$(echo "$2" | jq -r '.CT_GHB_TKN')
  CT_ACD_PTH=$(echo "$2" | jq -r '.CT_ACD_PTH')
  BUILD_ID=$(echo "$2" | jq -r '.BUILD_ID')
 

  tmp_dn=$(echo "$2" | jq -r '.CT_FQDN')
  tmp_dn_svc=$(echo "$2" | jq -r '.CT_FQDN_SVC')
  tmp_ar=$(echo "$2" | jq -r '.CT_ACD_REP')
  tmp_sl=$(echo "$2" | jq -r '.CT_SVC_LST')
  CT_ACD_REP=$(echo -n "${tmp_ar/<%CT_GHB_TKN%>/$CT_GHB_TKN}")
  CT_SVC_LST=$(echo -n "${tmp_sl/<%CT_GHB_TKN%>/$CT_GHB_TKN}")
  curl -Ss -o ~list "$CT_SVC_LST"
  git clone "$CT_ACD_REP" psd
  app_bas="$(pwd)/psd"
  app_dir="${app_bas}/${CT_ACD_PTH}"
  svc_dir="${app_bas}/svc"
  
  rm "$app_dir" \
  && cp ./apps.yaml "$app_dir"
        
  x=0
  while read -r line; do
    
    if [[ -z "$line" ]]; then
      if [[ "$ref0" == "yes" ]]; then
        echo " [x] end of the svc spec"
        printf "\n"
        ref0="no"
        
        #test
        #break
      fi
        
    else
      if [[ "$line" == *"service instance"* ]]; then
        #if (( "$x" == 10 )); then
        #  break
        #fi
          
        echo " [${x}] begin of the svc spec"
        ref0="yes"
      else
        ref1=$(echo $line | cut -d '=' -f 1)
        ref2=$(echo $line | cut -d '=' -f 2)
        case $ref1 in
         ZONE)
         
          if [[ "$ref2" == *"888d91ee-c556-4d31-869f-c6e937bfa7af"* ]] || [[ "$ref2" == *"9e768876-7fe6-413c-8330-9e2d7ad42c7b"* ]]; then
            echo ""
            echo " [!] service ${ref2} discarded."
            echo ""
            continue
          fi
          
          echo " ZONE: $ref2"
          
          mkdir -p "./${ref2}" \
          && cp ./dpl.yaml "./${ref2}/" \
          && cp ./svc.yaml "./${ref2}/" \
          && cp ./igs.yaml "./${ref2}/" \
          && cp ./svc-argocd-app.yaml "./~apps"
          
          CT_FQDN=$(echo -n "${tmp_dn/<%SVC_ID%>/$ref2}")
          #CT_FQDN_SVC=$(echo -n "${tmp_dn_svc/<%SVC_ID%>/$ref2}")
          
          sed -i "s|{{SVC_ID}}|${ref2}|g" "./${ref2}/dpl.yaml"
          sed -i "s|{{SVC_ADM_TKN}}|${SVC_ADM_TKN}|g" "./${ref2}/dpl.yaml"
          sed -i "s|{{SVC_SETTING}}|${SVC_SETTING}|g" "./${ref2}/dpl.yaml"
          sed -i "s|{{EC_NOD}}|${EC_NOD}|g" "./${ref2}/dpl.yaml"
          sed -i "s|{{BUILD_ID}}|${BUILD_ID}|g" "./${ref2}/dpl.yaml"
          
          sed -i "s|{{SVC_ID}}|${ref2}|g" "./${ref2}/svc.yaml"
          sed -i "s|{{SVC_ID}}|${ref2}|g" "./${ref2}/igs.yaml"
          sed -i "s|{{SVC_FQDN}}|${CT_FQDN}|g" "./${ref2}/igs.yaml"
          sed -i "s|{{SVC_ID}}|${ref2}|g" "./~apps"
          
          cat "./~apps" >> "$app_dir"
          #OWNER_INF=$(echo "$OWNER_INF" | jq '.SVC_LIST += {"'$ref2'":["https://'$CT_FQDN'","http://'$CT_FQDN_SVC'"]}')
          #'. += {"456f":["123"]}'
          #echo ""
          echo " [!] service ${ref2} updated."
          #cat "./${ref2}/dpl.yaml" "./${ref2}/svc.yaml" "./${ref2}/igs.yaml" "$app_dir"
          #echo ""
            
          [[ -d "${svc_dir}/${ref2}" ]] && rm -Rf "${svc_dir}/${ref2}"
          mv "./${ref2}" "${svc_dir}/${ref2}"
          x=$(( $x + 1 ))
          ;;
         ADMIN_TKN)
          SVC_ADM_TKN="$ref2"
          ;;
         EC_SETTINGS)
          SVC_SETTING="$ref2"
          ;;
         #*)
          #echo " [-] unhandled val ${ref1}: ${ref2}"
          #;;
        esac
      fi      
    fi
  done < ~list
  
  cd - && cd "$app_bas"
  git add .
  git config user.name "ec.bot"
  git config user.email "ec.bot@ge.local"
  git commit -m 'update svc'
  git push origin master -f
  
  echo " svc count: ${x}"
  #rm -Rf tmp
  cd - && rm -Rf tmp
  exit 0
}
