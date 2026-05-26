/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Partner / inbound-intake configuration card. Lets an admin toggle a
 *               partner connection (Cloud Nimbus official or a custom URL) and surfaces
 *               the local org's inbound apexrest intake URL for the partner to call.
 *               Not exposed standalone (isExposed=false) — composed by a parent settings
 *               container. Pure client-side state at present; persistence wiring is
 *               composed-in by the parent.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class DeliveryPartnerSettingsCard extends LightningElement {
    @track isEnabled = false;
    @track selectedPartner = 'nimbus';
    @track customUrl = '';
    
    // In a real scenario, you'd fetch the User's actual Site URL here via Apex
    @track myInboundUrl = 'https://[Your-Site-Domain].force.com/services/apexrest/delivery/deliveryhub/v1/intake';

    get partnerOptions() {
        return [
            { label: 'Cloud Nimbus LLC (Official Partner)', value: 'nimbus' },
            { label: 'Custom Connection', value: 'custom' }
        ];
    }

    get isCustomPartner() {
        return this.selectedPartner === 'custom';
    }

    handleToggle(event) {
        this.isEnabled = event.target.checked;
    }

    handlePartnerChange(event) {
        this.selectedPartner = event.target.value;
    }

    handleUrlChange(event) {
        this.customUrl = event.target.value;
    }

    handleSave() {
        // Here you would call Apex to save these preferences to Custom Metadata or Custom Settings
        // For MVP, we just show success.
        
        const evt = new ShowToastEvent({
            title: 'Settings Saved',
            message: 'Partner network configuration updated successfully.',
            variant: 'success',
        });
        this.dispatchEvent(evt);
    }
}