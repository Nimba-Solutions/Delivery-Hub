@isTest
private class HtmlToAdfConverterTest {

    /**
     * @description Test conversion of a simple paragraph with no formatting.
     */
    @isTest
    static void testConvert_SimpleParagraph() {
        String html = '<p>This is a simple paragraph.</p>';
        Map<String, Object> adf = HtmlToAdfConverter.convert(html);

        // Build expected structure
        List<Object> expectedContent = new List<Object>{
            new Map<String, Object>{
                'type' => 'paragraph',
                'content' => new List<Object>{
                    new Map<String, Object>{'type' => 'text', 'text' => 'This is a simple paragraph.'}
                }
            }
        };

        System.assertEquals('doc', adf.get('type'));
        System.assertEquals(1, adf.get('version'));
        System.assertEquals(JSON.serialize(expectedContent), JSON.serialize(adf.get('content')));
    }

    /**
     * @description Test conversion of text with bold and italic marks.
     */
    @isTest
    static void testConvert_WithMarks() {
        String html = '<p>This is <b>bold</b> and <i>italic</i> text.</p>';
        Map<String, Object> adf = HtmlToAdfConverter.convert(html);

        // Build expected structure
        List<Object> expectedContent = new List<Object>{
            new Map<String, Object>{
                'type' => 'paragraph',
                'content' => new List<Object>{
                    new Map<String, Object>{'type' => 'text', 'text' => 'This is '},
                    new Map<String, Object>{'type' => 'text', 'text' => 'bold', 'marks' => new List<Object>{new Map<String, Object>{'type' => 'strong'}}},
                    new Map<String, Object>{'type' => 'text', 'text' => ' and '},
                    new Map<String, Object>{'type' => 'text', 'text' => 'italic', 'marks' => new List<Object>{new Map<String, Object>{'type' => 'em'}}},
                    new Map<String, Object>{'type' => 'text', 'text' => ' text.'}
                }
            }
        };
        
        System.assertEquals(JSON.serialize(expectedContent), JSON.serialize(adf.get('content')));
    }

    /**
     * @description Test conversion of an unordered list (ul).
     */
    @isTest
    static void testConvert_UnorderedList() {
        String html = '<ul><li>Item 1</li><li>Item 2</li></ul>';
        Map<String, Object> adf = HtmlToAdfConverter.convert(html);

        // Build expected structure
        List<Object> expectedContent = new List<Object>{
            new Map<String, Object>{
                'type' => 'bulletList',
                'content' => new List<Object>{
                    new Map<String, Object>{'type' => 'paragraph', 'content' => new List<Object>{new Map<String, Object>{'type' => 'text', 'text' => 'Item 1'}}},
                    new Map<String, Object>{'type' => 'paragraph', 'content' => new List<Object>{new Map<String, Object>{'type' => 'text', 'text' => 'Item 2'}}}
                }
            }
        };

        System.assertEquals(JSON.serialize(expectedContent), JSON.serialize(adf.get('content')));
    }

    /**
     * @description Test conversion of an ordered list (ol).
     */
    @isTest
    static void testConvert_OrderedList() {
        String html = '<ol><li>First</li><li>Second</li></ol>';
        Map<String, Object> adf = HtmlToAdfConverter.convert(html);

        // Build expected structure
        List<Object> expectedContent = new List<Object>{
            new Map<String, Object>{
                'type' => 'orderedList',
                'content' => new List<Object>{
                    new Map<String, Object>{'type' => 'paragraph', 'content' => new List<Object>{new Map<String, Object>{'type' => 'text', 'text' => 'First'}}},
                    new Map<String, Object>{'type' => 'paragraph', 'content' => new List<Object>{new Map<String, Object>{'type' => 'text', 'text' => 'Second'}}}
                }
            }
        };

        System.assertEquals(JSON.serialize(expectedContent), JSON.serialize(adf.get('content')));
    }

    /**
     * @description Test conversion of mixed content including paragraphs and lists.
     */
    @isTest
    static void testConvert_MixedContent() {
        String html = '<p>Intro</p><ul><li>Point A</li></ul><p>Conclusion</p>';
        Map<String, Object> adf = HtmlToAdfConverter.convert(html);

        System.assertNotEquals(null, adf);
        List<Map<String, Object>> content = (List<Map<String, Object>>)adf.get('content');
        System.assertEquals(3, content.size(), 'Should have three content blocks: p, ul, p.');
        //System.assertEquals('paragraph', content[0].get('type'));
        //System.assertEquals('bulletList', content[1].get('type'));
        //System.assertEquals('paragraph', content[2].get('type'));
    }

    /**
     * @description Test that unsafe tags like <script> are stripped.
     */
    @isTest
    static void testConvert_StripsUnsafeTags() {
        String html = '<p>Safe text</p><script>alert("unsafe!");</script>';
        Map<String, Object> adf = HtmlToAdfConverter.convert(html);
        
        String json = JSON.serialize(adf);
        System.assert(!json.contains('unsafe'), 'Script content should be stripped.');
    }

    /**
     * @description Test with empty and blank string inputs.
     */
    @isTest
    static void testConvert_EmptyAndBlankInput() {
        // Test with empty string
        Map<String, Object> adfEmpty = HtmlToAdfConverter.convert('');
        List<Map<String, Object>> contentEmpty = (List<Map<String, Object>>)adfEmpty.get('content');
        System.assertEquals(1, contentEmpty.size());
        System.assertEquals('paragraph', contentEmpty[0].get('type'));

        // Test with null string
        Map<String, Object> adfNull = HtmlToAdfConverter.convert(null);
        List<Map<String, Object>> contentNull = (List<Map<String, Object>>)adfNull.get('content');
        System.assertEquals(1, contentNull.size());
    }
    
    /**
     * @description Test with underline and strong tags.
     */
    @isTest
    static void testConvert_UnderlineAndStrong() {
        String html = '<p><u>Underlined</u> and <strong>strong</strong> text.</p>';
        Map<String, Object> adf = HtmlToAdfConverter.convert(html);
        
        List<Object> expectedContent = new List<Object>{
            new Map<String, Object>{
                'type' => 'paragraph',
                'content' => new List<Object>{
                    new Map<String, Object>{'type' => 'text', 'text' => 'Underlined', 'marks' => new List<Object>{new Map<String, Object>{'type' => 'underline'}}},
                    new Map<String, Object>{'type' => 'text', 'text' => ' and '},
                    new Map<String, Object>{'type' => 'text', 'text' => 'strong', 'marks' => new List<Object>{new Map<String, Object>{'type' => 'strong'}}},
                    new Map<String, Object>{'type' => 'text', 'text' => ' text.'}
                }
            }
        };

        System.assertEquals(JSON.serialize(expectedContent), JSON.serialize(adf.get('content')));
    }
}
