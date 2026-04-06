import { LightningElement, api, track } from 'lwc';
import getCardsForPage from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDashboardCardController.getCardsForPage';
import getCardData from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDashboardCardController.getCardData';

export default class DeliveryExecutiveDashboard extends LightningElement {
    @api pageKey = 'home';
    @track cards = [];
    @track isLoading = true;
    @track error = null;

    connectedCallback() {
        this.loadDashboard();
    }

    async loadDashboard() {
        this.isLoading = true;
        this.error = null;
        try {
            const configs = await getCardsForPage({ pageKey: this.pageKey });
            const resolved = await Promise.all(
                configs.map(async (cfg) => {
                    let data = null;
                    let displayValue = '';
                    let statusClass = 'slds-theme_default';
                    try {
                        data = await getCardData({ dataSource: cfg.dataSource, filterJson: cfg.filterJson });
                        if (cfg.cardType === 'Metric') {
                            displayValue = data != null ? String(data) : '0';
                            const num = Number(data);
                            if (cfg.thresholdCritical != null && num >= cfg.thresholdCritical) {
                                statusClass = 'slds-theme_error';
                            } else if (cfg.thresholdWarning != null && num >= cfg.thresholdWarning) {
                                statusClass = 'slds-theme_warning';
                            } else {
                                statusClass = 'slds-theme_success';
                            }
                        }
                    } catch (e) {
                        displayValue = 'Error';
                        statusClass = 'slds-theme_error';
                    }
                    return {
                        ...cfg,
                        data,
                        displayValue,
                        statusClass,
                        isMetric: cfg.cardType === 'Metric',
                        isList: cfg.cardType === 'List',
                        isPieChart: cfg.cardType === 'PieChart',
                        isBarChart: cfg.cardType === 'BarChart',
                        isChart: cfg.cardType === 'PieChart' || cfg.cardType === 'BarChart',
                        sizeClass: 'slds-col slds-size_1-of-1 slds-medium-size_1-of-' + (cfg.cardSize === 'large' ? '1' : cfg.cardSize === 'small' ? '4' : '2') + ' slds-p-around_x-small',
                        chartBars: Array.isArray(data) ? data.map((d, i) => ({
                            key: String(i),
                            label: d.label || '',
                            value: d.value || 0,
                            pct: 0
                        })) : []
                    };
                })
            );
            // Calculate bar chart percentages
            resolved.forEach((card) => {
                if (card.isChart && card.chartBars.length > 0) {
                    const max = Math.max(...card.chartBars.map((b) => b.value), 1);
                    card.chartBars.forEach((b) => {
                        b.pct = Math.round((b.value / max) * 100);
                        b.barStyle = 'width: ' + b.pct + '%; min-width: 2px;';
                    });
                }
            });
            this.cards = resolved;
        } catch (err) {
            this.error = err.body ? err.body.message : err.message;
        } finally {
            this.isLoading = false;
        }
    }

    handleRefresh() {
        this.loadDashboard();
    }

    get hasCards() {
        return this.cards.length > 0;
    }

    get noCardsMessage() {
        return 'No dashboard cards configured for page "' + this.pageKey + '". Add DashboardCard__mdt records to get started.';
    }
}
