#!/usr/bin/env bash

source "$(dirname "$0")/common.sh"

if [[ -z "${SONAR_TOKEN}" ]]; then
  echo "Set the SONAR_TOKEN env variable."
  exit 1
fi

metadataFile="$1"

if [[ ! -f "$metadataFile" ]]; then
   echo "$metadataFile does not exist."
   exit 1
fi

if [[ ! -z "${SONAR_HOST_URL}" ]]; then
   serverUrl="${SONAR_HOST_URL%/}"
   ceTaskUrl="${SONAR_HOST_URL%/}/api$(sed -n 's/^ceTaskUrl=.*api//p' "${metadataFile}")"
else
   serverUrl="$(sed -n 's/serverUrl=\(.*\)/\1/p' "${metadataFile}")"
   ceTaskUrl="$(sed -n 's/ceTaskUrl=\(.*\)/\1/p' "${metadataFile}")"
fi

if [ -z "${serverUrl}" ] || [ -z "${ceTaskUrl}" ]; then
  echo "Invalid report metadata file."
  exit 1
fi

task="$(curl --location --location-trusted --max-redirs 10  --silent --fail --show-error --user "${SONAR_TOKEN}": "${ceTaskUrl}")"
status="$(jq -r '.task.status' <<< "$task")"

until [[ ${status} != "PENDING" && ${status} != "IN_PROGRESS" ]]; do
    printf '.'
    sleep 5s
    task="$(curl --location --location-trusted --max-redirs 10 --silent --fail --show-error --user "${SONAR_TOKEN}": "${ceTaskUrl}")"
    status="$(jq -r '.task.status' <<< "$task")"
done

analysisId="$(jq -r '.task.analysisId' <<< "${task}")"
qualityGateUrl="${serverUrl}/api/qualitygates/project_status?analysisId=${analysisId}"
qualityGateStatus="$(curl --location --location-trusted --max-redirs 10 --silent --fail --show-error --user "${SONAR_TOKEN}": "${qualityGateUrl}" | jq -r '.projectStatus.status')"

if [[ ${qualityGateStatus} == "OK" ]]; then
   echo '::set-output name=quality-gate-status::PASSED'
   success "Quality Gate has PASSED."
elif [[ ${qualityGateStatus} == "WARN" ]]; then
   echo '::set-output name=quality-gate-status::WARN'
   warn "Warnings on Quality Gate."
elif [[ ${qualityGateStatus} == "ERROR" ]]; then
   echo '::set-output name=quality-gate-status::FAILED'
   fail "Quality Gate has FAILED."
else
   echo '::set-output name=quality-gate-status::FAILED'
   fail "Quality Gate not set for the project. Please configure the Quality Gate in SonarQube or remove sonarqube-quality-gate action from the workflow."
fi

