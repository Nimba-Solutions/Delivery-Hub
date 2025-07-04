import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class DragAndDropCard extends NavigationMixin(LightningElement) {
    @api stage;
    @api record;
    @api sizeMode;

    // Use custom picklist field instead of StageName
    get isSameStage() {
        return this.record.StageNamePk__c === this.stage;
    }

    // Dispatch drag event
    itemDragStart() {
        this.dispatchEvent(new CustomEvent('itemdrag', {
            detail: this.record.Id
        }));
    }

    // Card size logic (optional based on sizeMode)
    get cardStyle() {
        if (this.sizeMode === 'ticketSize') {
            const size = this.record.DeveloperDaysSizeNumber__c || 0;
            // Scale height by 20px per day (adjust as needed)
            const height = size * 20;
            return `height: ${height}px;`;
        }
        return 'height: 100px;';
    }
}