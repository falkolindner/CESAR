/**
 * @description Controller für die Case Classification LWC.
 * API Version: 61.0
 * Production Version: Flow-First Ansatz mit Fallback-Simulation.
 */
public with sharing class CaseAIController {
  @AuraEnabled
  public static String getAIClassification(
    Id caseId,
    String typeOptions,
    String subTypeOptions
  ) {
    ensureReadable(
      Schema.EmailMessage.SObjectType,
      'EmailMessage Zugriff fehlt.'
    );
    ensureReadable(Schema.Case.SObjectType, 'Case Zugriff fehlt.');

    List<EmailMessage> emails = [
      SELECT TextBody, Incoming
      FROM EmailMessage
      WHERE ParentId = :caseId
      ORDER BY MessageDate ASC
      LIMIT 10
    ];

    if (emails.isEmpty()) {
      throw new AuraHandledException('Keine E-Mails für die Analyse gefunden.');
    }

    List<String> contextParts = new List<String>();
    Boolean isUrgent = false;

    for (EmailMessage em : emails) {
      String role = em.Incoming ? 'CUSTOMER: ' : 'SUPPORT: ';
      String body = em.TextBody != null ? em.TextBody.left(1000) : '';
      contextParts.add(role + body);

      // Einfache Heuristik für Fallback-Simulation
      if (
        em.Incoming &&
        (body.containsIgnoreCase('urgent') ||
        body.containsIgnoreCase('wichtig') ||
        body.contains('!'))
      ) {
        isUrgent = true;
      }
    }
    String contextStr = String.join(contextParts, '\n');

    try {
      // Flow Inputs vorbereiten
      Map<String, Object> flowInputs = new Map<String, Object>();
      flowInputs.put('recordId', caseId);
      flowInputs.put('emailContext', contextStr);
      flowInputs.put('typeOptions', typeOptions);
      flowInputs.put('subTypeOptions', subTypeOptions);

      // Flow aufrufen
      Flow.Interview myFlow = Flow.Interview.createInterview(
        'Agentforce_Case_Classifier',
        flowInputs
      );
      myFlow.start();

      // Ergebnis lesen
      String flowResult = (String) myFlow.getVariableValue('outputJson');

      if (String.isNotBlank(flowResult)) {
        return cleanJson(flowResult, isUrgent, typeOptions, subTypeOptions);
      } else {
        // Fallback, falls Flow leer zurückkommt
        return simulateResponse(
          isUrgent,
          typeOptions,
          subTypeOptions,
          'Flow lieferte kein Ergebnis.'
        );
      }
    } catch (Exception e) {
      System.debug('Agentforce Flow Fehler: ' + e.getMessage());
      // Fallback bei technischem Fehler (damit die UI nicht crasht)
      return simulateResponse(
        isUrgent,
        typeOptions,
        subTypeOptions,
        'Verbindungsfehler: ' + e.getMessage()
      );
    }
  }

  private static String cleanJson(
    String input,
    Boolean isUrgent,
    String typeOptions,
    String subTypeOptions
  ) {
    Integer firstBrace = input.indexOf('{');
    Integer lastBrace = input.lastIndexOf('}');
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      return input.substring(firstBrace, lastBrace + 1);
    }
    return simulateResponse(
      isUrgent,
      typeOptions,
      subTypeOptions,
      'Flow Ergebnis war kein valides JSON.'
    );
  }

  // Fallback-Simulation (ohne Diagnose-Tags für saubere UI)
  private static String simulateResponse(
    Boolean isUrgent,
    String typeOpts,
    String subTypeOpts,
    String internalReason
  ) {
    List<String> types = typeOpts.split('#');
    List<String> subTypes = subTypeOpts.split('#');

    // Wir zeigen dem User eine verständliche Meldung, loggen den Fehler aber intern (siehe reason)
    String explanation = isUrgent
      ? 'Aufgrund der Dringlichkeit im Text wird eine hohe Priorität empfohlen (Fallback-Modus).'
      : 'Standard-Analyse basierend auf Text-Keywords (Fallback-Modus).';

    return JSON.serialize(
      new Map<String, Object>{
        'reason' => 'System-Fallback (' +
        internalReason +
        ')',
        'priority' => isUrgent ? 'High' : 'Medium',
        'type' => types.isEmpty() ? 'Problem' : types[0],
        'subType' => subTypes.isEmpty() ? 'General' : subTypes[0],
        'sentiment' => isUrgent ? 'Frustrated' : 'Neutral',
        'explanation' => explanation
      }
    );
  }

  @AuraEnabled
  public static void saveLogAndMapFields(
    Id caseId,
    String resultJson,
    Boolean isApplied
  ) {
    try {
      Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(
        resultJson
      );
      String explanation = getStringValue(data, 'explanation');
      String sentiment = getStringValue(data, 'sentiment');
      String priority = getStringValue(data, 'priority');
      String typeValue = getStringValue(data, 'type');
      String reason = getStringValue(data, 'reason');
      String subType = getStringValue(data, 'subType');

      Case_AI_Log__c log = new Case_AI_Log__c();
      log.Case__c = caseId;
      log.Reasoning__c = explanation;
      log.Sentiment__c = sentiment;

      // NEU: Speichern der vorgeschlagenen Werte
      log.Suggested_Priority__c = priority;
      log.Suggested_Type__c = typeValue;
      log.Suggested_Subtype__c = subType;

      log.Applied__c = isApplied;
      log.Analysis_Date__c = System.now();
      ensureCreatable(
        Schema.Case_AI_Log__c.SObjectType,
        'Case_AI_Log kann nicht erstellt werden.'
      );
      SObjectAccessDecision createDecision = Security.stripInaccessible(
        AccessType.CREATABLE,
        new List<SObject>{ log }
      );
      insert (Case_AI_Log__c) createDecision.getRecords()[0];

      if (isApplied) {
        // HIER IST DIE ÄNDERUNG FÜR DYNAMIC APEX
        ensureUpdateable(
          Schema.Case.SObjectType,
          'Case kann nicht aktualisiert werden.'
        );
        Case c = new Case(Id = caseId);

        // Standard-Felder können statisch bleiben
        c.Priority = priority;
        c.Type = typeValue;
        c.Reason = reason;

        // Custom Fields, die wir besitzen (AI_Sentiment__c), können statisch bleiben
        c.AI_Sentiment__c = sentiment;

        // Custom Field, das wir NICHT besitzen (SDO_Sub_Type__c), wird dynamisch gesetzt
        // Das verhindert den Compiler-Fehler, wenn das Feld im Paket fehlt.
        if (
          Schema.SObjectType.Case.fields.getMap().containsKey('SDO_Sub_Type__c')
        ) {
          Schema.DescribeFieldResult subTypeFieldDescribe = Schema.SObjectType.Case.fields.getMap()
            .get('SDO_Sub_Type__c')
            .getDescribe();
          if (subTypeFieldDescribe.isUpdateable()) {
            c.put('SDO_Sub_Type__c', subType);
          }
        }

        SObjectAccessDecision updateDecision = Security.stripInaccessible(
          AccessType.UPDATABLE,
          new List<SObject>{ c }
        );
        update (Case) updateDecision.getRecords()[0];
      }
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Fehler beim Speichern: ' + e.getMessage()
      );
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<Case_AI_Log__c> getAuditLogs(Id caseId) {
    ensureReadable(
      Schema.Case_AI_Log__c.SObjectType,
      'Case_AI_Log kann nicht gelesen werden.'
    );
    // Query erweitert um Name (AutoNumber) für die Anzeige im Link
    List<Case_AI_Log__c> logs = [
      SELECT
        Id,
        Name,
        Analysis_Date__c,
        Sentiment__c,
        Applied__c,
        Reasoning__c,
        Suggested_Priority__c,
        Suggested_Type__c,
        Suggested_Subtype__c
      FROM Case_AI_Log__c
      WHERE Case__c = :caseId
      ORDER BY Analysis_Date__c DESC
    ];
    SObjectAccessDecision readDecision = Security.stripInaccessible(
      AccessType.READABLE,
      logs
    );
    return (List<Case_AI_Log__c>) readDecision.getRecords();
  }

  private static String getStringValue(Map<String, Object> data, String key) {
    if (data == null || !data.containsKey(key) || data.get(key) == null) {
      return null;
    }
    return String.valueOf(data.get(key));
  }

  private static void ensureReadable(
    Schema.SObjectType objectType,
    String message
  ) {
    if (!objectType.getDescribe().isAccessible()) {
      throw new AuraHandledException(message);
    }
  }

  private static void ensureCreatable(
    Schema.SObjectType objectType,
    String message
  ) {
    if (!objectType.getDescribe().isCreateable()) {
      throw new AuraHandledException(message);
    }
  }

  private static void ensureUpdateable(
    Schema.SObjectType objectType,
    String message
  ) {
    if (!objectType.getDescribe().isUpdateable()) {
      throw new AuraHandledException(message);
    }
  }
}
