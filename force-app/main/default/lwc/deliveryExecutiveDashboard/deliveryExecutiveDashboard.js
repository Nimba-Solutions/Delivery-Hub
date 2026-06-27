/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  CMT-driven Executive Dashboard — renders dashboard cards configured in
 *               DashboardCard__mdt for a given @api pageKey (default "home", matches
 *               DashboardCard__mdt.PageKeyTxt__c). Each card pulls its display value via
 *               DeliveryDashboardCardController.getCardData and supports threshold-based
 *               critical / warning color states. Mounts on HomePage / AppPage / RecordPage.
 *               Pure read view — admins author cards as Custom Metadata.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import WORK_ITEM_OBJECT from '@salesforce/schema/WorkItem__c';
import getCardsForPage from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDashboardCardController.getCardsForPage';
import getCardData from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDashboardCardController.getCardData';
import getHiddenHomeComponents from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHomeVisibilityController.getHiddenHomeComponents';

// This component's key in the Home-visibility map (matches its LWC folder name).
const HOME_COMPONENT_KEY = 'deliveryExecutiveDashboard';

export default class DeliveryExecutiveDashboard extends LightningElement {
    @api pageKey = 'home';
    @track cards = [];
    @track isLoading = true;
    @track error = null;

    // ── Home-page visibility (admin-toggleable, default = shown) ──
    // Hides ONLY on the Delivery Hub app Home page when an admin toggles it
    // off in Settings. Everywhere else this component always renders.
    @wire(CurrentPageReference) _homePageRef;
    @wire(getHiddenHomeComponents) _hiddenHomeComponents;

    get isOnHomePage() {
        const ref = this._homePageRef;
        if (!ref) {
            return false;
        }
        const attrs = ref.attributes || {};
        if (ref.type === 'standard__namedPage' && attrs.pageName === 'home') {
            return true;
        }
        const url = attrs.url
            || (typeof window !== 'undefined' && window.location ? window.location.pathname : '');
        return typeof url === 'string' && url.indexOf('/lightning/page/home') !== -1;
    }

    get isHiddenOnHome() {
        if (!this.isOnHomePage) {
            return false;
        }
        const map = this._hiddenHomeComponents && this._hiddenHomeComponents.data;
        return !!(map && map[HOME_COMPONENT_KEY] === true);
    }

    get isNotHiddenOnHome() {
        return !this.isHiddenOnHome;
    }

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
                    let metricClass = 'dh-metric';
                    try {
                        data = await getCardData({ dataSource: cfg.dataSource, filterJson: cfg.filterJson });
                        if (cfg.cardType === 'Metric') {
                            displayValue = data != null ? String(data) : '0';
                            const num = Number(data);
                            if (cfg.thresholdCritical != null && num >= cfg.thresholdCritical) {
                                metricClass = 'dh-metric dh-metric--danger';
                            } else if (cfg.thresholdWarning != null && num >= cfg.thresholdWarning) {
                                metricClass = 'dh-metric dh-metric--warning';
                            } else {
                                metricClass = 'dh-metric dh-metric--success';
                            }
                        }
                    } catch (e) {
                        displayValue = 'Error';
                        metricClass = 'dh-metric dh-metric--danger';
                    }
                    const isPills = cfg.cardType === 'Pills';
                    const isChart = cfg.cardType === 'PieChart' || cfg.cardType === 'BarChart';
                    return {
                        ...cfg,
                        data,
                        displayValue,
                        metricClass,
                        isMetric: cfg.cardType === 'Metric',
                        isList: cfg.cardType === 'List',
                        isPieChart: cfg.cardType === 'PieChart',
                        isBarChart: cfg.cardType === 'BarChart',
                        isChart,
                        isPills,
                        hasClickThrough: !!cfg.clickThroughUrl,
                        hasInfoPopover: !!cfg.infoPopover,
                        infoPopoverOpen: false,
                        cardClass: this.buildCardClass(cfg.clickThroughUrl),
                        sizeClass: 'slds-col slds-size_1-of-1 slds-medium-size_1-of-' + (cfg.cardSize === 'large' ? '1' : cfg.cardSize === 'small' ? '4' : '2') + ' slds-p-around_x-small',
                        chartBars: Array.isArray(data) ? data.map((d, i) => ({
                            key: String(i),
                            label: d.label || '',
                            value: d.value || 0,
                            pct: 0
                        })) : [],
                        pills: isPills && Array.isArray(data) ? data.map((row, i) => ({
                            key: row.id || String(i),
                            id: row.id,
                            label: row.label,
                            estimated: row.estimated,
                            logged: row.logged,
                            budgetLabel: row.budgetLabel,
                            scheduleLabel: row.scheduleLabel,
                            budgetPillClass: 'dh-pill dh-pill--' + (row.budgetClass || 'neutral'),
                            schedulePillClass: 'dh-pill dh-pill--' + (row.scheduleClass || 'neutral'),
                            recordUrl: row.id ? '/lightning/r/' + this.workItemApiName() + '/' + row.id + '/view' : null
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

    handleCardClick(event) {
        // Cards are made clickable when DashboardCard__mdt.ClickThroughUrlTxt__c
        // is populated. Opens in a new tab so the user keeps the dashboard
        // context and can compare side-by-side.
        const url = event.currentTarget.dataset.url;
        if (url) {
            window.open(url, '_blank', 'noopener,noreferrer');
        }
    }

    handleInfoToggle(event) {
        // Clicking the ⓘ icon toggles the popover for THIS card only.
        // Stop propagation so the click-through-url handler on the card doesn't
        // also fire (info button is nested inside a clickable card).
        event.stopPropagation();
        event.preventDefault();
        const cardKey = event.currentTarget.dataset.key;
        this.cards = this.cards.map((c) => ({
            ...c,
            infoPopoverOpen: c.key === cardKey ? !c.infoPopoverOpen : false
        }));
    }

    handlePillClick(event) {
        // Pill rows in a Pills-type card are individually clickable —
        // navigate to the underlying WorkItem record.
        event.stopPropagation();
        const url = event.currentTarget.dataset.url;
        if (url) {
            window.open(url, '_blank', 'noopener,noreferrer');
        }
    }

    buildCardClass(clickThroughUrl) {
        return clickThroughUrl ? 'dh-hero-card dh-hero-card--clickable' : 'dh-hero-card';
    }

    workItemApiName() {
        // Namespace-safe object API name resolved via @salesforce/schema import;
        // resolves correctly on managed (delivery__) and unmanaged installs alike.
        return WORK_ITEM_OBJECT.objectApiName;
    }

    get hasCards() {
        return this.cards.length > 0;
    }

    get noCardsMessage() {
        return 'No dashboard cards configured for page "' + this.pageKey + '". Add DashboardCard__mdt records to get started.';
    }
}
