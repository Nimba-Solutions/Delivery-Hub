/**
* @File Name : HtmlToAdfConverter.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : July 6, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | July 6, 2025 |   | Initial Version
**/

/**
 * @description Utility class for converting HTML content to Atlassian Document Format (ADF)
 */
public class HtmlToAdfConverter {
    /**
     * @description Converts basic HTML (from Salesforce Rich Text) to Jira ADF JSON Map.
     * Only handles very common tags: <b>, <strong>, <i>, <em>, <u>, <ul>, <ol>, <li>, <p>, <br>
     * Everything else is stripped.
     * @param html The HTML string to convert
     * @return Map<String, Object> The ADF JSON structure as a Map
     */
    public static Map<String, Object> convert(String html) {
        if (String.isBlank(html)) {
            html = '';
        }
        // Remove script/style tags for safety
        html = html.replaceAll('(?i)<script.*?>[\\s\\S]*?<\\/script>', '');
        html = html.replaceAll('(?i)<style.*?>[\\s\\S]*?<\\/style>', '');

        // Standardize newlines and trim
        html = html.replaceAll('\r', '').trim();

        // Split by block elements (paragraphs, lists)
        List<Map<String, Object>> docContent = new List<Map<String, Object>>();
        
        // Handle lists first (ul/ol)
        while (html.contains('<ul>') || html.contains('<ol>')) {
            html = processFirstList(html, docContent);
        }
        
        // Break into paragraphs
        List<String> paras = html.split('(?i)<p>|<br ?/?>');
        for (String para : paras) {
            String cleanPara = stripTags(para).trim();
            if (cleanPara == '') {
                continue;
            }
            docContent.add(buildParagraph(cleanPara));
        }

        if (docContent.isEmpty()) {
            docContent.add(buildParagraph(''));
        }

        Map<String, Object> adf = new Map<String, Object>{
            'type' => 'doc',
            'version' => 1,
            'content' => docContent
        };
        return adf;
    }

    private static String stripTags(String html) {
        // Allow only a subset, everything else becomes plain text
        html = html.replaceAll('(?i)<(b|strong)>', '__B__');
        html = html.replaceAll('(?i)</(b|strong)>', '__/B__');
        html = html.replaceAll('(?i)<(i|em)>', '__I__');
        html = html.replaceAll('(?i)</(i|em)>', '__/I__');
        html = html.replaceAll('(?i)<u>', '__U__');
        html = html.replaceAll('(?i)</u>', '__/U__');
        // Remove all other tags
        html = html.replaceAll('<[^>]+>', '');
        // Restore
        html = html.replaceAll('__B__', '<b>');
        html = html.replaceAll('__/B__', '</b>');
        html = html.replaceAll('__I__', '<i>');
        html = html.replaceAll('__/I__', '</i>');
        html = html.replaceAll('__U__', '<u>');
        html = html.replaceAll('__/U__', '</u>');
        return html;
    }

    private static Map<String, Object> buildParagraph(String text) {
		List<Map<String, Object>> content = new List<Map<String, Object>>();
		// Corrected: Use (?i) in the regex for case-insensitivity
		Pattern p = Pattern.compile('(?i)(<b>|</b>|<i>|</i>|<u>|</u>)');
		Matcher m = p.matcher(text);

		List<Object> tokens = new List<Object>();
		Integer lastIdx = 0;
		while (m.find()) {
			if (m.start() > lastIdx) {
				tokens.add(text.substring(lastIdx, m.start()));
			}
			tokens.add(m.group());
			lastIdx = m.end();
		}
		if (lastIdx < text.length()) {
			tokens.add(text.substring(lastIdx));
		}

		List<String> marks = new List<String>();
		for (Object tokObj : tokens) {
			String token = String.valueOf(tokObj);
			if (token == '<b>') {
				marks.add('strong');
			} else if (token == '</b>') {
				if (!marks.isEmpty()) {
					marks.remove(marks.size()-1);
				}
			} else if (token == '<i>') {
				marks.add('em');
			} else if (token == '</i>') {
				if (!marks.isEmpty()) {
					marks.remove(marks.size()-1);
				}
			} else if (token == '<u>') {
				marks.add('underline');
			} else if (token == '</u>') {
				if (!marks.isEmpty()) {
					marks.remove(marks.size()-1);
				}
			} else if (!String.isBlank(token)) {
				Map<String, Object> node = new Map<String, Object>{
					'type' => 'text',
					'text' => token
				};
				if (!marks.isEmpty()) {
					List<Map<String, String>> adfMarks = new List<Map<String, String>>();
					for (String mark : marks) {
						adfMarks.add(new Map<String, String>{ 'type' => mark });
					}
					node.put('marks', adfMarks);
				}
				content.add(node);
			}
		}

		return new Map<String, Object>{
			'type' => 'paragraph',
			'content' => content
		};
	}


    private static String processFirstList(String html, List<Map<String, Object>> docContent) {
        // Find first <ul> or <ol>
        Pattern p = Pattern.compile('(?i)<(ul|ol)>([\\s\\S]*?)</\\1>');
        Matcher m = p.matcher(html);
        if (m.find()) {
            String listHtml = m.group();
            String tag = m.group(1).toLowerCase();
            List<Map<String, Object>> items = new List<Map<String, Object>>();
            Pattern li = Pattern.compile('(?i)<li>([\\s\\S]*?)</li>');
            Matcher mi = li.matcher(listHtml);
            while (mi.find()) {
                String itemText = stripTags(mi.group(1));
                Map<String, Object> liNode = buildParagraph(itemText);
                items.add(liNode);
            }
            docContent.add(new Map<String, Object>{
                'type' => (tag == 'ul' ? 'bulletList' : 'orderedList'),
                'content' => items
            });
            // Remove processed list from html
            html = html.substring(0, m.start()) + html.substring(m.end());
        }
        return html;
    }
}