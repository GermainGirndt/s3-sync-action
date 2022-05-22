#!/bin/sh

set -e

BRANCH=${GITHUB_REF##*/}
echo "Brach name: $BRANCH"
[[ $BRANCH = "production" ]] && IS_PRODUCTION="true" || IS_PRODUCTION=false
echo "IS_PRODUCTION: $IS_PRODUCTION"

if [ -z "$AWS_S3_BUCKET" ]; then
  echo "AWS_S3_BUCKET is not set. Quitting."
  exit 1
fi


if [ -z "$AWS_S3_STAGING_BUCKET" ]; then
  echo "AWS_S3_STAGING_BUCKET is not set. Quitting."
  exit 1
fi

if [ -z "$AWS_ACCESS_KEY_ID" ]; then
  echo "AWS_ACCESS_KEY_ID is not set. Quitting."
  exit 1
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
  echo "AWS_SECRET_ACCESS_KEY is not set. Quitting."
  exit 1
fi

# Default to us-east-1 if AWS_REGION not set.
if [ -z "$AWS_REGION" ]; then
  AWS_REGION="us-east-1"
fi

# Override default AWS endpoint if user sets AWS_S3_ENDPOINT.
if [ -n "$AWS_S3_ENDPOINT" ]; then
  ENDPOINT_APPEND="--endpoint-url $AWS_S3_ENDPOINT"
fi


# Sets the AWS_S3_BUCKET going to be used (production/staging bucket)
if [ "$IS_PRODUCTION" == "true" ] ; then
    AWS_S3_BUCKET_TO_BE_USED=$PRODUCTION_BUCKET
    echo "production!"
elif [ "$IS_PRODUCTION" == "false" ] ; then
    AWS_S3_BUCKET_TO_BE_USED=$STAGING_BUCKET
    echo "staging!"
else
    echo "IS_PRODUCTION must be 'true' or 'false'. Found: $IS_PRODUCTION"
    exit 1
fi

echo "Production: "
echo $PRODUCTION_BUCKET
echo "Staging: "
echo $STAGING_BUCKET
    
echo "Bucket to be used: $AWS_S3_BUCKET_TO_BE_USED"

# Create a dedicated profile for this action to avoid conflicts
# with past/future actions.
# https://github.com/jakejarvis/s3-sync-action/issues/1
aws configure --profile s3-sync-action <<-EOF > /dev/null 2>&1
${AWS_ACCESS_KEY_ID}
${AWS_SECRET_ACCESS_KEY}
${AWS_REGION}
text
EOF

aws s3 ls

# Sync using our dedicated profile and suppress verbose messages.
# All other flags are optional via the `args:` directive.
sh -c "aws s3 sync ${SOURCE_DIR:-.} s3://${AWS_S3_BUCKET_TO_BE_USED}/${DEST_DIR} \
              --profile s3-sync-action \
              --no-progress \
              ${ENDPOINT_APPEND} $*"

# Clear out credentials after we're done.
# We need to re-run `aws configure` with bogus input instead of
# deleting ~/.aws in case there are other credentials living there.
# https://forums.aws.amazon.com/thread.jspa?threadID=148833
aws configure --profile s3-sync-action <<-EOF > /dev/null 2>&1
null
null
null
text
EOF
