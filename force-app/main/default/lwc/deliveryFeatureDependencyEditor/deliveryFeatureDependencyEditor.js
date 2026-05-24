/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Inline FeatureDependency__c editor for the Feature__c record page.
 *               Closes the Flow 5 gap from docs/audits/e2e-walkthrough-2026-05-21.md
 *               — admins can now add and remove dependencies without leaving the
 *               parent Feature record (no Data Loader / direct record-page New
 *               required).
 *
 *               Two sections:
 *                 1. Existing dependencies — lightning-datatable bound to
 *                    DeliveryFeatureDepEditorController.getDependencies,
 *                    one row per FeatureDependency__c that has THIS feature as
 *                    the BlockedFeatureLookup__c (i.e. the things this feature
 *                    depends on). Delete is the only inline row action.
 *                 2. Add new — lightning-record-picker (Feature__c, excludes
 *                    the current recordId), lightning-combobox for type, and a
 *                    lightning-textarea for notes. Add button is reactively
 *                    disabled until child + type are both set, and refuses
 *                    child == recordId in addition to the Apex-side guard.
 *
 *               No ternaries in the template (LWC v62 limitation per CLAUDE.md).
 *               No @api boolean defaulting to true (LWC1503).
 *               Admin gate is enforced server-side by the controller — non-admins
 *               see the read-only datatable + a disabled Add form (the controller
 *               will refuse the call too, but disabling at the UI is friendlier).
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDependencies from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureDepEditorController.getDependencies';
import createDependency from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureDepEditorController.createDependency';
import deleteDependency from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureDepEditorController.deleteDependency';
import isAdminApex from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureCatalogController.isAdmin';

const TYPE_OPTIONS = [
    { label: 'Hard (must be enabled first)', value: 'Hard' },
    { label: 'Soft (strongly recommended)', value: 'Soft' },
    { label: 'Optional (informational only)', value: 'Optional' }
];

const EMPTY = 0;

export default class DeliveryFeatureDependencyEditor extends LightningElement {
    /** Feature__c record id this editor is mounted on (the parent / blocked side). */
    @api recordId;

    @track dependencyRows = [];
    @track isLoaded = false;
    @track errorMessage = '';
    @track isAdminUser = false;
    @track isSaving = false;
    @track isConfirmDeleteOpen = false;
    @track pendingDeleteId = null;
    @track pendingDeleteLabel = '';

    @track selectedChildId = null;
    @track selectedType = 'Hard';
    @track notesValue = '';

    wiredDependenciesResult;

    /** lightning-datatable columns — name link + type + notes + delete action. */
    columns = [
        {
            label: 'Dependency',
            fieldName: 'recordUrl',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'childName' },
                target: '_self'
            }
        },
        { label: 'Type', fieldName: 'depType', initialWidth: 110 },
        { label: 'Notes', fieldName: 'notes', wrapText: true },
        {
            type: 'action',
            typeAttributes: {
                rowActions: [{ label: 'Delete', name: 'delete', iconName: 'utility:delete' }]
            }
        }
    ];

    typeOptions = TYPE_OPTIONS;

    // ── Lifecycle / wires ──────────────────────────────────────────────

    @wire(isAdminApex)
    wiredIsAdmin({ data }) {
        if (data === true) {
            this.isAdminUser = true;
        } else {
            this.isAdminUser = false;
        }
    }

    @wire(getDependencies, { parentFeatureId: '$recordId' })
    wiredDependencies(result) {
        this.wiredDependenciesResult = result;
        if (result.data) {
            this.dependencyRows = (result.data || []).map((row) => this.toRow(row));
            this.errorMessage = '';
            this.isLoaded = true;
        } else if (result.error) {
            this.errorMessage = this.extractErrorMessage(result.error);
            this.dependencyRows = [];
            this.isLoaded = true;
        }
    }

    toRow(dep) {
        const childName = (dep.BlockingFeatureLookup__r && dep.BlockingFeatureLookup__r.Name)
            ? dep.BlockingFeatureLookup__r.Name
            : dep.BlockingFeatureLookup__c;
        return {
            id: dep.Id,
            childName,
            childId: dep.BlockingFeatureLookup__c,
            recordUrl: '/' + dep.BlockingFeatureLookup__c,
            depType: dep.TypePk__c || '',
            notes: dep.NotesTxt__c || ''
        };
    }

    extractErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        return 'Unable to load feature dependencies.';
    }

    // ── Computed properties ────────────────────────────────────────────

    get hasError() {
        return !!this.errorMessage;
    }

    get hasRows() {
        return this.dependencyRows && this.dependencyRows.length > EMPTY;
    }

    get isEmpty() {
        return this.isLoaded && !this.hasError && !this.hasRows;
    }

    /**
     * Feature__c lookup filter — excludes the current Feature record from the
     * picker (self-edges are nonsensical; the Apex guard will refuse too).
     */
    get childPickerFilter() {
        if (!this.recordId) {
            return null;
        }
        return {
            criteria: [
                { fieldPath: 'Id', operator: 'ne', value: this.recordId }
            ]
        };
    }

    get childPickerMatchingInfo() {
        return {
            primaryField: { fieldPath: 'Name' }
        };
    }

    get childPickerDisplayInfo() {
        return {
            primaryField: 'Name'
        };
    }

    get addDisabled() {
        if (!this.isAdminUser) {
            return true;
        }
        if (this.isSaving) {
            return true;
        }
        if (!this.selectedChildId) {
            return true;
        }
        if (!this.selectedType) {
            return true;
        }
        if (this.selectedChildId === this.recordId) {
            return true;
        }
        return false;
    }

    get formDisabled() {
        return !this.isAdminUser || this.isSaving;
    }

    get adminGateMessage() {
        if (this.isAdminUser) {
            return '';
        }
        return 'Only Delivery Hub admins can add or remove feature dependencies.';
    }

    get showAdminGateNotice() {
        return this.isLoaded && !this.isAdminUser;
    }

    get pendingDeletePromptText() {
        if (this.pendingDeleteLabel) {
            return `Remove dependency on "${this.pendingDeleteLabel}"?`;
        }
        return 'Remove this dependency?';
    }

    // ── Event handlers — add form ──────────────────────────────────────

    handleChildChange(event) {
        const next = event.detail && event.detail.recordId;
        this.selectedChildId = next || null;
    }

    handleTypeChange(event) {
        this.selectedType = event.detail.value;
    }

    handleNotesChange(event) {
        this.notesValue = event.detail.value;
    }

    handleAdd() {
        if (this.addDisabled) {
            return;
        }
        this.isSaving = true;
        createDependency({
            parentFeatureId: this.recordId,
            childFeatureId: this.selectedChildId,
            depType: this.selectedType,
            notes: this.notesValue
        })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Dependency added',
                    variant: 'success'
                }));
                this.resetForm();
                if (this.wiredDependenciesResult) {
                    return refreshApex(this.wiredDependenciesResult);
                }
                return null;
            })
            .catch((err) => {
                const msg = (err && err.body && err.body.message)
                    ? err.body.message
                    : 'Unable to add dependency.';
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Add failed',
                    message: msg,
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    resetForm() {
        this.selectedChildId = null;
        this.selectedType = 'Hard';
        this.notesValue = '';
        const picker = this.template.querySelector('lightning-record-picker');
        if (picker) {
            picker.clearSelection();
        }
    }

    // ── Event handlers — datatable row action ──────────────────────────

    handleRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;
        if (action !== 'delete') {
            return;
        }
        if (!this.isAdminUser) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Admin required',
                message: 'Only admins can remove dependencies.',
                variant: 'warning'
            }));
            return;
        }
        this.pendingDeleteId = row.id;
        this.pendingDeleteLabel = row.childName || '';
        this.isConfirmDeleteOpen = true;
    }

    handleConfirmDelete() {
        if (!this.pendingDeleteId) {
            this.handleCancelDelete();
            return;
        }
        const idToDelete = this.pendingDeleteId;
        this.isConfirmDeleteOpen = false;
        this.isSaving = true;
        deleteDependency({ dependencyId: idToDelete })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Dependency removed',
                    variant: 'success'
                }));
                this.pendingDeleteId = null;
                this.pendingDeleteLabel = '';
                if (this.wiredDependenciesResult) {
                    return refreshApex(this.wiredDependenciesResult);
                }
                return null;
            })
            .catch((err) => {
                const msg = (err && err.body && err.body.message)
                    ? err.body.message
                    : 'Unable to remove dependency.';
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Delete failed',
                    message: msg,
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    handleCancelDelete() {
        this.isConfirmDeleteOpen = false;
        this.pendingDeleteId = null;
        this.pendingDeleteLabel = '';
    }
}
