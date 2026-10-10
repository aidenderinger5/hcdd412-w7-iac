# hcdd412-w7-iac

Infrastructure as Code for HCDD 412 Week 7. This repo defines a Linux App Service web app and an Azure AI Language resource in Bicep, previews them with `what-if`, deploys them to an Azure for Students subscription, and makes one live sentiment-analysis call.

## What the templates create

| File | Scope | Creates |
|---|---|---|
| `main.bicep` | resource group | Linux App Service plan (**F1**, free), web app (HTTPS only, TLS 1.2 minimum, FTP disabled, Python 3.12), Azure AI Language account (**F0**, free) |
| `budget.bicep` | subscription | $10/month cost budget with email alerts at 50% and 90% of actual spend |
| `bicepconfig.json` | linter | Warns on outdated API versions; errors on secrets in outputs or parameters |
| `scripts/call-language.sh` | n/a | Calls the Language sentiment API using a key from an environment variable |

Resource names follow `plan-<appName>-<env>`, `app-<appName>-<env>-<suffix>` and `lang-<appName>-<env>-<suffix>`. Web app hostnames and AI subdomains must be globally unique, so `<suffix>` is the first 5 characters of `uniqueString(resourceGroup().id)`. That keeps names unique across Azure but stable for this resource group, so redeploying updates resources instead of duplicating them.

### Parameters (`main.bicep`)

| Name | Default | Allowed |
|---|---|---|
| `appName` | (required) | 3–12 letters/numbers |
| `env` | `dev` | `dev`, `staging`, `prod` |
| `location` | resource group location | any region your subscription allows |
| `planSku` | `F1` | `F1`, `B1` |
| `languageSku` | `F0` | `F0`, `S` |

## Deploy

Requires the Azure CLI (Bicep ships with it) or Azure Cloud Shell.

```bash
az login
az provider register --namespace Microsoft.Web
az provider register --namespace Microsoft.CognitiveServices

# 1. Budget alert first (subscription scope, survives resource-group deletion)
az deployment sub create -l <region> -f budget.bicep -p contactEmails='["you@psu.edu"]'

# 2. Resource group
az group create -n rg-hcdd412-w7 -l <region>

# 3. Validate (no output = success)
az bicep build --file main.bicep --stdout > /dev/null

# 4. Preview - every "Create" should be a resource you expect
az deployment group what-if -g rg-hcdd412-w7 -f main.bicep -p appName=<yourid>

# 5. Deploy
az deployment group create -g rg-hcdd412-w7 -n main -f main.bicep -p appName=<yourid>

# 6. Preview again - should report no changes (idempotence)
az deployment group what-if -g rg-hcdd412-w7 -f main.bicep -p appName=<yourid>
```

## Preview evidence

Run 1, before the first deployment (`az deployment group what-if`):

```text
Note: The result may contain false positive predictions (noise).
You can help us improve the accuracy of the result by opening an issue here: https://aka.ms/WhatIfIssues
NOTICE! - Want to get What-if without noise? Move to Deployment Stacks What-If https://aka.ms/stackswhatifGA

Resource and property changes are indicated with this symbol:
  + Create

The deployment will update the following scope:

Scope: /subscriptions/<subscription-id>/resourceGroups/rg-hcdd412-w7

  + Microsoft.CognitiveServices/accounts/lang-aiden-dev-ueccq [2025-06-01]

      apiVersion:                     "2025-06-01"
      id:                             "/subscriptions/<subscription-id>/resourceGroups/rg-hcdd412-w7/providers/Microsoft.CognitiveServices/accounts/lang-aiden-dev-ueccq"
      kind:                           "TextAnalytics"
      location:                       "westus"
      name:                           "lang-aiden-dev-ueccq"
      properties.customSubDomainName: "lang-aiden-dev-ueccq"
      properties.publicNetworkAccess: "Enabled"
      sku.name:                       "F0"
      tags.assignment:                "w7-iac"
      tags.course:                    "hcdd412"
      tags.env:                       "dev"
      type:                           "Microsoft.CognitiveServices/accounts"

  + Microsoft.Web/serverfarms/plan-aiden-dev [2025-03-01]

      apiVersion:          "2025-03-01"
      id:                  "/subscriptions/<subscription-id>/resourceGroups/rg-hcdd412-w7/providers/Microsoft.Web/serverfarms/plan-aiden-dev"
      kind:                "linux"
      location:            "westus"
      name:                "plan-aiden-dev"
      properties.reserved: true
      sku.name:            "F1"
      tags.assignment:     "w7-iac"
      tags.course:         "hcdd412"
      tags.env:            "dev"
      type:                "Microsoft.Web/serverfarms"

  + Microsoft.Web/sites/app-aiden-dev-ueccq [2025-03-01]

      apiVersion:              "2025-03-01"
      id:                      "/subscriptions/<subscription-id>/resourceGroups/rg-hcdd412-w7/providers/Microsoft.Web/sites/app-aiden-dev-ueccq"
      kind:                    "app,linux"
      location:                "westus"
      name:                    "app-aiden-dev-ueccq"
      properties.httpsOnly:    true
      properties.serverFarmId: "/subscriptions/<subscription-id>/resourceGroups/rg-hcdd412-w7/providers/Microsoft.Web/serverfarms/plan-aiden-dev"
      properties.siteConfig:   "*******"
      tags.assignment:         "w7-iac"
      tags.course:             "hcdd412"
      tags.env:                "dev"
      type:                    "Microsoft.Web/sites"

Resource changes: 3 to create.
```

Run 2, the same command after deploying. It shows 2 Modify but nothing to create or delete. Both are known what-if noise, not drift: ARM does not return siteConfig when it reads a web app, so what-if always lists those properties as added, and allowProjectManagement is a server-side default from the 2025-06-01 API that the template does not set. The live values in evidence/live-config.txt match the template:

```text
Note: The result may contain false positive predictions (noise).
You can help us improve the accuracy of the result by opening an issue here: https://aka.ms/WhatIfIssues
NOTICE! - Want to get What-if without noise? Move to Deployment Stacks What-If https://aka.ms/stackswhatifGA

Resource and property changes are indicated with these symbols:
  - Delete
  + Create
  ~ Modify
  = Nochange

The deployment will update the following scope:

Scope: /subscriptions/<subscription-id>/resourceGroups/rg-hcdd412-w7

  ~ Microsoft.CognitiveServices/accounts/lang-aiden-dev-ueccq [2025-06-01]
    - properties.allowProjectManagement: false

  ~ Microsoft.Web/sites/app-aiden-dev-ueccq [2025-03-01]
    + properties.siteConfig.ftpsState:           "Disabled"
    + properties.siteConfig.localMySqlEnabled:   false
    + properties.siteConfig.minTlsVersion:       "1.2"
    + properties.siteConfig.netFrameworkVersion: "v4.6"

  = Microsoft.Web/serverfarms/plan-aiden-dev [2025-03-01]

Resource changes: 2 to modify, 1 no change.
```

Raw copies are in `evidence/`. Subscription IDs are replaced with `<subscription-id>`.

## AI Service Proof of Concept

One live call to Azure AI Language sentiment analysis (F0 tier) via `scripts/call-language.sh`. The key was read into the `LANG_KEY` environment variable for the shell session only.

Input (non-sensitive sample text): "The deployment finished cleanly and the team is thrilled."

Response:

```json
{
    "kind": "SentimentAnalysisResults",
    "results": {
        "documents": [
            {
                "id": "1",
                "sentiment": "positive",
                "confidenceScores": {
                    "positive": 1.0,
                    "neutral": 0.0,
                    "negative": 0.0
                },
                "sentences": [
                    {
                        "sentiment": "positive",
                        "confidenceScores": {
                            "positive": 1.0,
                            "neutral": 0.0,
                            "negative": 0.0
                        },
                        "offset": 0,
                        "length": 57,
                        "text": "The deployment finished cleanly and the team is thrilled."
                    }
                ],
                "warnings": []
            }
        ],
        "errors": [],
        "modelVersion": "2025-01-01"
    }
}
```

Where it sits: behind my Week 6 inference boundary, only the backend web app calls this endpoint, server-side, with the key held in app settings or Key Vault, so the browser never sees the key and only non-sensitive text crosses the boundary.

## Clean up

```bash
az group delete -n rg-hcdd412-w7 --yes
```

The budget lives at subscription scope and stays in place after the resource group is deleted.

## Secrets handling

- No keys, connection strings or state files are in this repo. Bicep keeps no local state file.
- The Language key is read into the `LANG_KEY` shell variable at run time (`az cognitiveservices account keys list ... -o tsv`) and never written to disk.
- Template outputs exclude keys, because deployment outputs are stored in plain text in the resource group's deployment history. `bicepconfig.json` makes a secret in an output a lint error.
- Subscription IDs in the saved what-if output are replaced with `<subscription-id>`.

## AI usage disclosure

Claude wrote the first draft of the Bicep templates, the call script and this README. I reviewed every change and the what-if output before each deployment.
