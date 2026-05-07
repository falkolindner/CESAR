# Installation Guide (Simple)

This guide is for admins who want the easiest setup with minimal technical steps.

## What gets installed

1. Core package (one-click package install)
2. AI metadata from source (`force-app-ai`) because AI package install URL is currently not available
3. Permission set assignment

## Prerequisites

- Salesforce CLI installed (`sf`)
- You can log in to the target org from CLI
- Agentforce / Prompt Builder features enabled in the org

## Step-by-step

### 1) Open terminal in this project folder

### 2) Login to your org

Production:

```bash
sf org login web --alias my-org --instance-url https://login.salesforce.com
```

Sandbox:

```bash
sf org login web --alias my-org --instance-url https://test.salesforce.com
```

### 3) Run the installer script

```bash
bash scripts/install-core-and-ai.sh --target-org my-org
```

That script will:

- install the Core package version
- deploy AI metadata from `force-app-ai`
- assign permission set `Case_Intelligence_User`

### 4) Open org and finish UI setup

```bash
sf org open --target-org my-org
```

Then in Lightning App Builder:

- add `CaseIntelligenceDashboard` to Case record page
- add `CaseSentimentIndicator` to Case record page

### 5) Verify

- Open a Case with email history.
- Run the analysis.
- Click **Apply Changes**.
- Confirm:
  - Priority/Type/Sub-Type updated
  - Sentiment indicator updated
  - Audit log entries created

## Troubleshooting

- If package install fails, confirm org login and permissions.
- If AI deployment fails, confirm Agentforce/Prompt Builder features are enabled.
- If flow cannot be found in runtime, activate `Agentforce_Case_Classifier` in Flow Builder.
