import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation'
export default class DragAndDropCard extends NavigationMixin(LightningElement) {
    @api stage
    @api record
    @api sizeMode

    get isSameStage(){
        return this.stage === this.record.StageName
    }

    navigateOppHandler(event){
        event.preventDefault()
        this.navigateHandler(event.target.dataset.id, 'Opportunity')
    }

    navigateAccHandler(event){
        event.preventDefault()
        this.navigateHandler(event.target.dataset.id, 'Account')
    }

    navigateHandler(Id, apiName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: Id,
                objectApiName: apiName,
                actionName: 'view',
            },
        });
    }

    itemDragStart(){
        const event = new CustomEvent('itemdrag', {
            detail: this.record.Id
        })
        this.dispatchEvent(event)
    }

    get cardStyle() {
        if (this.sizeMode === 'Ticket Size') {
            const val = this.record.Amount || 0;
            const height = val / 100;
            return `height: ${height}px;`;
        }
        return 'height: 100px;';
    }

}