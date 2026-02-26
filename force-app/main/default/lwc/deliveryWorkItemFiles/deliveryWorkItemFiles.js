/**
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getWorkItemFiles from '@salesforce/apex/DeliveryHubFilesController.getWorkItemFiles';

const EXTENSION_ICON_MAP = {
    pdf: 'doctype:pdf',
    doc: 'doctype:word',
    docx: 'doctype:word',
    xls: 'doctype:excel',
    xlsx: 'doctype:excel',
    ppt: 'doctype:ppt',
    pptx: 'doctype:ppt',
    png: 'doctype:image',
    jpg: 'doctype:image',
    jpeg: 'doctype:image',
    gif: 'doctype:image',
    zip: 'doctype:zip',
    txt: 'doctype:txt',
    csv: 'doctype:csv',
    mp4: 'doctype:video',
    mov: 'doctype:video'
};

function getIconName(ext) {
    if (!ext) return 'doctype:unknown';
    return EXTENSION_ICON_MAP[ext.toLowerCase()] || 'doctype:unknown';
}

function formatSize(bytes) {
    if (!bytes) return '';
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return Math.round(bytes / 1024) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
}

export default class DeliveryWorkItemFiles extends LightningElement {
    @api recordId;
    @track files = [];
    @track isLoading = true;
    _wiredResult;

    @wire(getWorkItemFiles, { workItemId: '$recordId' })
    wiredFiles(result) {
        this._wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.files = data.map(f => ({
                ...f,
                iconName: getIconName(f.extension),
                formattedSize: formatSize(f.fileSize),
                downloadUrl: '/sfc/servlet.shepherd/document/download/' + f.documentId
            }));
            this.isLoading = false;
        } else if (error) {
            console.error('Error loading files', error);
            this.isLoading = false;
        }
    }

    get hasFiles() {
        return this.files && this.files.length > 0;
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredResult).then(() => {
            this.isLoading = false;
        });
    }
}
