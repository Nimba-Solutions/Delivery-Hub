/**
 * Delivery Hub — Document Renderer
 * Self-contained vanilla JS renderer for public document viewing.
 * Fetches document data via public API token, renders beautiful HTML.
 * No build tools, no frameworks — just modern JS + DOM.
 */
(function () {
    'use strict';

    // ═══════════════════════════════════════════════════════════
    //  INIT
    // ═══════════════════════════════════════════════════════════

    var token = getUrlParam('token');
    var docId = getUrlParam('id');

    // If we have data injected by VF page (server-side), use it
    if (window.__DELIVERY_DOC_DATA__) {
        render(window.__DELIVERY_DOC_DATA__);
    } else if (token || docId) {
        fetchDocument(token, docId);
    } else {
        showError('No document token or ID provided.');
    }

    // ═══════════════════════════════════════════════════════════
    //  FETCH
    // ═══════════════════════════════════════════════════════════

    function fetchDocument(token, id) {
        // Build the API URL — works with Salesforce Sites public endpoint
        var baseUrl = window.location.origin;
        var apiPath = '/services/apexrest/delivery/api';
        var url = baseUrl + apiPath + '/documents';
        if (token) url += '?token=' + encodeURIComponent(token);
        else if (id) url += '?id=' + encodeURIComponent(id);

        fetch(url)
            .then(function (r) {
                if (!r.ok) throw new Error('HTTP ' + r.status);
                return r.json();
            })
            .then(function (data) { render(data); })
            .catch(function (err) { showError('Unable to load document: ' + err.message); });
    }

    // ═══════════════════════════════════════════════════════════
    //  RENDER
    // ═══════════════════════════════════════════════════════════

    function render(doc) {
        var snapshot = typeof doc.snapshot === 'string' ? JSON.parse(doc.snapshot) : doc.snapshot;
        var entity = snapshot.entity || {};
        var workItems = snapshot.workItems || [];
        var workLogs = snapshot.workLogs || [];
        var isInvoice = doc.template === 'Invoice';
        var isAgreement = doc.template === 'Client_Agreement' || doc.template === 'Contractor_Agreement';
        var templateDisplay = (doc.template || '').replace(/_/g, ' ');
        var totalHours = doc.totalHours || 0;
        var totalCost = doc.totalCost || 0;
        var defaultRate = entity.defaultRate || 0;

        // Parse metadata for prior balance
        var meta = {};
        try { if (doc.metadata) meta = JSON.parse(doc.metadata); } catch (e) { /* ignore */ }
        var priorBalance = meta.priorBalance || 0;
        var amountDue = totalCost + priorBalance;

        var html = '';

        // Toolbar
        html += '<div class="doc-toolbar">';
        html += '  <div class="doc-toolbar-left">';
        html += '    <span class="toolbar-status status-' + (doc.status || 'draft').toLowerCase() + '">' + esc(doc.status || 'Draft') + '</span>';
        html += '  </div>';
        html += '  <div class="doc-toolbar-right">';
        html += '    <button class="btn" onclick="window.print()" title="Print"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 9V2h12v7M6 18H4a2 2 0 01-2-2v-5a2 2 0 012-2h16a2 2 0 012 2v5a2 2 0 01-2 2h-2"/><rect x="6" y="14" width="12" height="8"/></svg>Print</button>';
        html += '    <button class="btn btn-primary" id="btn-pdf" title="Download PDF"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 3v4a1 1 0 001 1h4M17 21H7a2 2 0 01-2-2V5a2 2 0 012-2h7l5 5v11a2 2 0 01-2 2z"/><path d="M12 11v6M9 14l3 3 3-3"/></svg>PDF</button>';
        html += '  </div>';
        html += '</div>';

        // Brand Header
        html += '<div class="doc-brand-bar">';
        html += '  <div class="doc-brand-left">';
        html += '    <div class="doc-brand-name">Cloud Nimbus LLC</div>';
        html += '    <div class="doc-brand-url">cloudnimbusllc.com</div>';
        html += '  </div>';
        html += '  <div class="doc-brand-right">';
        html += '    <div class="doc-brand-type">' + esc(templateDisplay) + '</div>';
        html += '    <div class="doc-brand-number">' + esc(doc.name || '') + '</div>';
        html += '  </div>';
        html += '</div>';

        // Parties
        html += '<div class="doc-parties">';
        html += '  <div class="party-block">';
        html += '    <div class="party-label">' + (isInvoice ? 'Bill To' : 'Prepared For') + '</div>';
        html += '    <div class="party-name">' + esc(entity.name || doc.entityName || '') + '</div>';
        if (entity.address) html += '<div class="party-detail">' + esc(entity.address) + '</div>';
        if (entity.email) html += '<div class="party-detail">' + esc(entity.email) + '</div>';
        if (entity.phone) html += '<div class="party-detail">' + esc(entity.phone) + '</div>';
        html += '  </div>';
        html += '  <div class="party-block" style="text-align: right;">';
        html += '    <div class="meta-grid">';
        if (doc.periodStart && doc.periodEnd) {
            html += '<div class="meta-row"><span class="meta-label">Period</span><span class="meta-value">' + formatDate(doc.periodStart) + ' - ' + formatDate(doc.periodEnd) + '</span></div>';
        }
        if (doc.terms) html += '<div class="meta-row"><span class="meta-label">Terms</span><span class="meta-value">' + esc(doc.terms) + '</span></div>';
        if (doc.dueDate) html += '<div class="meta-row"><span class="meta-label">Due Date</span><span class="meta-value">' + formatDate(doc.dueDate) + '</span></div>';
        if (defaultRate) html += '<div class="meta-row"><span class="meta-label">Rate</span><span class="meta-value">' + fmtCurrency(defaultRate) + '/hr</span></div>';
        html += '    </div>';
        html += '  </div>';
        html += '</div>';

        // Summary Cards
        if (!isAgreement) {
            html += '<div class="doc-summary">';
            html += '  <div class="summary-card"><div class="summary-card-label">Total Hours</div><div class="summary-card-value">' + totalHours.toFixed(1) + '</div></div>';
            html += '  <div class="summary-card"><div class="summary-card-label">Total Amount</div><div class="summary-card-value accent">' + fmtCurrency(totalCost) + '</div></div>';
            html += '</div>';
        }

        // Content
        html += '<div class="doc-content">';

        // Work Items Table
        if (workItems.length > 0) {
            html += '<div class="section-title">Work Items</div>';
            html += '<table class="data-table"><tr>';
            html += '<th style="width:12%">Name</th><th style="width:34%">Description</th><th style="width:16%">Stage</th>';
            html += '<th class="r" style="width:10%">Hours</th><th class="r" style="width:12%">Rate</th><th class="r" style="width:16%">Subtotal</th>';
            html += '</tr>';
            workItems.forEach(function (wi) {
                var hrs = wi.totalLoggedHours || 0;
                var rate = wi.billableRate || defaultRate;
                var sub = hrs * rate;
                html += '<tr>';
                html += '<td class="b">' + esc(wi.name) + '</td>';
                html += '<td>' + esc(wi.description || '-') + '</td>';
                html += '<td>' + esc(wi.stage || '-') + '</td>';
                html += '<td class="r">' + hrs.toFixed(1) + '</td>';
                html += '<td class="r">' + fmtCurrency(rate) + '</td>';
                html += '<td class="r b">' + fmtCurrency(sub) + '</td>';
                html += '</tr>';
            });
            html += '</table>';
        }

        // Work Logs Table
        if (workLogs.length > 0) {
            html += '<div class="section-title">Time Log Detail</div>';
            html += '<table class="data-table"><tr>';
            html += '<th style="width:13%">Date</th><th style="width:13%">Work Item</th>';
            html += '<th class="r" style="width:9%">Hours</th><th style="width:65%">Description</th>';
            html += '</tr>';
            workLogs.forEach(function (wl) {
                html += '<tr>';
                html += '<td>' + formatDate(wl.date) + '</td>';
                html += '<td class="b">' + esc(wl.workItemName || '-') + '</td>';
                html += '<td class="r">' + (wl.hours || 0).toFixed(1) + '</td>';
                html += '<td>' + esc(wl.description || '-') + '</td>';
                html += '</tr>';
            });
            html += '</table>';
        }

        // AI Narrative
        if (doc.aiNarrative) {
            html += '<div class="section-title">Summary</div>';
            html += '<div class="narrative-box">' + esc(doc.aiNarrative) + '</div>';
        }

        html += '</div>'; // end doc-content

        // Footer
        html += '<div class="doc-footer">';
        html += '  <div class="footer-terms">' + (doc.terms ? 'Terms: ' + esc(doc.terms) : '') + '</div>';
        if (!isAgreement) {
            html += '<div class="footer-total">';
            if (priorBalance > 0) {
                html += '<div class="footer-prior">Prior Balance: ' + fmtCurrency(priorBalance) + '</div>';
                html += '<div class="footer-prior">Current Charges: ' + fmtCurrency(totalCost) + '</div>';
            }
            html += '<div class="footer-total-label">Total Due</div>';
            html += '<div class="footer-total-amount">' + fmtCurrency(amountDue) + '</div>';
            html += '</div>';
        }
        html += '</div>';
        html += '<div class="doc-footer-brand">Cloud Nimbus LLC &bull; cloudnimbusllc.com &bull; Powered by Delivery Hub</div>';

        // Inject
        var container = document.getElementById('document-container');
        container.innerHTML = '<div class="doc-page">' + html + '</div>';
        container.style.display = 'block';
        document.getElementById('loading-state').style.display = 'none';
        document.title = (doc.name || 'Document') + ' - ' + templateDisplay + ' - Cloud Nimbus LLC';

        // Wire PDF button
        var pdfBtn = document.getElementById('btn-pdf');
        if (pdfBtn && window.html2pdf) {
            pdfBtn.addEventListener('click', function () {
                var page = container.querySelector('.doc-page');
                var toolbar = page.querySelector('.doc-toolbar');
                if (toolbar) toolbar.style.display = 'none';
                html2pdf().set({
                    margin: [0.3, 0.3, 0.4, 0.3],
                    filename: (doc.name || 'document') + '.pdf',
                    image: { type: 'jpeg', quality: 0.98 },
                    html2canvas: { scale: 2, useCORS: true },
                    jsPDF: { unit: 'in', format: 'letter', orientation: 'portrait' }
                }).from(page).save().then(function () {
                    if (toolbar) toolbar.style.display = '';
                });
            });
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  HELPERS
    // ═══════════════════════════════════════════════════════════

    function getUrlParam(name) {
        var params = new URLSearchParams(window.location.search);
        return params.get(name);
    }

    function esc(str) {
        if (!str) return '';
        var d = document.createElement('div');
        d.textContent = str;
        return d.innerHTML;
    }

    function fmtCurrency(n) {
        if (n == null) return '$0.00';
        return '$' + Number(n).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    }

    function formatDate(val) {
        if (!val) return '-';
        try {
            var d = new Date(val);
            return d.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
        } catch (e) { return String(val); }
    }

    function showError(msg) {
        document.getElementById('loading-state').style.display = 'none';
        document.getElementById('error-state').style.display = 'block';
        document.getElementById('error-message').textContent = msg;
    }

})();
