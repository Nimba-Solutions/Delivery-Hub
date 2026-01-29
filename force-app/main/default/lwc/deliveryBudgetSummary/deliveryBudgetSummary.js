import { LightningElement, track } from 'lwc';
import getBudgetMetrics from '@salesforce/apex/DeliveryHubDashboardController.getBudgetMetrics';

export default class DeliveryBudgetSummary extends LightningElement {
    @track metrics = { totalHours: 0, estimatedSpend: 0, activeRequests: 0 };

    connectedCallback() {
        this.loadMetrics();
    }

    async loadMetrics() {
        try {
            const data = await getBudgetMetrics();
            if (data) {
                this.metrics = data;
            }
        } catch (error) {
            console.error('Error loading budget metrics:', error);
        }
    }
}