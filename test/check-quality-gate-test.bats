#!/usr/bin/env bats

setup() {
  DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  PATH="$DIR/../src:$PATH"
  touch metadata_tmp
}

teardown() {
  rm -f metadata_tmp
}

@test "fail when SONAR_TOKEN not provided" {
  run script/check-quality-gate.sh
  [ "$status" -eq 1 ]
  [ "$output" = "Set the SONAR_TOKEN env variable." ]
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
  [ "$status" -eq 1 ]
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
  [ "$status" -eq 1 ]
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
  [ "$status" -eq 1 ]
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
  [ "$status" -eq 0 ]
  [[ "$output" = *"Quality Gate has PASSED."* ]]
}

