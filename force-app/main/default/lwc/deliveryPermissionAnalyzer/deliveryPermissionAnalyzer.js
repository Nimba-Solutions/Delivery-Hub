import { LightningElement, track } from 'lwc';
import getPermissionAnalysis from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryPermissionAnalyzerController.getPermissionAnalysis';
import getUserDetail from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryPermissionAnalyzerController.getUserDetail';

export default class DeliveryPermissionAnalyzer extends LightningElement {
    @track analysis = null;
    @track isLoading = true;
    @track error = null;
    @track selectedUserId = null;
    @track userDetail = null;
    @track isLoadingDetail = false;
    @track viewMode = 'summary';

    connectedCallback() {
        this.loadAnalysis();
    }

    loadAnalysis() {
        this.isLoading = true;
        this.error = null;
        getPermissionAnalysis()
            .then((result) => {
                this.analysis = {
                    ...result,
                    users: result.users.map((u) => ({
                        ...u,
                        riskClass:
                            u.riskLevel === 'High'
                                ? 'slds-badge_inverse'
                                : u.riskLevel === 'Medium'
                                  ? 'slds-theme_warning'
                                  : ''
                    }))
                };
            })
            .catch((err) => {
                this.error = err.body?.message || err.message || 'An error occurred';
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleUserClick(event) {
        const userId = event.currentTarget.dataset.userid;
        this.selectedUserId = userId;
        this.isLoadingDetail = true;
        this.viewMode = 'detail';
        this.userDetail = null;
        getUserDetail({ userId })
            .then((result) => {
                this.userDetail = result;
            })
            .catch((err) => {
                this.error = err.body?.message || err.message || 'An error occurred';
                this.viewMode = 'summary';
            })
            .finally(() => {
                this.isLoadingDetail = false;
            });
    }

    handleBackToSummary() {
        this.selectedUserId = null;
        this.userDetail = null;
        this.viewMode = 'summary';
    }

    handleRefresh() {
        this.loadAnalysis();
    }

    get hasData() {
        return this.analysis != null;
    }

    get isSummaryView() {
        return this.viewMode === 'summary';
    }

    get isDetailView() {
        return this.viewMode === 'detail';
    }

    get showSummary() {
        return !this.isLoading && !this.error && this.analysis && this.viewMode === 'summary';
    }

    get showDetail() {
        return !this.isLoading && this.viewMode === 'detail';
    }

    get objectCount() {
        return this.analysis?.objects?.length || 0;
    }

    get hasRecommendations() {
        return this.analysis?.recommendations?.length > 0;
    }

    get riskBadgeClass() {
        if (!this.userDetail) {
            return '';
        }
        if (this.userDetail.riskLevel === 'High') {
            return 'slds-badge_inverse';
        }
        if (this.userDetail.riskLevel === 'Medium') {
            return 'slds-theme_warning';
        }
        return '';
    }

    get hasDailyActivity() {
        return this.userDetail?.dailyActivity?.length > 0;
    }

    get dailyActivityBars() {
        const data = this.userDetail?.dailyActivity;
        if (!data || data.length === 0) {
            return [];
        }
        const maxCount = Math.max(...data.map((d) => d.count), 1);
        return data.map((d) => {
            const pct = Math.round((d.count / maxCount) * 100);
            const label = d.dateLabel.substring(5);
            return {
                key: d.dateLabel,
                label,
                count: d.count,
                barStyle: 'height: ' + pct + '%',
                hasActivity: d.count > 0
            };
        });
    }
}
