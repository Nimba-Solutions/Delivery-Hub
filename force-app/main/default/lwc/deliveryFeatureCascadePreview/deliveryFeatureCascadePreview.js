/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Cascade preview LWC for the Feature Cockpit.
 *               Renders the dependency tree returned by
 *               DeliveryFeatureGraphService.computeCascade(featureId, action)
 *               as a flattened indented tree. PR 5 is informational only —
 *               Confirm dispatches a `confirm` event; PR 6 wires actual
 *               enforcement, PR 7+ wires approval workflow.
 *
 *               No ternaries in the template (LWC v62 limitation per CLAUDE.md).
 *               No @api boolean defaulting to true (LWC1503).
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire } from 'lwc';
import computeCascade from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureGraphService.computeCascade';

const ACTION_ENABLE = 'Enable',
    ACTION_DISABLE = 'Disable',
    INDENT_REM_PER_DEPTH = 1.5,
    EMPTY = 0,
    ONE = 1;

export default class DeliveryFeatureCascadePreview extends LightningElement {
    @api featureId;
    @api action = ACTION_ENABLE;
    /**
     * When true the component renders as a standalone preview (with headline +
     * Cancel/Confirm footer). Defaults to true so the modal host gets a complete
     * UI; embedded uses can flip it off via `hide-footer-buttons` attribute.
     * Per LWC1503 we don't expose a boolean that defaults to true — instead we
     * expose `hideFooterButtons` which defaults to false.
     */
    @api hideFooterButtons = false;

    isLoading = true;
    isLoaded = false;
    errorMessage = '';
    rootNode = null;

    @wire(computeCascade, { featureId: '$featureId', action: '$action' })
    wiredCascade(result) {
        if (result.data !== undefined && result.data !== null) {
            this.rootNode = result.data;
            this.errorMessage = '';
            this.isLoaded = true;
            this.isLoading = false;
        } else if (result.data === null) {
            this.rootNode = null;
            this.errorMessage = 'Feature not found.';
            this.isLoaded = true;
            this.isLoading = false;
        } else if (result.error) {
            this.errorMessage = this.extractErrorMessage(result.error);
            this.rootNode = null;
            this.isLoaded = true;
            this.isLoading = false;
        }
    }

    extractErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        return 'Unable to compute cascade.';
    }

    get hasError() {
        return !!this.errorMessage;
    }

    get isStandalone() {
        return !this.hideFooterButtons;
    }

    get showFooterButtons() {
        return !this.hideFooterButtons;
    }

    get isEnableAction() {
        return this.action === ACTION_ENABLE;
    }

    get actionHeadline() {
        if (this.isEnableAction) {
            return 'These features must be enabled first before turning this on.';
        }
        return 'These features depend on this one — they may need to be disabled first.';
    }

    /**
     * Flatten the tree into an indented row list for the template.
     * Each row carries indent style + iconography + an optional badge.
     */
    get flattenedRows() {
        const rows = [];
        if (!this.rootNode) {
            return rows;
        }
        this.walk(this.rootNode, rows, true);
        return rows;
    }

    walk(node, rows, isRoot) {
        const depth = node.depth || 0;
        rows.push(this.toRow(node, isRoot));
        if (node.children && node.children.length > EMPTY) {
            for (const child of node.children) {
                this.walk(child, rows, false);
            }
        }
        return depth;
    }

    toRow(node, isCurrentRoot) {
        const depth = node.depth || 0,
            isHard = node.dependencyType === 'Hard',
            isSoft = node.dependencyType === 'Soft',
            isOptional = node.dependencyType === 'Optional';

        let iconName = 'utility:record',
            iconVariant = 'default',
            iconAlt = 'Feature';
        if (isHard) {
            iconName = 'utility:lock';
            iconVariant = 'error';
            iconAlt = 'Hard dependency';
        } else if (isSoft) {
            iconName = 'utility:warning';
            iconVariant = 'warning';
            iconAlt = 'Soft dependency';
        } else if (isOptional) {
            iconName = 'utility:info';
            iconVariant = 'default';
            iconAlt = 'Optional dependency';
        } else if (isCurrentRoot) {
            iconName = 'utility:apps';
            iconVariant = 'default';
            iconAlt = 'Current feature';
        }

        let badgeText = '',
            badgeClass = '',
            hasBadge = false;
        if (!isCurrentRoot) {
            hasBadge = true;
            if (this.isEnableAction) {
                badgeText = 'Enable required';
                badgeClass = 'slds-badge slds-theme_success slds-m-left_x-small';
            } else {
                badgeText = 'Disable required';
                badgeClass = 'slds-badge slds-theme_warning slds-m-left_x-small';
            }
        }

        return {
            key: `${node.featureId}-${depth}`,
            label: node.label || node.name || node.featureId,
            depth,
            ariaLevel: depth + ONE,
            indentStyle: `padding-left: ${depth * INDENT_REM_PER_DEPTH}rem;`,
            rowClass: 'slds-p-vertical_xx-small',
            iconName,
            iconVariant,
            iconAlt,
            isCurrentRoot,
            hasBadge,
            badgeText,
            badgeClass,
            dependencyType: node.dependencyType
        };
    }

    /** Count of nodes at each depth, formatted for the summary panel. */
    get depthCounts() {
        const counts = new Map();
        if (this.rootNode) {
            this.collectDepthCounts(this.rootNode, counts);
        }
        const rows = [];
        const depths = Array.from(counts.keys()).sort((a, b) => a - b);
        for (const d of depths) {
            const count = counts.get(d),
                noun = count === ONE ? 'feature' : 'features',
                label = d === EMPTY
                    ? `Current: ${count} ${noun}`
                    : `Depth ${d}: ${count} ${noun}`;
            rows.push({ depth: d, label });
        }
        return rows;
    }

    collectDepthCounts(node, counts) {
        const depth = node.depth || 0,
            existing = counts.get(depth) || 0;
        counts.set(depth, existing + ONE);
        if (node.children) {
            for (const child of node.children) {
                this.collectDepthCounts(child, counts);
            }
        }
    }

    /** "Looks good" if no hard dependencies surfaced; otherwise warning text. */
    get summaryText() {
        if (!this.rootNode) {
            return '';
        }
        const hasHard = this.hasHardDependency(this.rootNode);
        if (hasHard) {
            return 'Has hard dependencies — these must be honored before proceeding.';
        }
        if (this.flattenedRows.length <= ONE) {
            return 'Looks good — no dependencies surfaced.';
        }
        return 'Looks good — only soft / optional dependencies surfaced.';
    }

    get summaryToneClass() {
        if (!this.rootNode) {
            return 'slds-text-color_weak';
        }
        if (this.hasHardDependency(this.rootNode)) {
            return 'slds-text-color_error slds-m-top_x-small';
        }
        return 'slds-text-color_success slds-m-top_x-small';
    }

    hasHardDependency(node) {
        if (!node) {
            return false;
        }
        if (node.dependencyType === 'Hard') {
            return true;
        }
        if (node.children) {
            for (const child of node.children) {
                if (this.hasHardDependency(child)) {
                    return true;
                }
            }
        }
        return false;
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    handleConfirm() {
        this.dispatchEvent(new CustomEvent('confirm', {
            detail: {
                featureId: this.featureId,
                action: this.action,
                hasHardDependencies: this.hasHardDependency(this.rootNode)
            }
        }));
    }
}
