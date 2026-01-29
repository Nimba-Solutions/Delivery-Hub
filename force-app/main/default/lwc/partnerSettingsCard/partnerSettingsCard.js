import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class PartnerSettingsCard extends LightningElement {
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