#!/bin/bash

REPOSITORY_URI="550879144543.dkr.ecr.us-west-2.amazonaws.com"
REPO="school-alerter"

ECS_TASK_JSON="ecs-task.json"

die() {
    echo >&2 "=> ERROR: $@"
    exit 1
}

# Verify jq is installed
if ! type jq > /dev/null 2>&1; then
    die "jq is a required dependency. To install, 'brew install jq'."
fi

# Verify that AWS CLI is properly configured
if [[ -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" || -z "$EC2_REGION" ]]; then
    die "AWS CLI not properly configured. Missing: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and/or EC2_REGION."
fi

# Verify changes have been committed
gitCommitStatus=$(git status --porcelain)
if [ "$gitCommitStatus" != "" ]; then
    die "You have uncommitted files."
fi

# Verify commits have been pushed to remote
gitPushStatus=$(git cherry -v)
if [ "$gitPushStatus" != "" ]; then
    die "You have local commits that were NOT pushed."
fi

getPreviousVersion() {
    local previous_version=$(git tag | sort -t "." -k1,1n -k2,2n -k3,3n | tail -n 1);
    if [[ -z $previous_version ]]; then
        previous_version="0.0.0"
    fi
    echo $previous_version
}

makeNewVersion() {
    local prevVersion=$(getPreviousVersion)
    local regEx="\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)"
    local previousMajor=$(echo $prevVersion | sed "s/$regEx/\1/")
    local previousMinor=$(echo $prevVersion | sed "s/$regEx/\2/")
    local previousTick=$(echo $prevVersion | sed "s/$regEx/\3/")
    let "newTick=$previousTick+1"
    local newVersion="$previousMajor.$previousMinor.$newTick"
    echo $newVersion
}

printChangeLog() {
    local previousTags=$(git tag | sort -t "." -k1,1rn -k2,2rn -k3,3rn | head -n 2);
    local lastTwoTags=$(echo $previousTags | sed "s/-$//")
    local tmpHashes=$(git show-ref --tags -s $lastTwoTags | tail -r | tr "\\n" "-")
    local lastTwo=${tmpHashes/-/...}
    local lastTwoHashes=$(echo $lastTwo | sed "s/-$//")
    git log --pretty=oneline --no-merges --abbrev-commit $lastTwoHashes
}

TAG=$1
if [[ -z $TAG ]]; then
    TAG=$(makeNewVersion)
fi

echo "Deploying tag: $TAG"

# Does this tag already exist in git?
git rev-parse $TAG > /dev/null 2>&1
if [[ $? != 0 ]]; then
    echo "Specified tag does not exist yet.  Tagging git repo with tag: $TAG.";

    git tag -a $TAG -m "Tag bot." > /dev/null 2>&1
    if [[ $? != 0 ]]; then
        die "Failed to create git tag."
    fi

    git push origin --tags > /dev/null 2>&1
    if [[ $? != 0 ]]; then
        die "Failed to push tag to git origin.";
    fi
fi

echo "====== CHANGE LOG ========"
printChangeLog
echo "=========================="

# Verify ECR repository exists
REPO_DESCRIPTOR=$(aws ecr describe-repositories | jq "(.repositories[] | select(.repositoryName==\"$REPO\"))")
if [[ -z $REPO_DESCRIPTOR ]]; then
    # Repo doesn't exist - create it
    echo "ECR repository, $REPO, does not exist. Creating it."
    aws ecr create-repository --repository-name $REPO > /dev/null 2>&1
    if [[ $? != 0 ]]; then
        die "Failed to create ECR repository, $REPO.";
    fi
fi

IMAGE="$REPOSITORY_URI/$REPO:$TAG"

pushd ..

echo "Building docker image: $IMAGE"

docker build -t $IMAGE .
if [[ $? != 0 ]]; then
    die "Failed to build docker image.";
fi

echo "Pushing docker image to ECR"
PUSHED_IMAGE=0

docker push $IMAGE
if [[ $? != 0 ]]; then
    # Likely failed because of expired credentials... re-authenticate
    echo "ECR credentials have expired - attempting to re-authenticate..."
    eval $(aws ecr get-login --no-include-email --region $EC2_REGION)

    # Re-try push
    docker push $IMAGE
    if [[ $? -eq 0 ]]; then
        PUSHED_IMAGE=1
    fi
else
    PUSHED_IMAGE=1
fi

if [[ $PUSHED_IMAGE != 1 ]]; then
    die "Failed to push docker image.";
fi

popd

# Splice image name into ECS task template
CLI_JSON=`cat $ECS_TASK_JSON | sed -e 's@__IMAGE__@'"$IMAGE"'@'`

# Create new task definition with ECS
aws ecs register-task-definition --cli-input-json "$CLI_JSON" > /dev/null 2>&1
if [[ $? != 0 ]]; then
    die "ECS register-task-definition failed."
fi

echo "Successfully deployed."
