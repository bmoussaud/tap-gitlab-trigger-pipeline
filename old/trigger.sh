#!/bin/bash
#
#
#
set -x
GITLAB_TOKEN=glpat-ES9YgYAP7P_tztuzb_Xy
PIPELINE_TOKEN=glptt-c096678d64032fd7fa4ffa19a6900c17edb28cd4
PROJECT_ID=54102014
BRANCH=main
GITLAB_DOMAIN=gitlab.com
curl --request POST \
     --form token=${PIPELINE_TOKEN} \
     --form ref=${BRANCH} \
     "https://${GITLAB_DOMAIN}/api/v4/projects/${PROJECT_ID}/trigger/pipeline"
