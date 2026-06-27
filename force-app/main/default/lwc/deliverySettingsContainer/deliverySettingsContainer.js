/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Top-level Application Settings container with a three-tab interface —
 *               General (deliveryGeneralSettingsCard), AI Features (deliveryAiSettingsCard),
 *               and OpenAI (deliveryOpenAiSettingsCard). Mounts on AppPage / HomePage /
 *               RecordPage / Tab. Pure layout — each child card owns its own
 *               DeliveryHubSettings__c read/write lifecycle.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, track } from 'lwc';

export default class DeliverySettingsContainer extends LightningElement {
    @track activeTab = 'general';

    get tabOptions() {
        return [
            { label: 'General', value: 'general' },
            { label: 'AI Features', value: 'ai' },
            { label: 'OpenAI', value: 'openai' },
            { label: 'Home Visibility', value: 'homeVisibility' },
            { label: 'Delivery Visibility', value: 'deliveryVisibility' }
        ];
    }

    get isGeneralActive() {
        return this.activeTab === 'general';
    }

    get isAiActive() {
        return this.activeTab === 'ai';
    }

    get isOpenaiActive() {
        return this.activeTab === 'openai';
    }

    get isHomeVisibilityActive() {
        return this.activeTab === 'homeVisibility';
    }

    get isDeliveryVisibilityActive() {
        return this.activeTab === 'deliveryVisibility';
    }

    handleTabChange(event) {
        this.activeTab = event.target.value;
    }
}