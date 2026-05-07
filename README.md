# Agentforce Case Intelligence

Salesforce DX project that adds two Case-focused LWCs:

- `caseIntelligenceDashboard`: classifies Case email history and proposes field updates.
- `caseSentimentIndicator`: visual sentiment indicator based on `Case.AI_Sentiment__c`.

The solution uses an Apex controller (`CaseAIController`) and an Agentforce Flow (`Agentforce_Case_Classifier`) with a safe fallback path if Flow output is unavailable.

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
- `force-app/main/default/objects/Case_AI_Log__c`: audit log object and fields.
- `force-app/main/default/permissionsets/Case_Intelligence_User.permissionset-meta.xml`: baseline permissions.

## Prerequisites

- Node.js 18+ (LTS recommended)
- npm
- Salesforce CLI (`sf`)
- Salesforce org with:
  - `EmailMessage` enabled on Case
  - Custom field `Case.AI_Sentiment__c`
  - Flow `Agentforce_Case_Classifier` (or fallback mode will be used)

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
