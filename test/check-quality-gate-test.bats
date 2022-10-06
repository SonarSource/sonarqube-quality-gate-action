#!/usr/bin/env bats

setup() {
  DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  PATH="$DIR/../src:$PATH"
  export GITHUB_OUTPUT=${BATS_TEST_TMPDIR}/github_output
  touch ${GITHUB_OUTPUT}
  touch metadata_tmp
}

teardown() {
  rm -f metadata_tmp
  unset GITHUB_OUTPUT
}

@test "fail when SONAR_TOKEN not provided" {
  run script/check-quality-gate.sh
  [ "$status" -eq 1 ]
  [ "$output" = "Set the SONAR_TOKEN env variable." ]
}

@test "use URL from SONAR_HOST_URL instead of metadata file when it is provided" {
  export SONAR_TOKEN="test"
  export SONAR_HOST_URL="http://sonarqube.org/" # Add a trailing slash, so we validate it correctly removes it.
  echo "serverUrl=http://localhost:9000" >> metadata_tmp
  echo "ceTaskUrl=http://localhost:9000/api/ce/task?id=AXlCe3gsFwOUsY8YKHTn" >> metadata_tmp

  #mock curl
  function curl() {
    url="${@: -1}"
    if [[ $url == "http://localhost:9000/"* ]]; then
      echo '{"error":["Not found"]}'
    elif [[ $url == "http://sonarqube.org/api/qualitygates/project_status?analysisId"* ]]; then
      echo '{"projectStatus":{"status":"OK"}}'
    else
      echo '{"task":{"analysisId":"AXlCe3jz9LkwR9Gs0pBY","status":"SUCCESS"}}'
    fi
  }
  export -f curl

  run script/check-quality-gate.sh metadata_tmp
  [ "$status" -eq 0 ]
}

@test "fail when metadata file not exist" {
  rm -f metadata_tmp
  export SONAR_TOKEN="test"
  run script/check-quality-gate.sh
  [ "$status" -eq 1 ]
  [ "$output" = " does not exist." ]
}

@test "fail when empty metadata file" {
  export SONAR_TOKEN="test"
  run script/check-quality-gate.sh metadata_tmp
  [ "$status" -eq 1 ]
  [ "$output" = "Invalid report metadata file." ]
}

@test "fail when no Quality Gate status" {
  export SONAR_TOKEN="test"
  echo "serverUrl=http://localhost:9000" >> metadata_tmp
  echo "ceTaskUrl=http://localhost:9000/api/ce/task?id=AXlCe3gsFwOUsY8YKHTn" >> metadata_tmp

  #mock curl
  function curl() {
     echo '{"task":{"analysisId":"AXlCe3jz9LkwR9Gs0pBY","status":"SUCCESS"}}'
  }
  export -f curl

  run script/check-quality-gate.sh metadata_tmp

  read -r github_out_actual < ${GITHUB_OUTPUT}

  [ "$status" -eq 1 ]
  [[ "${github_out_actual}" = "name=quality-gate-status::FAILED" ]]
  [[ "$output" = *"Quality Gate not set for the project. Please configure the Quality Gate in SonarQube or remove sonarqube-quality-gate action from the workflow."* ]]
}

@test "fail when Quality Gate status WARN" {
  export SONAR_TOKEN="test"
  echo "serverUrl=http://localhost:9000" >> metadata_tmp
  echo "ceTaskUrl=http://localhost:9000/api/ce/task?id=AXlCe3gsFwOUsY8YKHTn" >> metadata_tmp

  #mock curl
  function curl() {
    url="${@: -1}"
     if [[ $url == *"/api/qualitygates/project_status?analysisId"* ]]; then
       echo '{"projectStatus":{"status":"WARN"}}'
     else
       echo '{"task":{"analysisId":"AXlCe3jz9LkwR9Gs0pBY","status":"SUCCESS"}}'
     fi
  }
  export -f curl

  run script/check-quality-gate.sh metadata_tmp

  read -r github_out_actual < ${GITHUB_OUTPUT}

  [ "$status" -eq 1 ]
  [[ "${github_out_actual}" = "name=quality-gate-status::WARN" ]]
  [[ "$output" = *"Warnings on Quality Gate."* ]]
}

@test "fail when Quality Gate status ERROR" {
  export SONAR_TOKEN="test"
  echo "serverUrl=http://localhost:9000" >> metadata_tmp
  echo "ceTaskUrl=http://localhost:9000/api/ce/task?id=AXlCe3gsFwOUsY8YKHTn" >> metadata_tmp

  #mock curl
  function curl() {
    url="${@: -1}"
     if [[ $url == *"/api/qualitygates/project_status?analysisId"* ]]; then
       echo '{"projectStatus":{"status":"ERROR"}}'
     else
       echo '{"task":{"analysisId":"AXlCe3jz9LkwR9Gs0pBY","status":"SUCCESS"}}'
     fi
  }
  export -f curl

  run script/check-quality-gate.sh metadata_tmp

  read -r github_out_actual < ${GITHUB_OUTPUT}

  [ "$status" -eq 1 ]
  [[ "${github_out_actual}" = "name=quality-gate-status::FAILED" ]]
  [[ "$output" = *"Quality Gate has FAILED."* ]]
}

@test "pass when Quality Gate status OK" {
  export SONAR_TOKEN="test"
  echo "serverUrl=http://localhost:9000" >> metadata_tmp
  echo "ceTaskUrl=http://localhost:9000/api/ce/task?id=AXlCe3gsFwOUsY8YKHTn" >> metadata_tmp

  #mock curl
  function curl() {
    url="${@: -1}"
     if [[ $url == *"/api/qualitygates/project_status?analysisId"* ]]; then
       echo '{"projectStatus":{"status":"OK"}}'
     else
       echo '{"task":{"analysisId":"AXlCe3jz9LkwR9Gs0pBY","status":"SUCCESS"}}'
     fi
  }
  export -f curl

  run script/check-quality-gate.sh metadata_tmp

  read -r github_out_actual < ${GITHUB_OUTPUT}

  [ "$status" -eq 0 ]
  [[ "${github_out_actual}" = "name=quality-gate-status::PASSED" ]]
  [[ "$output" = *"Quality Gate has PASSED."* ]]
}

@test "pass when Quality Gate status OK and status starts from IN_PROGRESS" {
  export SONAR_TOKEN="test"
  export COUNTER_FILE=${BATS_TEST_TMPDIR}/counter
  echo "serverUrl=http://localhost:9000" >> metadata_tmp
  echo "ceTaskUrl=http://localhost:9000/api/ce/task?id=AXlCe3gsFwOUsY8YKHTn" >> metadata_tmp

  printf "5" > ${COUNTER_FILE}

  #mock curl
  function curl() {
    read -r counter < ${COUNTER_FILE}

    url="${@: -1}"
     if [[ $url == *"/api/qualitygates/project_status?analysisId"* ]]; then
       echo '{"projectStatus":{"status":"OK"}}'
     elif [[ $counter -gt 0 ]]; then
       echo '{"task":{"analysisId":"AXlCe3jz9LkwR9Gs0pBY","status":"IN_PROGRESS"}}'
       printf "%d\n" "$(( --counter ))" > ${COUNTER_FILE}
     else
       echo '{"task":{"analysisId":"AXlCe3jz9LkwR9Gs0pBY","status":"SUCCESS"}}'
     fi
  }
  export -f curl

  #mock sleep
  function sleep() {
    return 0
  }
  export -f sleep

  run script/check-quality-gate.sh metadata_tmp

  read -r github_out_actual < ${GITHUB_OUTPUT}

  [ "$status" -eq 0 ]
  [[ "${github_out_actual}" = "name=quality-gate-status::PASSED" ]]
  # lines[0] is the dots from waiting for status to move to SUCCESS
  [[ "${lines[0]}" = "....." ]]
  [[ "${lines[1]}" = *"Quality Gate has PASSED."* ]]
}
