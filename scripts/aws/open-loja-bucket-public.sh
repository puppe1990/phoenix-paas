#!/usr/bin/env bash
# Run with an AWS admin/root profile for account 840298254452, e.g.:
#   AWS_PROFILE=admin ./scripts/aws/open-loja-bucket-public.sh
set -euo pipefail

BUCKET="${CATALOGO_S3_BUCKET:-loja-gestaobem-prod-840298254452}"
REGION="${AWS_REGION:-us-east-1}"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_command aws

echo "==> AWS identity (must be account admin for 840298254452)"
aws sts get-caller-identity

echo "==> Allow bucket policy + public reads on ${BUCKET}"
aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false

aws s3api put-bucket-policy --bucket "$BUCKET" --policy "$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadTenantImages",
      "Effect": "Allow",
      "Principal": "*",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::${BUCKET}/tenants/*"
    }
  ]
}
EOF
)"

SAMPLE_KEY="${SAMPLE_KEY:-tenants/7cb685e7-f51f-4e9a-ac49-3142975d1ab8/images/0cb8b731-c967-4e55-9f94-94413d0e5ba5.webp}"
PUBLIC_URL="https://${BUCKET}.s3.${REGION}.amazonaws.com/${SAMPLE_KEY}"

echo "==> Testing public object URL"
curl -sI "$PUBLIC_URL" | head -5

echo "Bucket ${BUCKET} is ready for direct S3 image URLs."