#!/bin/bash

while getopts :n:i:t:e:w: option
do
    case "${option}" in
    n) SERVICE_NAME=${OPTARG};;
    i) IMAGE_NAME=${OPTARG};;
    t) IMAGE_TAG=${OPTARG};;
    e) ENV_NAME=${OPTARG};;
    w) WORKLOAD_TYPE=${OPTARG};;
    *) echo "ERROR: Please refer to usage guide on GitHub" >&2
        exit 1 ;;
    esac
done

global_rematch() { 
    local s=$1 regex=$2 
    while [[ $s =~ $regex ]]; do 
        echo "${BASH_REMATCH[1]}"
        s=${s#*"${BASH_REMATCH[1]}"}
    done
}

if [ -z "$SERVICE_NAME" ]; then
    echo "Missing SERVICE_NAME"
    exit 1
else 
    echo "SERVICE_NAME=$SERVICE_NAME"
fi

if [ -z "$IMAGE_NAME" ]; then 
    IMAGE_NAME="$SERVICE_NAME"
fi
echo "IMAGE_NAME=$IMAGE_NAME"

if [ -z "$IMAGE_TAG" ]; then
    echo "Missing IMAGE_TAG"
    exit 1
else 
    echo "IMAGE_TAG=$IMAGE_TAG"
fi

if [ -z "$ENV_NAME" ]; then
    ENV_NAME="dev"
fi
echo "ENV_NAME=$ENV_NAME"
if [ -z "$WORKLOAD_TYPE" ]; then
    WORKLOAD_TYPE="deployment"
fi
echo "ENV_NAME=$WORKLOAD_TYPE"

Seconds=0
image_name_pattern="${IMAGE_NAME//[-]/\-}"
image_tag_patter="${IMAGE_TAG//[-]/\-}"

while [ $Seconds -lt 360 ]
do
    Service_File="./generated/$ENV_NAME/svc/$SERVICE_NAME/$WORKLOAD_TYPE.yaml"
    echo "Attempt after: $Seconds sec: checking generated manifest file: $Service_File"
    yaml_content="$(cat $Service_File)"
    if [ $(expr $Seconds % 100) -eq 0 ]; then 
        echo -e $yaml_content
    fi 
    if [[ $(echo -e "$yaml_content" | grep "$image_name_pattern:$image_tag_patter") ]]; then
        echo "Found image with same tag at commit: $commitId"
        exit 0
    fi

	sleep 10s
    Seconds=$((Seconds+10))
	gitPull=$(git pull --tags -f)
done

echo "Unable to find service with expected tag: $COMMIT_MESSAGE" >&2
exit 1