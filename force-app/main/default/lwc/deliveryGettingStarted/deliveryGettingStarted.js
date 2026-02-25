import { LightningElement, track } from 'lwc';

export default class DeliveryGettingStarted extends LightningElement {
    @track isExpanded = false;

    get rootClass() {
        return 'gs-root' + (this.isExpanded ? ' gs-root--expanded' : '');
    }

    get chevronIcon() {
        return this.isExpanded ? 'utility:chevronup' : 'utility:chevrondown';
    }

    handleToggle() {
        this.isExpanded = !this.isExpanded;
    }

    handleKeydown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.handleToggle();
        }
    }
}
