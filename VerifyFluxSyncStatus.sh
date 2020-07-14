#!/bin/bash

while getopts :t: option
do
    case "${option}" in
    t) GIT_SYNC_TAG=${OPTARG};;
    *) echo "ERROR: Please refer to usage guide on GitHub" >&2
        exit 1 ;;
    esac
done

if [ -z "$GIT_SYNC_TAG" ]; then
    GIT_SYNC_TAG="sync-dev"
fi
echo "GIT_SYNC_TAG=$GIT_SYNC_TAG"

START_COMMIT_ID=$(git rev-parse HEAD)
echo "START_COMMIT_ID=$START_COMMIT_ID"

Seconds=0
while [ $Seconds -lt 600 ]
do
	Seconds=$((Seconds+10))
	gitPull=$(git pull --tags -f)
	Commits=$(git rev-list $START_COMMIT_ID^..HEAD)
    Commit_Array=($(echo "$Commits" | tr ',' '\n'))
    for commitId in "${Commit_Array[@]}"; do
        echo "Attempt after: $Seconds sec: checking commit id $commitId"
        tags=$(git describe --tags $commitId)
        tags2=$(git tag --contains $commitId)
        echo "Attempt after: $Seconds sec: tags=$tags"

        if [ -z "$tags" ]; then
            echo "Attempt after: $Seconds sec: tags empty at commit $commitId"
        else
            tag_array=($(echo "$tags" | tr ',' '\n'))
            echo "Attempt after: $Seconds sec: Checking commit: $commitId, tags: $tags"

            if [[ " ${tag_array[@]} " =~ " ${GIT_SYNC_TAG} " ]]; then
                echo "Found flux-sync tag at commit: $commitId"
                exit 0
            fi

            if [ -z "$tags2" ]; then
                echo "tags empty"
            else
                tag_array2=($(echo "$tags2" | tr ',' '\n'))
                echo "Attempt after: $Seconds sec: Checking commit: $commitId, tags: $tags2"

                if [[ " ${tag_array2[@]} " =~ " ${GIT_SYNC_TAG} " ]]; then
                    echo "Found flux-sync tag at commit: $commitId"
                    exit 0
                fi
            fi
            
        fi
	done
	sleep 10s
done

echo "Unable to find GIT_SYNC_TAG: $GIT_SYNC_TAG" >&2
exit 1
