#!/bin/bash
#
#
#
#set -x

PROJECT_PATH=bmoussaud/playlist-service-springboot
#GITLAB_TOKEN=glpat-dqsdqsdqsdqsd
TRIGGER_TOKEN=glptt-dqsdqsdqdqsqs
BRANCH=main
GITLAB_DOMAIN=gitlab.com
OUT_FILE=$(mktemp)

echo "GITLAB_DOMAIN ${GITLAB_DOMAIN}"
echo "PROJECT_PATH  ${PROJECT_PATH}"
echo "BRANCH        ${BRANCH}"

#urlencoded_path="${PROJECT_PATH//'\/'/%2f}" # use `urlencode` if installed, but this works in a pinch
ENCODED_PATH=$(echo ${PROJECT_PATH} | sed 's/\//%2f/g')
#echo "ENCODED_PATH    ${ENCODED_PATH}"
curl --silent --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" https://gitlab.com/api/v4/projects/${ENCODED_PATH} >${OUT_FILE}
PROJECT_ID=$(jq -r .id ${OUT_FILE})
echo "PROJECT_ID    ${PROJECT_ID}"

curl --silent --request POST --form token=${TRIGGER_TOKEN} --form variables[CI_REGISTRY_IMAGE]="valuefromcli" --form ref=${BRANCH} "https://${GITLAB_DOMAIN}/api/v4/projects/${PROJECT_ID}/trigger/pipeline" >${OUT_FILE}

if [ 0 -eq $? ]; then
     STATUS=$(jq -r .status ${OUT_FILE})
     PIPELINE_ID=$(jq -r .id ${OUT_FILE})
     echo "Pipeline[${PIPELINE_ID}]/Status[${STATUS}]"

     if [ ${STATUS} = "created" ]; then
          echo -e "\nSuccess, pipeline is triggered.\n"
     else
          echo -e "\nMost likely something went wrong, check API response:\n"
          cat ${OUT_FILE}
          exit 2
     fi
else
     printf '\nCurl failed with error code "%d"\n' "$?" >&2
     exit 1
fi

x=0

while true; do
     curl --silent --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" "https://${GITLAB_DOMAIN}/api/v4/projects/${PROJECT_ID}/pipelines/${PIPELINE_ID}" >${OUT_FILE}
     #cat ${OUT_FILE} | jq
     x=$(($x + 1))
     STATUS=$(jq -r .status ${OUT_FILE})
     echo "${x} Pipeline[${PIPELINE_ID}]/Status[${STATUS}]"
     case ${STATUS} in

     created)
          #echo "__Created"
          ;;

     success)
          echo "__Succeed Exit !"
          exit 0
          ;;

     running)
          #echo "__Running"
          ;;

     *)
          echo "Unknonw Status ${STATUS}...exit"
          exit 1
          ;;
     esac
     sleep 10
done
