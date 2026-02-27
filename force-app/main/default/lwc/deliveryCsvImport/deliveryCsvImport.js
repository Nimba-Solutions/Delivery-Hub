/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  CSV Import tool with Jira auto-detection for bulk-creating
 *               WorkItem__c records.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import importWorkItems from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryCsvImportController.importWorkItems';
import getWorkItemFields from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryCsvImportController.getWorkItemFields';

// ── Jira column-to-field mapping ─────────────────────────────────
const JIRA_COLUMN_MAP = {
    'summary':     'BriefDescriptionTxt__c',
    'description': 'DetailsTxt__c',
    'priority':    'PriorityPk__c',
    'status':      'StageNamePk__c',
    'issue type':  'RequestTypePk__c',
    'labels':      'Tags__c',
    'epic link':   'Epic__c',
    'epic name':   'Epic__c',
    'story points':'DeveloperDaysSizeNumber__c'
};

// Jira priority → WorkItem priority
const JIRA_PRIORITY_MAP = {
    'highest':  'High',
    'high':     'High',
    'medium':   'Medium',
    'low':      'Low',
    'lowest':   'Low'
};

// Jira status → WorkItem stage (common defaults)
const JIRA_STATUS_MAP = {
    'to do':            'Backlog',
    'open':             'Backlog',
    'backlog':          'Backlog',
    'selected for development': 'Ready for Development',
    'in progress':      'In Development',
    'in development':   'In Development',
    'in review':        'Ready for Scratch Test',
    'code review':      'Ready for Scratch Test',
    'in testing':       'QA In Progress',
    'qa':               'QA In Progress',
    'ready for qa':     'Ready for QA',
    'done':             'Done',
    'closed':           'Done',
    'resolved':         'Done',
    'cancelled':        'Cancelled',
    'won\'t do':        'Cancelled',
    'blocked':          'Dev Blocked',
    'waiting':          'Clarification Requested (Pre-Dev)',
    'ready for review': 'Ready for Tech Review',
    'review':           'Tech Reviewing',
    'deployed':         'Deployed to Prod',
    'released':         'Deployed to Prod'
};

// Jira issue type → WorkItem request type
const JIRA_ISSUE_TYPE_MAP = {
    'bug':          'Internal',
    'story':        'Internal',
    'task':         'Internal',
    'sub-task':     'Internal',
    'epic':         'Internal',
    'improvement':  'Internal',
    'new feature':  'Internal'
};

const JIRA_DETECTION_COLUMNS = ['issue type', 'summary', 'status', 'priority'];
const MAX_PREVIEW_ROWS = 5;

export default class DeliveryCsvImport extends NavigationMixin(LightningElement) {
    // ── State ────────────────────────────────────────────────────────
    @track step = 'upload';       // upload | mapping | preview | importing | results
    @track fileName = '';
    @track csvHeaders = [];
    @track csvRows = [];
    @track columnMappings = [];   // { csvColumn, targetField }
    @track isJiraDetected = false;
    @track availableFields = [];
    @track importProgress = 0;
    @track importTotal = 0;
    @track importResult = null;   // { successCount, errorCount, errors, createdIds }
    @track isDragOver = false;
    @track parseError = '';

    _fieldOptions = [];

    // ── Wire: fetch WorkItem__c fields ───────────────────────────────
    @wire(getWorkItemFields)
    wiredFields({ data, error }) {
        if (data) {
            this.availableFields = data;
            this._fieldOptions = [
                { label: '-- Skip this column --', value: '' },
                ...data.map(f => ({
                    label: `${f.label} (${f.apiName})`,
                    value: f.apiName
                }))
            ];
        }
        if (error) {
            console.error('Failed to load WorkItem fields', error);
        }
    }

    // ── Computed getters ─────────────────────────────────────────────
    get isUploadStep()    { return this.step === 'upload'; }
    get isMappingStep()   { return this.step === 'mapping'; }
    get isPreviewStep()   { return this.step === 'preview'; }
    get isImportingStep() { return this.step === 'importing'; }
    get isResultsStep()   { return this.step === 'results'; }

    get dropZoneClass() {
        return 'drop-zone slds-box slds-theme_shade slds-text-align_center' +
            (this.isDragOver ? ' drop-zone-active' : '');
    }

    get fieldOptions() {
        return this._fieldOptions;
    }

    get previewRows() {
        return this.csvRows.slice(0, MAX_PREVIEW_ROWS);
    }

    get previewColumns() {
        return this.columnMappings
            .filter(m => m.targetField)
            .map(m => ({
                label: `${m.csvColumn} -> ${m.targetField}`,
                fieldName: m.csvColumn,
                type: 'text'
            }));
    }

    get previewData() {
        const mapped = this.columnMappings.filter(m => m.targetField);
        return this.previewRows.map((row, idx) => {
            const obj = { _rowKey: String(idx) };
            for (const m of mapped) {
                obj[m.csvColumn] = row[m.csvColumn] || '';
            }
            return obj;
        });
    }

    get totalRows() {
        return this.csvRows.length;
    }

    get mappedColumnCount() {
        return this.columnMappings.filter(m => m.targetField).length;
    }

    get hasMappedColumns() {
        return this.mappedColumnCount > 0;
    }

    get progressPercent() {
        return this.importTotal > 0
            ? Math.round((this.importProgress / this.importTotal) * 100)
            : 0;
    }

    get hasErrors() {
        return this.importResult && this.importResult.errorCount > 0;
    }

    get resultErrors() {
        return this.importResult ? this.importResult.errors : [];
    }

    get resultSuccessCount() {
        return this.importResult ? this.importResult.successCount : 0;
    }

    get resultErrorCount() {
        return this.importResult ? this.importResult.errorCount : 0;
    }

    get summaryMessage() {
        if (!this.importResult) return '';
        const s = this.importResult.successCount;
        const e = this.importResult.errorCount;
        if (e === 0) {
            return `All ${s} work item${s !== 1 ? 's' : ''} imported successfully.`;
        }
        return `${s} imported, ${e} failed.`;
    }

    get isAllSuccess() {
        return this.importResult && this.importResult.errorCount === 0 &&
               this.importResult.successCount > 0;
    }

    get importButtonLabel() {
        return `Import ${this.totalRows} Work Item${this.totalRows !== 1 ? 's' : ''}`;
    }

    get resultBannerClass() {
        return 'result-banner slds-grid slds-grid_vertical-align-center slds-p-around_medium slds-m-bottom_small ' +
            (this.isAllSuccess ? 'result-banner-success' : 'result-banner-warning');
    }

    get resultIconName() {
        return this.isAllSuccess ? 'utility:success' : 'utility:warning';
    }

    // ── Drag & Drop handlers ─────────────────────────────────────────
    handleDragOver(event) {
        event.preventDefault();
        this.isDragOver = true;
    }

    handleDragLeave() {
        this.isDragOver = false;
    }

    handleDrop(event) {
        event.preventDefault();
        this.isDragOver = false;
        const files = event.dataTransfer.files;
        if (files.length > 0) {
            this.processFile(files[0]);
        }
    }

    handleFileChange(event) {
        const files = event.target.files;
        if (files.length > 0) {
            this.processFile(files[0]);
        }
    }

    handleFilePick() {
        this.template.querySelector('input[type="file"]').click();
    }

    // ── CSV parsing ──────────────────────────────────────────────────
    processFile(file) {
        if (!file.name.toLowerCase().endsWith('.csv')) {
            this.parseError = 'Please select a .csv file.';
            return;
        }
        this.parseError = '';
        this.fileName = file.name;

        const reader = new FileReader();
        reader.onload = (e) => {
            try {
                const text = e.target.result;
                this.parseCsv(text);
            } catch (err) {
                this.parseError = 'Failed to parse CSV: ' + err.message;
            }
        };
        reader.onerror = () => {
            this.parseError = 'Failed to read the file.';
        };
        reader.readAsText(file);
    }

    parseCsv(text) {
        // Auto-detect delimiter from the first line
        const delimiter = this.detectDelimiter(text);
        const rows = this.parseCsvText(text, delimiter);

        if (rows.length < 2) {
            this.parseError = 'CSV must have a header row and at least one data row.';
            return;
        }

        const headers = rows[0];
        const dataRows = [];

        for (let i = 1; i < rows.length; i++) {
            if (rows[i].length === 0 || (rows[i].length === 1 && rows[i][0].trim() === '')) {
                continue; // skip empty rows
            }
            const obj = {};
            for (let j = 0; j < headers.length; j++) {
                obj[headers[j]] = j < rows[i].length ? rows[i][j] : '';
            }
            dataRows.push(obj);
        }

        if (dataRows.length === 0) {
            this.parseError = 'No data rows found in the CSV.';
            return;
        }

        this.csvHeaders = headers;
        this.csvRows = dataRows;
        this.buildColumnMappings(headers);
        this.step = 'mapping';
    }

    detectDelimiter(text) {
        const firstLine = text.split('\n')[0] || '';
        const commas     = (firstLine.match(/,/g) || []).length;
        const semicolons = (firstLine.match(/;/g) || []).length;
        const tabs       = (firstLine.match(/\t/g) || []).length;

        if (tabs >= commas && tabs >= semicolons && tabs > 0) return '\t';
        if (semicolons > commas && semicolons > 0) return ';';
        return ',';
    }

    /**
     * RFC 4180-compliant CSV parser with proper handling of:
     * - Quoted fields containing delimiters
     * - Escaped quotes (double-quote within quoted field)
     * - Newlines within quoted fields
     * - Empty fields
     */
    parseCsvText(text, delimiter) {
        const rows = [];
        let currentRow = [];
        let currentField = '';
        let inQuotes = false;
        let i = 0;

        while (i < text.length) {
            const ch = text[i];

            if (inQuotes) {
                if (ch === '"') {
                    // Peek ahead: is this an escaped quote?
                    if (i + 1 < text.length && text[i + 1] === '"') {
                        currentField += '"';
                        i += 2;
                        continue;
                    }
                    // End of quoted field
                    inQuotes = false;
                    i++;
                    continue;
                }
                currentField += ch;
                i++;
                continue;
            }

            // Not inside quotes
            if (ch === '"' && currentField.length === 0) {
                inQuotes = true;
                i++;
                continue;
            }
            if (ch === delimiter) {
                currentRow.push(currentField.trim());
                currentField = '';
                i++;
                continue;
            }
            if (ch === '\r') {
                // Handle \r\n or standalone \r
                currentRow.push(currentField.trim());
                currentField = '';
                rows.push(currentRow);
                currentRow = [];
                if (i + 1 < text.length && text[i + 1] === '\n') {
                    i++;
                }
                i++;
                continue;
            }
            if (ch === '\n') {
                currentRow.push(currentField.trim());
                currentField = '';
                rows.push(currentRow);
                currentRow = [];
                i++;
                continue;
            }

            currentField += ch;
            i++;
        }

        // Flush the last field/row
        if (currentField.length > 0 || currentRow.length > 0) {
            currentRow.push(currentField.trim());
            rows.push(currentRow);
        }

        return rows;
    }

    // ── Column mapping ───────────────────────────────────────────────
    buildColumnMappings(headers) {
        // Check for Jira format
        const lowerHeaders = headers.map(h => h.toLowerCase().trim());
        const jiraMatch = JIRA_DETECTION_COLUMNS.every(
            col => lowerHeaders.includes(col)
        );
        this.isJiraDetected = jiraMatch;

        // Build a lookup from lowercase field label/api name to api name
        const labelToApi = {};
        const apiToApi = {};
        for (const f of this.availableFields) {
            labelToApi[f.label.toLowerCase()] = f.apiName;
            apiToApi[f.apiName.toLowerCase()] = f.apiName;
        }

        this.columnMappings = headers.map(header => {
            const headerLower = header.toLowerCase().trim();
            let target = '';

            if (jiraMatch && JIRA_COLUMN_MAP[headerLower]) {
                // Jira auto-mapping takes priority
                target = JIRA_COLUMN_MAP[headerLower];
            } else if (apiToApi[headerLower]) {
                // Exact API name match (case-insensitive)
                target = apiToApi[headerLower];
            } else if (labelToApi[headerLower]) {
                // Field label match
                target = labelToApi[headerLower];
            }

            return {
                csvColumn: header,
                targetField: target,
                key: header  // for iteration key
            };
        });
    }

    handleMappingChange(event) {
        const csvColumn = event.target.dataset.column;
        const newTarget = event.detail.value;
        this.columnMappings = this.columnMappings.map(m =>
            m.csvColumn === csvColumn
                ? { ...m, targetField: newTarget }
                : m
        );
    }

    // ── Navigation between steps ─────────────────────────────────────
    handleBackToUpload() {
        this.step = 'upload';
        this.csvHeaders = [];
        this.csvRows = [];
        this.columnMappings = [];
        this.isJiraDetected = false;
        this.fileName = '';
        this.parseError = '';
    }

    handleProceedToPreview() {
        if (!this.hasMappedColumns) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'No columns mapped',
                message: 'Please map at least one CSV column to a Work Item field.',
                variant: 'warning'
            }));
            return;
        }
        this.step = 'preview';
    }

    handleBackToMapping() {
        this.step = 'mapping';
    }

    // ── Import execution ─────────────────────────────────────────────
    handleStartImport() {
        this.step = 'importing';
        this.importTotal = this.csvRows.length;
        this.importProgress = 0;
        this.importResult = null;

        const mappedColumns = this.columnMappings.filter(m => m.targetField);

        // Build the records payload, applying Jira value transforms
        const records = this.csvRows.map(row => {
            const rec = {};
            for (const m of mappedColumns) {
                let value = row[m.csvColumn] || '';

                // Apply Jira value transformations
                if (this.isJiraDetected && value) {
                    if (m.targetField === 'PriorityPk__c') {
                        value = JIRA_PRIORITY_MAP[value.toLowerCase()] || value;
                    } else if (m.targetField === 'StageNamePk__c') {
                        value = JIRA_STATUS_MAP[value.toLowerCase()] || 'Backlog';
                    } else if (m.targetField === 'RequestTypePk__c') {
                        value = JIRA_ISSUE_TYPE_MAP[value.toLowerCase()] || value;
                    }
                }

                rec[m.targetField] = value;
            }
            return rec;
        });

        importWorkItems({ records, workflowType: 'Software_Delivery' })
            .then(result => {
                this.importResult = result;
                this.importProgress = this.importTotal;
                this.step = 'results';
            })
            .catch(error => {
                this.step = 'results';
                this.importResult = {
                    successCount: 0,
                    errorCount: this.importTotal,
                    errors: [{
                        row: 'N/A',
                        message: error.body ? error.body.message : error.message
                    }],
                    createdIds: []
                };
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Import Failed',
                    message: error.body ? error.body.message : error.message,
                    variant: 'error'
                }));
            });
    }

    // ── Post-import actions ──────────────────────────────────────────
    handleViewOnBoard() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Delivery_Hub'
            }
        });
    }

    handleImportAnother() {
        this.step = 'upload';
        this.fileName = '';
        this.csvHeaders = [];
        this.csvRows = [];
        this.columnMappings = [];
        this.isJiraDetected = false;
        this.importResult = null;
        this.importProgress = 0;
        this.importTotal = 0;
        this.parseError = '';
    }
}
