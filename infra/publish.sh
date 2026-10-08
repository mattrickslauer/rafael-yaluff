#!/usr/bin/env bash
# Publish the site files to S3 and bust the CloudFront cache. Used by CI on every push to
# main and by infra/deploy.sh. Needs AWS credentials that can read the stack outputs.
set -euo pipefail

STACK="${STACK:-rafael-yaluff}"
export AWS_DEFAULT_REGION="${AWS_REGION:-us-east-1}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

out() { aws cloudformation describe-stacks --stack-name "$STACK" \
  --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text; }
BUCKET="$(out SiteBucketName)"
DIST_ID="$(out DistributionId)"
DIST_DOMAIN="$(out DistributionDomain)"

# The repo root is the site, minus the things that aren't.
EXCLUDES=( --exclude '.*' --exclude '*/.*' --exclude 'infra/*' --exclude 'README.md' )

echo "Syncing to $BUCKET"
aws s3 sync "$ROOT" "s3://$BUCKET" --delete --only-show-errors "${EXCLUDES[@]}"

# HTML and JSON are edited by hand and must show up right away; images are large and
# rarely change, so browsers may keep them for a day (the invalidation covers the edge).
B="s3://$BUCKET"
aws s3 cp "$B" "$B" --recursive --only-show-errors \
  --exclude "*" --include "*.html" --metadata-directive REPLACE \
  --content-type "text/html; charset=utf-8" \
  --cache-control "public, max-age=0, must-revalidate"
aws s3 cp "$B" "$B" --recursive --only-show-errors \
  --exclude "*" --include "*.json" --metadata-directive REPLACE \
  --content-type "application/json; charset=utf-8" \
  --cache-control "public, max-age=0, must-revalidate"
aws s3 cp "$B" "$B" --recursive --only-show-errors \
  --exclude "*" --include "*.css" --metadata-directive REPLACE \
  --content-type "text/css; charset=utf-8" \
  --cache-control "public, max-age=300"

echo "Invalidating CloudFront"
INV="$(aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths '/*' \
  --query 'Invalidation.Id' --output text)"
aws cloudfront wait invalidation-completed --distribution-id "$DIST_ID" --id "$INV"

# A green deploy that serves a broken page is worse than a red one.
D="https://${DIST_DOMAIN}"
for path in / /paintings.html /cv.html /paintings.json /styles.css; do
  code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 30 "$D$path")
  [ "$code" = "200" ] || { echo "$path returned $code"; exit 1; }
done
echo "Published: $D"
