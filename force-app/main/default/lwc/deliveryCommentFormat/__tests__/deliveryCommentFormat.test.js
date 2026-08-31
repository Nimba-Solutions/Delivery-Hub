/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Covers the two comment-body shapes actually present in MF-Prod.
 *               Fixtures below are lifted verbatim from real WorkItemComment__c
 *               rows so the tests fail if the platform's encoding behaviour on
 *               Rich Text Area saves ever changes.
 * @author Cloud Nimbus LLC
 */
import { toRichText, toPlainText, hasMarkup } from 'c/deliveryCommentFormat';

// Shape (b): plain prose, no tags, newlines intact, content chars encoded.
// Verbatim from the comment Jose screenshotted on 2026-08-12.
const PLAIN_SHAPE =
    'DIAGNOSED 8/3. Jose&#39;s hypothesis - &quot;it can&#39;t be resolved via ' +
    'Document Receipts&quot; - turns out to be wrong.\n\nWHAT OLIVIA IS SEEING\n\n' +
    '7/22 created -&gt; completed 7/22 -&gt; recreated 7/23';

// Shape (a): real markup, no newlines. Verbatim from a 2026-08-05 comment.
const MARKUP_SHAPE =
    '<p><b>The write-up for this ticket is live:</b></p>' +
    '<p><a href="https://cloudnimbusllc.com/mf/iuw-tasks-0805" target="_blank">Read it</a></p>';

describe('hasMarkup', () => {
    it('detects real markup', () => {
        expect(hasMarkup(MARKUP_SHAPE)).toBe(true);
    });

    it('does not fire on encoded angle brackets in plain prose', () => {
        // The bug this guards: -&gt; must not read as a tag, or plain comments
        // lose their newlines and render as a wall.
        expect(hasMarkup(PLAIN_SHAPE)).toBe(false);
        expect(hasMarkup('use &lt;p&gt; for a paragraph')).toBe(false);
    });

    it('tolerates non-strings', () => {
        expect(hasMarkup(null)).toBe(false);
        expect(hasMarkup(undefined)).toBe(false);
    });
});

describe('toRichText', () => {
    it('promotes newlines to <br> for plain prose', () => {
        const out = toRichText(PLAIN_SHAPE);
        expect(out).toContain('Receipts&quot; - turns out to be wrong.<br><br>WHAT OLIVIA');
        expect(out).not.toContain('\n');
    });

    it('leaves entities alone so the renderer decodes them once, not twice', () => {
        // Double-escaping here is exactly how you get a literal &amp;#39; on screen.
        expect(toRichText(PLAIN_SHAPE)).toContain('Jose&#39;s hypothesis');
        expect(toRichText(PLAIN_SHAPE)).not.toContain('&amp;#39;');
    });

    it('passes real markup through untouched', () => {
        expect(toRichText(MARKUP_SHAPE)).toBe(MARKUP_SHAPE);
    });

    it('handles carriage returns', () => {
        expect(toRichText('one\r\ntwo\rthree')).toBe('one<br>two<br>three');
    });

    it('returns empty string for blank input', () => {
        expect(toRichText('')).toBe('');
        expect(toRichText(null)).toBe('');
        expect(toRichText(undefined)).toBe('');
    });
});

describe('toPlainText', () => {
    it('decodes the entities a reader would otherwise see raw', () => {
        const out = toPlainText(PLAIN_SHAPE);
        expect(out).toContain("Jose's hypothesis");
        expect(out).toContain('"it can\'t be resolved via Document Receipts"');
        expect(out).toContain('7/22 created -> completed 7/22');
        expect(out).not.toContain('&#39;');
        expect(out).not.toContain('&gt;');
    });

    it('strips tags and keeps the link text', () => {
        const out = toPlainText(MARKUP_SHAPE);
        expect(out).toBe('The write-up for this ticket is live:\nRead it');
        expect(out).not.toContain('<');
        expect(out).not.toContain('href');
    });

    it('turns <br> and block closes into single newlines', () => {
        expect(toPlainText('<p>one</p><p>two</p>')).toBe('one\ntwo');
        expect(toPlainText('one<br>two<br/>three')).toBe('one\ntwo\nthree');
    });

    it('decodes &amp; last so escaped entities survive', () => {
        // The author literally wrote "&lt;" — it must not collapse to "<".
        expect(toPlainText('write &amp;lt; to mean less-than')).toBe('write &lt; to mean less-than');
        expect(toPlainText('Covenant Grading &amp; Utilities')).toBe('Covenant Grading & Utilities');
    });

    it('decodes hex entities', () => {
        expect(toPlainText('it&#x27;s here')).toBe("it's here");
    });

    it('leaves malformed numeric entities as written', () => {
        expect(toPlainText('&#0; and &#99999999;')).toBe('&#0; and &#99999999;');
    });

    it('collapses runs of whitespace', () => {
        expect(toPlainText('<p>one</p>\n\n\n<p>two</p>')).toBe('one\ntwo');
        expect(toPlainText('  spaced   out  ')).toBe('spaced out');
    });

    it('returns empty string for blank input', () => {
        expect(toPlainText('')).toBe('');
        expect(toPlainText(null)).toBe('');
        expect(toPlainText(undefined)).toBe('');
    });
});
