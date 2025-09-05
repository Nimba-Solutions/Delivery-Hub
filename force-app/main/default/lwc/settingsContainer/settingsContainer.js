import { LightningElement, track } from 'lwc';

export default class SettingsContainer extends LightningElement {
    @track activeTab = 'general';

    get tabOptions() {
        return [
            { label: 'General', value: 'general' },
            { label: 'AI Features', value: 'ai' },
            { label: 'OpenAI', value: 'openai' },
            { label: 'JIRA Integration', value: 'jira' }
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

    get isJiraActive() {
        return this.activeTab === 'jira';
    }

    handleTabChange(event) {
        this.activeTab = event.target.value;
    }
}