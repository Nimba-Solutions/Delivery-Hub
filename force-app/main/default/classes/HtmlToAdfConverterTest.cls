@isTest
private class HtmlToAdfConverterTest {

    /**
     * @description Test conversion of a simple paragraph with no formatting.
     */
    @isTest
    static void testConvertSimpleParagraph() {
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

        System.assertEquals('doc', adf.get('type'), 'ADF type should be doc');
        System.assertEquals(1, adf.get('version'), 'ADF version should be 1');
        System.assertEquals(JSON.serialize(expectedContent), JSON.serialize(adf.get('content')), 'ADF content should match expected structure');
    }

    /**
     * @description Test conversion of text with bold and italic marks.
     */
    @isTest
    static void testConvertWithMarks() {
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
        
        System.assertEquals(JSON.serialize(expectedContent), JSON.serialize(adf.get('content')), 'ADF content should include bold and italic marks');
    }

    /**
     * @description Test conversion of an unordered list (ul).
     */
    @isTest
    static void testConvertUnorderedList() {
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

        System.assertEquals(JSON.serialize(expectedContent), JSON.serialize(adf.get('content')), 'ADF content should include unordered list structure');
    }

    /**
     * @description Test conversion of an ordered list (ol).
     */
    @isTest
    static void testConvertOrderedList() {
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

        System.assertEquals(JSON.serialize(expectedContent), JSON.serialize(adf.get('content')), 'ADF content should include ordered list structure');
    }

    /**
     * @description Test conversion of mixed content including paragraphs and lists.
     */
    @isTest
    static void testConvertMixedContent() {
        String html = '<p>Intro</p><ul><li>Point A</li></ul><p>Conclusion</p>';
        Map<String, Object> adf = HtmlToAdfConverter.convert(html);

        System.assertNotEquals(null, adf, 'ADF should not be null');
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
    static void testConvertStripsUnsafeTags() {
        String html = '<p>Safe text</p><script>alert("unsafe!");</script>';
        Map<String, Object> adf = HtmlToAdfConverter.convert(html);
        
        String json = JSON.serialize(adf);
        System.assert(!json.contains('unsafe'), 'Script content should be stripped.');
    }

    /**
     * @description Test with empty and blank string inputs.
     */
    @isTest
    static void testConvertEmptyAndBlankInput() {
        // Test with empty string
        Map<String, Object> adfEmpty = HtmlToAdfConverter.convert('');
        List<Map<String, Object>> contentEmpty = (List<Map<String, Object>>)adfEmpty.get('content');
        System.assertEquals(1, contentEmpty.size(), 'Empty input should create one paragraph');
        System.assertEquals('paragraph', contentEmpty[0].get('type'), 'Content type should be paragraph');

        // Test with null string
        Map<String, Object> adfNull = HtmlToAdfConverter.convert(null);
        List<Map<String, Object>> contentNull = (List<Map<String, Object>>)adfNull.get('content');
        System.assertEquals(1, contentNull.size(), 'Null input should create one paragraph');
    }
    
    /**
     * @description Test with underline and strong tags.
     */
    @isTest
    static void testConvertUnderlineAndStrong() {
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

        System.assertEquals(JSON.serialize(expectedContent), JSON.serialize(adf.get('content')), 'ADF content should include underline and strong marks');
    }
    
    /**
     * @description Explicitly tests the processFirstList method by providing 
     * both list types (ul and ol) in a single HTML string. This ensures 
     * the while loop and regex logic are fully exercised.
     */
    @isTest
    static void testProcessFirstListCoverage() {
        // We put text between lists to ensure the substring/removal logic works correctly
        String html = '<ul><li>Bullet Item</li></ul>' + 
                      '<p>Spacer</p>' + 
                      '<ol><li>Ordered Item</li></ol>';

        Test.startTest();
        Map<String, Object> result = HtmlToAdfConverter.convert(html);
        Test.stopTest();

        // Verify the structure
        List<Object> content = (List<Object>)result.get('content');
        
        // We expect 3 nodes: bulletList, paragraph, orderedList
        System.assertEquals(3, content.size(), 'Should have parsed three content blocks');

        // Check 1: Bullet List
        Map<String, Object> node1 = (Map<String, Object>)content[0];
        System.assertEquals('bulletList', node1.get('type'), 'First node should be bulletList');
        List<Object> node1Content = (List<Object>)node1.get('content');
        System.assertEquals(1, node1Content.size());
    }
}