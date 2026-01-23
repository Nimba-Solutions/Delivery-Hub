import { LightningElement, wire, track } from 'lwc';
import getBudgetMetrics from '@salesforce/apex/DeliveryHubDashboardController.getBudgetMetrics';

export default class DeliveryBudgetSummary extends LightningElement {
    @track metrics = { totalHours: 0, estimatedSpend: 0, activeRequests: 0 };

    @wire(getBudgetMetrics)
    wiredMetrics({ error, data }) {
        if (data) {
            this.metrics = data;
        }
    }
}