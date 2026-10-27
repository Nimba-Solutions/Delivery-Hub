/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Headless Ghost Recorder: no markup, no shortcut, no panel. Wires
 *               CurrentPageReference into the shared deliveryGhostTracker so
 *               navigation + page duration are logged exactly like the visible
 *               deliveryGhostRecorder. Hosted by the Aura
 *               deliveryGhostRecorderBackground component, which implements
 *               lightning:backgroundUtilityItem (LWC has no background utility
 *               target), so it can sit in any utility bar's background region.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { attach, detach, recordNavigation } from 'c/deliveryGhostTracker';

export default class DeliveryGhostRecorderHeadless extends LightningElement {
    @wire(CurrentPageReference)
    handlePageReference(pageRef) {
        if (pageRef) {
            recordNavigation(this, pageRef);
        }
    }

    connectedCallback() {
        attach(this);
    }

    disconnectedCallback() {
        detach(this);
    }
}
