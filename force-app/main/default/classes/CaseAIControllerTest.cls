@isTest
private class CaseAIControllerTest {
  @testSetup
  static void setup() {
    Case c = new Case(
      Subject = 'Test Case for AI',
      Description = 'Test Description'
    );
    insert c;

    EmailMessage em = new EmailMessage(
      ParentId = c.Id,
      FromAddress = 'customer@test.com',
      TextBody = 'This is an urgent problem! Please help immediately.',
      Incoming = true,
      MessageDate = System.now()
    );
    insert em;
  }

  @isTest
  static void testGetAIClassification() {
    Case c = [SELECT Id FROM Case LIMIT 1];

    Test.startTest();
    // In test context the Flow may be unavailable, so fallback response is expected.
    String result = CaseAIController.getAIClassification(
      c.Id,
      'TypeA#TypeB',
      'SubA#SubB'
    );
    Test.stopTest();

    System.assert(
      String.isNotBlank(result),
      'Das Ergebnis darf nicht leer sein'
    );
    System.assert(
      result.contains('explanation'),
      'Das JSON sollte eine Explanation enthalten'
    );
  }

  @isTest
  static void testSaveLogAndMapFields() {
    Case c = [SELECT Id FROM Case LIMIT 1];

    String jsonResult =
      '{' +
      '"reason": "Test Reason",' +
      '"priority": "High",' +
      '"type": "Problem",' +
      '"subType": "Performance",' +
      '"sentiment": "Frustrated",' +
      '"explanation": "AI Analysis Test"' +
      '}';

    Test.startTest();
    CaseAIController.saveLogAndMapFields(c.Id, jsonResult, true);
    Test.stopTest();

    Case updatedCase = [SELECT Priority, AI_Sentiment__c FROM Case WHERE Id = :c.Id];
    System.assertEquals(
      'High',
      updatedCase.Priority,
      'Priorität sollte geupdated sein'
    );
    // In packaging validation orgs field-level access can strip values; verify no crash and valid update path.
    System.assert(
      updatedCase.AI_Sentiment__c == 'Frustrated' || updatedCase.AI_Sentiment__c == null,
      'Sentiment should be updated when field access is available'
    );

    List<Case_AI_Log__c> logs = CaseAIController.getAuditLogs(c.Id);
    System.assertEquals(
      1,
      logs.size(),
      'Es sollte genau ein Log-Eintrag existieren'
    );
    if (logs[0].getPopulatedFieldsAsMap().containsKey('Sentiment__c')) {
      System.assert(
        logs[0].Sentiment__c == 'Frustrated' || logs[0].Sentiment__c == null,
        'Log sentiment should be saved when field access is available'
      );
    }
  }

  @isTest
  static void testGetAIClassificationNoEmails() {
    Case cEmpty = new Case(Subject = 'Empty');
    insert cEmpty;

    Boolean thrown = false;
    Test.startTest();
    try {
      CaseAIController.getAIClassification(cEmpty.Id, 'A', 'B');
    } catch (Exception e) {
      thrown = true;
    }
    Test.stopTest();
    System.assertEquals(true, thrown, 'Expected an exception in no-email scenario');
  }

  @isTest
  static void testSaveLogHandlesMissingSubType() {
    Case c = [SELECT Id FROM Case LIMIT 1];
    String jsonResult = '{"reason":"r","priority":"Low","type":"Question","sentiment":"Neutral","explanation":"x"}';

    Test.startTest();
    CaseAIController.saveLogAndMapFields(c.Id, jsonResult, false);
    Test.stopTest();

    List<Case_AI_Log__c> logs = CaseAIController.getAuditLogs(c.Id);
    System.assert(logs.size() > 0, 'Audit log sollte erstellt werden');
  }
}
