import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

// Wir referenzieren das Feld als String (Loose Coupling), 
// damit die Komponente auch deploybar ist, wenn das Feld noch nicht existiert.
const SENTIMENT_FIELD = 'Case.AI_Sentiment__c';

export default class CaseSentimentIndicator extends LightningElement {
    @api recordId;

    sentimentValue;
    
    // Wire Service: Holt das Feld automatisch und lauscht auf Updates
    @wire(getRecord, { recordId: '$recordId', fields: [SENTIMENT_FIELD] })
    wiredCase({ error, data }) {
        if (data) {
            this.sentimentValue = getFieldValue(data, SENTIMENT_FIELD);
        } else if (error) {
            // Fehler werden leise behandelt (z.B. wenn Feld nicht existiert oder Zugriff fehlt)
            // console.warn('Sentiment Indicator: Feld AI_Sentiment__c konnte nicht gelesen werden.');
            this.sentimentValue = null;
        }
    }

    // Zeigt einen Platzhaltertext an, wenn das Feld leer ist
    get sentimentDisplay() {
        return this.sentimentValue || 'No sentiment detected yet';
    }

    // Berechnet die CSS-Klasse für den Hintergrund (Farbverläufe)
    get containerClass() {
        const base = 'indicator-container';
        const s = (this.sentimentValue || '').toLowerCase();

        if (s.includes('positive')) return `${base} bg-success`;
        if (s.includes('frustrated')) return `${base} bg-warning`;
        if (s.includes('angry')) return `${base} bg-error`;
        
        return `${base} bg-neutral`; // Standard für Neutral oder Leer
    }

    // Wählt das passende Icon aus der Salesforce Utility Library
    get iconName() {
        const s = (this.sentimentValue || '').toLowerCase();

        if (s.includes('positive')) return 'utility:smiley_and_people';
        if (s.includes('frustrated')) return 'utility:sentiment_neutral'; // Neutrales Gesicht für Frust
        if (s.includes('angry')) return 'utility:sentiment_negative'; // Wütendes Gesicht
        
        return 'utility:chat'; // Standard Sprechblase
    }
}