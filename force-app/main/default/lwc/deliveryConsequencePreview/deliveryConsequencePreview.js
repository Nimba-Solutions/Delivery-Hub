/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Shared "consequence preview" helper for the admin Settings cards.
 *               When an admin flips a consequential toggle (one that emits
 *               email / bell / Slack / external webhook traffic or incurs AI
 *               cost) to ON, the card calls confirmConsequence() to show a plain-
 *               English confirm dialog explaining exactly what will happen, who is
 *               affected, and any cost — BEFORE the change commits. The copy is
 *               sourced from a single maintainable Apex method
 *               (DeliveryHubSettingsController.getConsequencePreviews), keyed by
 *               DeliveryHubSettings__c field API name. P1 of the "safe by default,
 *               explain before you commit" install-experience initiative.
 * @author       Cloud Nimbus LLC
 */
import LightningConfirm from 'lightning/confirm';
import getConsequencePreviews from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSettingsController.getConsequencePreviews';

// Cache the preview map across calls (it is static, cacheable copy).
let cachedPreviews;

/**
 * Loads (and memoizes) the consequence-preview map keyed by field API name.
 * @returns {Promise<Object>} map of fieldApiName -> {title, whatHappens, whoIsAffected, cost}
 */
async function loadPreviews() {
    if (!cachedPreviews) {
        cachedPreviews = await getConsequencePreviews();
    }
    return cachedPreviews;
}

/**
 * Builds the multi-line confirm message body for a single preview.
 * @param {Object} preview the ConsequencePreview entry
 * @returns {string} plain-text message
 */
function buildMessage(preview) {
    const lines = [
        preview.whatHappens,
        '',
        'Who is affected: ' + preview.whoIsAffected
    ];
    if (preview.cost) {
        lines.push('');
        lines.push('Cost: ' + preview.cost);
    }
    return lines.join('\n');
}

/**
 * Shows a consequence-preview confirm dialog for the given setting field.
 * Resolves true if the admin confirms (commit), false if they cancel (revert).
 * If no preview copy exists for the field, resolves true (nothing to warn about).
 *
 * @param {string} fieldApiName DeliveryHubSettings__c field API name (e.g. 'EnableEmailNotificationsDateTime__c')
 * @returns {Promise<boolean>} whether the admin confirmed the enable
 */
export async function confirmConsequence(fieldApiName) {
    let preview;
    try {
        const previews = await loadPreviews();
        preview = previews && previews[fieldApiName];
    } catch (error) {
        // If we cannot load copy, fail safe by NOT blocking the toggle.
        return true;
    }

    if (!preview) {
        return true;
    }

    return LightningConfirm.open({
        message: buildMessage(preview),
        variant: 'header',
        theme: 'warning',
        label: preview.title
    });
}
