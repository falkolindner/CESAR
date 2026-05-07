import { LightningElement, api, track, wire } from "lwc";
import getAIClassification from "@salesforce/apex/CaseAIController.getAIClassification";
import saveLogAndMapFields from "@salesforce/apex/CaseAIController.saveLogAndMapFields";
import getAuditLogs from "@salesforce/apex/CaseAIController.getAuditLogs";
import { getRelatedListRecords } from "lightning/uiRelatedListApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";

export default class CaseIntelligenceDashboard extends LightningElement {
  @api recordId;
  @api typeOptions = "Problem#Question#Feature Request";
  @api subTypeOptions = "Installation#Performance#UI#Security";

  @track suggestion = null;
  @track isLoading = false;
  @track isSaving = false;
  @track logs = [];

  @track emailCount = 0;

  wiredLogsResult;

  @wire(getRelatedListRecords, {
    parentRecordId: "$recordId",
    relatedListId: "Emails",
    fields: ["EmailMessage.Id"]
  })
  wiredEmails({ error, data }) {
    if (data) {
      const total = data.records.length;
      this.emailCount = total > 10 ? 10 : total;
    } else if (error) {
      console.error("Error counting emails:", error);
      this.emailCount = 0;
    }
  }

  logColumns = [
    {
      label: "Date",
      fieldName: "Analysis_Date__c",
      type: "date",
      typeAttributes: {
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
        hour: "2-digit",
        minute: "2-digit"
      },
      initialWidth: 140
    },
    {
      label: "Sentiment",
      fieldName: "Sentiment__c",
      initialWidth: 120
    },
    {
      label: "Status",
      fieldName: "Applied__c",
      type: "boolean",
      initialWidth: 80
    },
    {
      label: "Reasoning",
      fieldName: "Reasoning__c",
      type: "text",
      wrapText: false,
      initialWidth: 300
    },
    {
      label: "Log File",
      fieldName: "recordUrl",
      type: "url",
      typeAttributes: { label: { fieldName: "Name" }, target: "_blank" },
      initialWidth: 110
    }
  ];

  @wire(getAuditLogs, { caseId: "$recordId" })
  wiredLogs(result) {
    this.wiredLogsResult = result;
    if (result.data) {
      this.logs = result.data.map((log) => {
        return {
          ...log,
          recordUrl: `/lightning/r/Case_AI_Log__c/${log.Id}/view`
        };
      });
    } else if (result.error) {
      console.error("Log Error:", result.error);
      this.logs = [];
    }
  }

  get hasLogs() {
    return this.logs && this.logs.length > 0;
  }

  connectedCallback() {
    this.triggerAnalysis();
  }

  async triggerAnalysis() {
    this.isLoading = true;
    try {
      const result = await getAIClassification({
        caseId: this.recordId,
        typeOptions: this.typeOptions,
        subTypeOptions: this.subTypeOptions
      });

      const parsedResult = JSON.parse(result);

      this.suggestion = {
        ...parsedResult,
        sentimentClass: this.getBadgeClass(parsedResult.sentiment)
      };
    } catch (error) {
      console.error("Analysis Error:", error);
      this.showToast(
        "Error",
        "Analysis failed: " +
          (error.body?.message || error.message || "Unknown error"),
        "error"
      );
      this.suggestion = null;
    } finally {
      this.isLoading = false;
    }
  }

  // UPDATE: Nutzung eigener CSS Klassen für den "Modern UI" Look
  getBadgeClass(sentiment) {
    const s = (sentiment || "").toLowerCase();
    let theme = "badge-neutral";

    if (s.includes("positive")) theme = "badge-success";
    else if (s.includes("neutral")) theme = "badge-neutral";
    else if (s.includes("frustrated")) theme = "badge-warning";
    else if (s.includes("angry")) theme = "badge-error";

    // 'custom-badge' ist unsere Basisklasse im CSS
    return `custom-badge ${theme}`;
  }

  async handleApply() {
    this.isSaving = true;
    try {
      await saveLogAndMapFields({
        caseId: this.recordId,
        resultJson: JSON.stringify(this.suggestion),
        isApplied: true
      });
      this.showToast("Success", "Case successfully updated.", "success");
      this.suggestion = null;
      await refreshApex(this.wiredLogsResult);
    } catch (error) {
      this.showToast(
        "Error",
        "Save failed: " + (error.body?.message || error.message),
        "error"
      );
    } finally {
      this.isSaving = false;
    }
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
