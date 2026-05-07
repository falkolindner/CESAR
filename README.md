# Agentforce Case Intelligence

Salesforce DX project that adds two Case-focused LWCs:

- `caseIntelligenceDashboard`: classifies Case email history and proposes field updates.
- `caseSentimentIndicator`: visual sentiment indicator based on `Case.AI_Sentiment__c`.

The solution uses an Apex controller (`CaseAIController`) and an Agentforce Flow (`Agentforce_Case_Classifier`) with a safe fallback path if Flow output is unavailable.

## Package Dependencies

This repository now contains:

- LWC + Apex + custom object metadata for Case Intelligence
- Flow metadata: `Agentforce_Case_Classifier`
- Prompt template metadata:
  - `Case_Classifier_Prompt`
  - `Case_Tag_Extractor`

If AI assets are not active or available in the target org, the dashboard still works in fallback mode.

## Features

- Analyze up to 10 related Case emails (`EmailMessage`).
- Suggest Case values (`Priority`, `Type`, `Sub-Type`, `Sentiment`).
- Apply suggestions to Case in one action.
- Store audit history in custom object `Case_AI_Log__c`.
- Display current sentiment with dedicated UI component.

## Project Structure

- `force-app/main/default/lwc/caseIntelligenceDashboard`: recommendation cockpit UI.
- `force-app/main/default/lwc/caseSentimentIndicator`: sentiment badge UI.
- `force-app/main/default/classes/CaseAIController.cls`: server-side orchestration.
- `force-app/main/default/*`: Core package metadata (LWC/Apex/objects/permissions).
- `force-app-ai/main/default/*`: AI package metadata (Flow + Prompt templates).
- `force-app/main/default/objects/Case_AI_Log__c`: audit log object and fields.
- `force-app/main/default/permissionsets/Case_Intelligence_User.permissionset-meta.xml`: baseline permissions.

## Prerequisites

- Node.js 18+ (LTS recommended)
- npm
- Salesforce CLI (`sf`)
- Salesforce org with:
  - `EmailMessage` enabled on Case
  - Custom field `Case.AI_Sentiment__c`
  - Agentforce/Prompt Builder features enabled in the org

## Setup

```bash
npm install
```

Authorize an org and deploy metadata:

```bash
sf org login web --alias my-org
sf project deploy start --target-org my-org
```

Assign permissions:

```bash
sf org assign permset --name Case_Intelligence_User --target-org my-org
```

## Create Install URLs (Unlocked Packages)

Create packages once (Dev Hub):

```bash
sf package create --name "Case Intelligence Core" --package-type Unlocked --path force-app --target-dev-hub MyDevHub
sf package create --name "Case Intelligence AI" --package-type Unlocked --path force-app-ai --target-dev-hub MyDevHub
```

Create and promote versions:

```bash
sf package version create --package "Case Intelligence Core" --installation-key-bypass --wait 60 --target-dev-hub MyDevHub
sf package version promote --package 04tCOREVERSIONID --target-dev-hub MyDevHub --no-prompt

sf package version create --package "Case Intelligence AI" --installation-key-bypass --wait 60 --target-dev-hub MyDevHub
sf package version promote --package 04tAIVERSIONID --target-dev-hub MyDevHub --no-prompt
```

Install URL format:

- Production orgs: `https://login.salesforce.com/packaging/installPackage.apexp?p0=04t...`
- Sandbox orgs: `https://test.salesforce.com/packaging/installPackage.apexp?p0=04t...`

## Installation (Order Matters)

This repo is configured for two unlocked packages:

1. `Case Intelligence Core` (path: `force-app`)
2. `Case Intelligence AI` (path: `force-app-ai`, depends on Core)

Install Core first, then AI.

For the easiest admin workflow, use:

- Script: `scripts/install-core-and-ai.sh`
- Walkthrough: `docs/INSTALL.md`

Then:

- Add `CaseIntelligenceDashboard` to the Case Lightning Record Page.
- Add `CaseSentimentIndicator` to the Case Lightning Record Page.

Both components can be used together or independently. The sentiment indicator reads `Case.AI_Sentiment__c`.

## Suggested Demo Walkthrough

1. Send an email to your Email-to-Case address.
2. Open the created Case and verify email content exists.
3. Open the Case Intelligence dashboard and run analysis.
4. Verify suggested values:
   - Sentiment
   - Priority
   - Type
   - Sub-Type
5. Click **Apply Changes** and confirm Case fields update.
6. Review `Case_AI_Log__c` entries in the Audit Log tab.
7. Continue the thread (support answer + customer reply) and re-run analysis to validate multi-email context behavior.

## Troubleshooting

- **Flow not found (`Agentforce_Case_Classifier`)**  
  Ensure the AI package is installed and the flow is active in the target org.
- **No sentiment visible in indicator**  
  Confirm `Case.AI_Sentiment__c` is populated and user has field access.
- **Unexpected no-op on Sub-Type**  
  `Case.SDO_Sub_Type__c` is set defensively and only when present and updateable in the org.

## Local Quality Checks

Run lint:

```bash
npm run lint
```

Run LWC unit tests:

```bash
npm test
```

Format files:

```bash
npm run prettier
```

## Design and UX Note

The visual design of both LWCs is intentionally custom-styled. Internal hardening changes should preserve the current UI/UX unless explicitly changed.

## Limitations

- Current analysis context is capped at 10 emails.
- If Flow execution fails or returns invalid output, fallback simulation is used.
- Org-specific fields (for example `Case.SDO_Sub_Type__c`) are handled defensively when absent.
