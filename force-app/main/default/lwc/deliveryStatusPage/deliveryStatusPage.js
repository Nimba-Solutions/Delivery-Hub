/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Public status page LWC for Experience Cloud.
 *               Displays aggregate project health data via a shareable URL.
 *               Only summary data is shown — no internal details exposed.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getStatusPageData from '@salesforce/apex/DeliveryStatusPageController.getStatusPageData';

export default class DeliveryStatusPage extends LightningElement {
    @api entityToken;

    pageData;
    errorMessage;
    isLoading = true;

    @wire(CurrentPageReference)
    handlePageRef(ref) {
        if (ref && ref.state && ref.state.token) {
            this.entityToken = ref.state.token;
        }
    }

    @wire(getStatusPageData, { entityToken: '$resolvedToken' })
    handleData({ error, data }) {
        this.isLoading = false;
        if (data) {
            if (data.error) {
                this.errorMessage = data.error;
                this.pageData = null;
            } else {
                this.pageData = data;
                this.errorMessage = null;
            }
        } else if (error) {
            this.errorMessage = error.body ? error.body.message : 'An error occurred.';
            this.pageData = null;
        }
    }

    get resolvedToken() {
        return this.entityToken || '';
    }

    get hasData() {
        return this.pageData != null && !this.errorMessage;
    }

    get hasError() {
        return this.errorMessage != null;
    }

    get entityName() {
        return this.pageData ? this.pageData.entityName : '';
    }

    get overallHealth() {
        return this.pageData ? this.pageData.overallHealth : '';
    }

    get lastUpdated() {
        return this.pageData ? this.pageData.lastUpdated : '';
    }

    get activeCount() {
        return this.pageData ? this.pageData.activeCount : 0;
    }

    get completedCount() {
        return this.pageData ? this.pageData.completedCount : 0;
    }

    get completionRate() {
        if (!this.pageData) { return '0%'; }
        const total = this.pageData.activeCount + this.pageData.completedCount;
        if (total === 0) { return '0%'; }
        return Math.round((this.pageData.completedCount / total) * 100) + '%';
    }

    get slaOnTrack() {
        return this.pageData && this.pageData.slaHealth ? this.pageData.slaHealth.onTrack : 0;
    }

    get slaAtRisk() {
        return this.pageData && this.pageData.slaHealth ? this.pageData.slaHealth.atRisk : 0;
    }

    get slaBreached() {
        return this.pageData && this.pageData.slaHealth ? this.pageData.slaHealth.breached : 0;
    }

    get recentCompletions() {
        return this.pageData ? this.pageData.recentCompletions : [];
    }

    get hasRecentCompletions() {
        return this.recentCompletions && this.recentCompletions.length > 0;
    }

    get phaseDistribution() {
        return this.pageData ? this.pageData.phaseDistribution : {};
    }

    get planningCount() {
        return this.phaseDistribution.Planning || 0;
    }

    get developmentCount() {
        return this.phaseDistribution.Development || 0;
    }

    get testingCount() {
        return this.phaseDistribution.Testing || 0;
    }

    get uatCount() {
        return this.phaseDistribution.UAT || 0;
    }

    get deploymentCount() {
        return this.phaseDistribution.Deployment || 0;
    }

    get phaseTotal() {
        return this.planningCount + this.developmentCount + this.testingCount
            + this.uatCount + this.deploymentCount;
    }

    get hasPhaseData() {
        return this.phaseTotal > 0;
    }

    get planningStyle() {
        return this.phaseTotal > 0 ? `width: ${Math.max((this.planningCount / this.phaseTotal) * 100, 5)}%` : 'width: 0';
    }

    get developmentStyle() {
        return this.phaseTotal > 0 ? `width: ${Math.max((this.developmentCount / this.phaseTotal) * 100, 5)}%` : 'width: 0';
    }

    get testingStyle() {
        return this.phaseTotal > 0 ? `width: ${Math.max((this.testingCount / this.phaseTotal) * 100, 5)}%` : 'width: 0';
    }

    get uatStyle() {
        return this.phaseTotal > 0 ? `width: ${Math.max((this.uatCount / this.phaseTotal) * 100, 5)}%` : 'width: 0';
    }

    get deploymentStyle() {
        return this.phaseTotal > 0 ? `width: ${Math.max((this.deploymentCount / this.phaseTotal) * 100, 5)}%` : 'width: 0';
    }

    get healthBadgeClass() {
        const h = this.overallHealth;
        if (h === 'Healthy') { return 'health-badge health-healthy'; }
        if (h === 'At Risk') { return 'health-badge health-at-risk'; }
        if (h === 'Critical') { return 'health-badge health-critical'; }
        return 'health-badge';
    }

    get healthDotClass() {
        const h = this.overallHealth;
        if (h === 'Healthy') { return 'health-dot dot-green'; }
        if (h === 'At Risk') { return 'health-dot dot-yellow'; }
        if (h === 'Critical') { return 'health-dot dot-red'; }
        return 'health-dot';
    }
}
