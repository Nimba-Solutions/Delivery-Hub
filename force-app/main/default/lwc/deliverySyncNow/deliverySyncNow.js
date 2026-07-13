import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import pollUpdates from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubPoller.pollUpdates';

// Auto-refresh cadence while this component is on-screen. The 15-minute
// scheduled poller is the durable safety net; this makes inbound cross-org
// updates (comments, edits, stage changes from connected orgs) feel live
// without waiting for that cron tick.
const AUTO_REFRESH_MS = 30000;

export default class DeliverySyncNow extends LightningElement {
    // Inverted default: auto-refresh is ON unless a page author opts out
    // (LWC boolean @api props cannot default to true — hence the inversion).
    @api disableAutoRefresh = false;

    isSyncing = false;
    lastResult = '';
    _timer;

    connectedCallback() {
        // Pull immediately on load so inbound changes are already there.
        this.runSync(true);
        if (!this.disableAutoRefresh) {
            this._timer = setInterval(() => this.runSync(true), AUTO_REFRESH_MS);
        }
    }

    disconnectedCallback() {
        if (this._timer) {
            clearInterval(this._timer);
            this._timer = undefined;
        }
    }

    get buttonLabel() {
        return this.isSyncing ? 'Syncing…' : 'Sync Now';
    }

    get hasResult() {
        return !!this.lastResult;
    }

    handleClick() {
        // Manual click is never silent — the user asked, so show the result.
        this.runSync(false);
    }

    runSync(silent) {
        if (this.isSyncing) {
            return;
        }
        this.isSyncing = true;
        pollUpdates()
            .then((result) => {
                this.lastResult = result;
                if (!silent) {
                    const ok = typeof result === 'string' && result.indexOf('Success') === 0;
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Cross-Org Sync',
                            message: result,
                            variant: ok ? 'success' : 'warning'
                        })
                    );
                }
            })
            .catch((error) => {
                const msg = (error && error.body && error.body.message) || 'Sync failed';
                this.lastResult = msg;
                if (!silent) {
                    this.dispatchEvent(
                        new ShowToastEvent({ title: 'Cross-Org Sync', message: msg, variant: 'error' })
                    );
                }
            })
            .finally(() => {
                this.isSyncing = false;
            });
    }
}
