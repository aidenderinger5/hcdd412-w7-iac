#!/usr/bin/env bash
# Sentiment analysis call to Azure AI Language.
# Reads the key and endpoint from environment variables only - never from a file in this repo.
#   export LANG_ENDPOINT=$(az deployment group show -g rg-hcdd412-w7 -n main --query properties.outputs.languageEndpoint.value -o tsv)
#   export LANG_KEY=$(az cognitiveservices account keys list -g rg-hcdd412-w7 -n <languageAccountName> --query key1 -o tsv)
#   ./scripts/call-language.sh "Some non-sensitive sample text."
set -euo pipefail
: "${LANG_ENDPOINT:?Set LANG_ENDPOINT to the languageEndpoint deployment output}"
: "${LANG_KEY:?Set LANG_KEY from az cognitiveservices account keys list}"

TEXT="${1:-The deployment finished cleanly and the team is thrilled.}"
BODY=$(python3 -c 'import json,sys; print(json.dumps({"kind":"SentimentAnalysis","parameters":{"modelVersion":"latest"},"analysisInput":{"documents":[{"id":"1","language":"en","text":sys.argv[1]}]}}))' "$TEXT")

curl -sS -X POST "${LANG_ENDPOINT%/}/language/:analyze-text?api-version=2023-04-01" \
  -H "Ocp-Apim-Subscription-Key: ${LANG_KEY}" \
  -H "Content-Type: application/json" \
  -d "$BODY" | python3 -m json.tool
