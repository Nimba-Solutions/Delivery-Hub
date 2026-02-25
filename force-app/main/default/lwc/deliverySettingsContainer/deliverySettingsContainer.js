/**
 * @author Cloud Nimbus LLC
 */
import { LightningElement, track } from 'lwc';

export default class DeliverySettingsContainer extends LightningElement {
    @track activeTab = 'general';

    get tabOptions() {
        return [
            { label: 'General', value: 'general' },
            { label: 'AI Features', value: 'ai' },
            { label: 'OpenAI', value: 'openai' }
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

    handleTabChange(event) {
        this.activeTab = event.target.value;
    }
}