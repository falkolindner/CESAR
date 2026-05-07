/**
 * @description Trigger auf EmailMessage, um bei neuen eingehenden E-Mails 
 * die Logik für Agentforce vorzubereiten (z.B. Benachrichtigung oder Flagging).
 */
trigger CaseEmailTrigger on EmailMessage (after insert) {
    for (EmailMessage em : Trigger.new) {
        // Nur bei eingehenden E-Mails, die an einem Case hängen
        if (em.Incoming && em.ParentId != null && em.ParentId.getSObjectType() == Case.SObjectType) {
            // Hier könnte man ein Platform Event feuern, um die LWC in Echtzeit zu refreshen
            System.debug('Neue E-Mail für Case erhalten: ' + em.ParentId);
        }
    }
}