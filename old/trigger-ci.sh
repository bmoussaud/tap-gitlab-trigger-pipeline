#!/usr/bin/env bash

# Function to print help.
usage() {
cat << EOF
Usage: ./trigger-ci-job.sh [-afhprt]

Force a pipeline rerun of a specific ref (branch or tag) by making
an Gitlab API call.

-a      <api-url>
        (Optional) The API URL without trailing slash.
        May be set in .env file as API_URL=...
        In Gitlab CI use predefined environment variable CI_API_V4_URL
        Defaults to "https://gitlab.com/api/v4".

-f      <name:value>
        A form variable to be included in the API call.
        Variable name and value needs to be separated by a colon.

-h
        (Optional) Print short help page and exit.

-p      <project-id>
        The project id.
        May be set in .env file as PROJECT_ID=...
        In Gitlab CI use predefined environment variable CI_PROJECT_ID

-r      <ref>
        (Optional) The ref (branch or tag name)
        Defaults to "main"

-t      <trigger-token>
        The trigger token.
        May be set in .env file as TRIGGER_TOKEN=...
        In Gitlab CI use predefined environment variable CI_JOB_TOKEN

--------------------------------------------------------------------
                             EXAMPLES
--------------------------------------------------------------------

Assuming the API URL, project id, and trigger token are set in your
.env file, the following commands will trigger the jobs shown below
them. Unless specified differently, all jobs are run on main branch.

$ ./trigger-ci.sh

some_job:
  script:
    - echo "some job"
  only:
    - triggers

$ ./trigger-ci.sh -f JOB_NAME:some_job -f "MESSAGE:Some message"

some_job:
  script:
    - echo "some job"
    - echo $MESSAGE
  only:
    variables:
      - \$JOB_NAME == "some_job"

--------------------------------------------------------------------
                              BEWARE!
--------------------------------------------------------------------

Make sure your token is kept secret. You should NOT add it to source
code and push it to your repository. Add it to an .env file instead.
The .env file, in turn, should be listed in your .gitignore file.

CLI arguments that .env may contain:

cli arg  | variable name
-------- | ---------------------------------------------------------
-a       | API_URL
-p       | PROJECT_ID
-t       | TRIGGER_TOKEN

Command line arguments always take precedence over their counterpart
set in .env file.

EOF
}

# Function to read a given entry from .env file.
read_env_var() {
  if [ -z "$1" ]; then
    echo "environment variable name parameter missing"
    return
  fi

  if [ ! -f ".env" ]; then
    return
  fi

  local VAR;
  VAR=$(grep "$1" ".env" | xargs)
  IFS="=" read -ra VAR <<< "$VAR"
  echo "${VAR[1]}"
}

# Get command line arguments / .env entries.
API_URL_ENV=$(read_env_var API_URL)
API_URL="${API_URL_ENV:-https://gitlab.com/api/v4}"
PROJECT_ID=$(read_env_var PROJECT_ID)
REF=main
TRIGGER_TOKEN=$(read_env_var TRIGGER_TOKEN)
FORM_VARS=""

while getopts a:f:hp:r:t: option; do
    case $option
    in
        a) API_URL=$OPTARG;;
        f) VARS+=("$OPTARG");;
        h)
            usage
            exit 0
            ;;
        p) PROJECT_ID=$OPTARG;;
        r) REF=$OPTARG;;
        t) TRIGGER_TOKEN=$OPTARG;;
        *)
            usage >&2
            exit 1
            ;;
    esac
done

# Build variables JSON.
# Error on values not being set correctly.
ERRORS=""

for VAL in "${VARS[@]}"; do
    IFS=':' read -ra VAR <<< "$VAL"
    if [ "${#VAR[@]}" -eq 2 ]; then
        FORM_VARS="${FORM_VARS},\"${VAR[0]}\":\"${VAR[1]}\""
    else
        ERRORS="${ERRORS}\nError: incorrect variable notation. \"var:val\" expected. \"$VAL\" given."
    fi
done

if [ -z "$PROJECT_ID" ]; then
  ERRORS="$ERRORS\nError: project id not set"
fi

if [ -z "$TRIGGER_TOKEN" ]; then
  ERRORS="$ERRORS\nError: trigger token not set"
fi

if [[ -n $ERRORS ]]; then
  echo -e "$ERRORS\n"
  echo "Run:"
  echo -e "./trigger-ci.sh -h\n"
  exit 1
fi

# Print values.
echo ""
echo "API URL ......... $API_URL"
echo "Project ID ...... $PROJECT_ID"
echo "Trigger Token ... *****"
echo "Ref ............. $REF"
echo "Form Variables .." "${VARS[@]}"
echo ""

# Trigger the pipeline.
RESP=$(curl --request POST --header "Content-Type:application/json" --data "{ \"token\": \"$TRIGGER_TOKEN\", \"ref\": \"$REF\", \"variables\": {${FORM_VARS:1}} }" "$API_URL/projects/$PROJECT_ID/trigger/pipeline")

if [ 0 -eq $? ]; then
    STATUS=$(grep -o '(?<="status":")[^"]*' <<< "$RESP")
    if [ "$STATUS" = "created" ]; then
        echo -e "\nSuccess, pipeline is triggered.\n"
    else
        echo -e "\nMost likely something went wrong, check API response:\n"
        echo -e "\n$RESP\n"
    fi
else
    printf '\nCurl failed with error code "%d"\n' "$?" >&2
    exit 1
fi