import { createElement } from "@lwc/engine-dom";
import CaseIntelligenceDashboard from "c/caseIntelligenceDashboard";
import getAIClassification from "@salesforce/apex/CaseAIController.getAIClassification";
import saveLogAndMapFields from "@salesforce/apex/CaseAIController.saveLogAndMapFields";
import getAuditLogs from "@salesforce/apex/CaseAIController.getAuditLogs";
import { getRelatedListRecords } from "lightning/uiRelatedListApi";

jest.mock(
  "@salesforce/apex/CaseAIController.getAIClassification",
  () => ({
    default: jest.fn()
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/CaseAIController.saveLogAndMapFields",
  () => ({
    default: jest.fn()
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/CaseAIController.getAuditLogs",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return {
      default: createApexTestWireAdapter(jest.fn())
    };
  },
  { virtual: true }
);

jest.mock(
  "lightning/uiRelatedListApi",
  () => {
    const {
      createLdsTestWireAdapter
    } = require("@salesforce/wire-service-jest-util");
    return {
      getRelatedListRecords: createLdsTestWireAdapter(jest.fn())
    };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex",
  () => ({
    refreshApex: jest.fn(() => Promise.resolve())
  }),
  { virtual: true }
);

const flushPromises = () => Promise.resolve();

describe("c-case-intelligence-dashboard", () => {
  afterEach(() => {
    // The jsdom instance is shared across test cases in a single file so reset the DOM
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders AI recommendation from analysis result", async () => {
    getAIClassification.mockResolvedValue(
      JSON.stringify({
        priority: "High",
        sentiment: "Frustrated",
        type: "Problem",
        subType: "Performance",
        explanation: "Detected urgency in customer email",
        reason: "Rule-based classification"
      })
    );

    const element = createElement("c-case-intelligence-dashboard", {
      is: CaseIntelligenceDashboard
    });
    element.recordId = "500000000000001AAA";

    document.body.appendChild(element);
    getAuditLogs.emit([]);
    getRelatedListRecords.emit({ records: [{ id: "1" }, { id: "2" }] });

    await flushPromises();
    await flushPromises();

    expect(getAIClassification).toHaveBeenCalledTimes(1);
    expect(getAIClassification.mock.calls[0][0].caseId).toBe(
      "500000000000001AAA"
    );
    expect(
      element.shadowRoot.querySelector(".ai-suggestion-box")
    ).not.toBeNull();
  });

  it("applies recommendation and clears suggestion", async () => {
    getAIClassification.mockResolvedValue(
      JSON.stringify({
        priority: "Medium",
        sentiment: "Neutral",
        type: "Question",
        subType: "Installation",
        explanation: "Neutral request detected",
        reason: "Default path"
      })
    );
    saveLogAndMapFields.mockResolvedValue();

    const element = createElement("c-case-intelligence-dashboard", {
      is: CaseIntelligenceDashboard
    });
    element.recordId = "500000000000001AAA";

    document.body.appendChild(element);
    getAuditLogs.emit([]);
    getRelatedListRecords.emit({ records: [] });

    await flushPromises();
    await flushPromises();

    const applyButton = element.shadowRoot.querySelector(
      "lightning-button.action-button"
    );
    applyButton.click();

    await flushPromises();
    await flushPromises();

    expect(saveLogAndMapFields).toHaveBeenCalledTimes(1);
    expect(element.shadowRoot.textContent).toContain("Analysis up to date.");
  });
});
