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

_Pending deployment._

## AI Service Proof of Concept

_Pending deployment._

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

Claude (Anthropic) wrote the first draft of the Bicep templates, the call script and this README, and ran the CLI commands in Azure Cloud Shell at my direction. I reviewed every change and the what-if output before each deployment. See the reflection in my Canvas submission for what the AI got wrong and what changed.
