/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Shared formatting for WorkItemComment__c.BodyTxt__c.
 *
 *               That field is declared type Html (Rich Text Area), and Salesforce
 *               entity-encodes content characters on save. So the stored value is
 *               ALWAYS html, arriving in one of two shapes:
 *                 (a) real markup   — "<p><b>Shipped.</b> Jose&#39;s call.</p>"
 *                 (b) plain prose   — "Jose&#39;s call.\n\nNext up:" (no tags,
 *                                      newlines intact, quotes still encoded)
 *               Roughly 3/4 of MF-Prod comments are shape (a), the rest (b).
 *
 *               Rendering either shape as plain text prints the markup literally —
 *               that is the bug this module exists to fix (Jose, 2026-08-12:
 *               "the text doesn't take special characters like apostrophes").
 *
 *               toRichText()  feeds lightning-formatted-rich-text, which decodes
 *                             entities and renders markup for us.
 *               toPlainText() is for surfaces that genuinely need a bare string —
 *                             one-line previews concatenated into a text node.
 *                             Mirrors the Apex-side treatment already used at
 *                             DeliveryWorkApprovalService.stripHtmlTags().unescapeHtml4().
 * @author Cloud Nimbus LLC
 */

/** Matches an html tag. A literal "<" typed by a user arrives encoded as &lt;, so this cannot false-positive on shape (b). */
const TAG_PATTERN = /<[a-zA-Z!/][^>]*>/;

/** Tags whose close implies a line break when flattening to plain text. */
const BLOCK_CLOSE_PATTERN = /<\/(p|div|li|h[1-6]|tr|blockquote)\s*>/gi;

const BR_PATTERN = /<br\s*\/?>/gi;

const NEWLINE_PATTERN = /\r\n|\r|\n/g;

/**
 * Named entities worth decoding. Deliberately NOT exhaustive — Salesforce emits
 * numeric entities for the characters that actually show up in prose (&#39;),
 * and these few named ones cover the rest. &amp; is handled last and separately.
 */
const NAMED_ENTITIES = {
    '&nbsp;': ' ',
    '&quot;': '"',
    '&apos;': "'",
    '&lt;': '<',
    '&gt;': '>'
};

/**
 * @description True when the body carries real html markup (shape a).
 * @param {string} body Raw BodyTxt__c value.
 * @return {boolean}
 */
export function hasMarkup(body) {
    return typeof body === 'string' && TAG_PATTERN.test(body);
}

/**
 * @description Normalises a comment body into html safe to hand to
 *              lightning-formatted-rich-text. Markup passes through untouched;
 *              plain prose gets its newlines promoted to <br> so it does not
 *              collapse into a wall when the browser folds whitespace.
 *
 *              Never escapes. The stored value is already entity-encoded by the
 *              platform, and escaping again is precisely how you get &amp;#39;.
 * @param {string} body Raw BodyTxt__c value.
 * @return {string} Html string, or '' when there is nothing to render.
 */
export function toRichText(body) {
    if (!body) {
        return '';
    }
    if (hasMarkup(body)) {
        return body;
    }
    return body.replace(NEWLINE_PATTERN, '<br>');
}

/**
 * @description Flattens a comment body to a bare string — tags stripped, entities
 *              decoded, whitespace collapsed. For previews rendered as text.
 * @param {string} body Raw BodyTxt__c value.
 * @return {string} Plain text, or '' when there is nothing to render.
 */
export function toPlainText(body) {
    if (!body) {
        return '';
    }
    const flattened = body
        .replace(BR_PATTERN, '\n')
        .replace(BLOCK_CLOSE_PATTERN, '\n')
        .replace(/<[^>]*>/g, '');

    return decodeEntities(flattened)
        .replace(/[ \t]+/g, ' ')
        .replace(/\s*\n\s*/g, '\n')
        .replace(/\n{2,}/g, '\n')
        .trim();
}

/**
 * @description Decodes html entities without touching the DOM — innerHTML round-tripping
 *              would be both a Locker hazard and an XSS foot-gun.
 *
 *              &amp; is decoded LAST. Decoding it first would turn the literal
 *              text "&amp;lt;" into "<" rather than the "&lt;" the author wrote.
 * @param {string} value Flattened, tag-free string.
 * @return {string}
 */
function decodeEntities(value) {
    let out = value
        .replace(/&#(\d+);/g, (match, dec) => safeCodePoint(parseInt(dec, 10), match))
        .replace(/&#x([0-9a-f]+);/gi, (match, hex) => safeCodePoint(parseInt(hex, 16), match));

    Object.keys(NAMED_ENTITIES).forEach(entity => {
        out = out.split(entity).join(NAMED_ENTITIES[entity]);
    });

    return out.split('&amp;').join('&');
}

/**
 * @description Converts a numeric entity to its character, leaving malformed or
 *              out-of-range references as the author typed them.
 * @param {number} code Parsed code point.
 * @param {string} original The matched entity text, returned on failure.
 * @return {string}
 */
function safeCodePoint(code, original) {
    if (!Number.isFinite(code) || code < 1 || code > 0x10ffff) {
        return original;
    }
    return String.fromCodePoint(code);
}
