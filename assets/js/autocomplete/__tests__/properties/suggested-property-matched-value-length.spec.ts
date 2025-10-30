import { test, expect } from 'vitest';
import { SuggestedProperty, type MatchedPropertyParts } from '../../properties';

// Covers calculateMatchedLength branch where value syntax with concrete typed value contributes to highlight length
test('calculateMatchedLength includes typed value length with colon', () => {
  const parts: MatchedPropertyParts = {
    propertyName: 'uploader',
    hasOperatorSyntax: false,
    hasValueSyntax: true,
    operator: undefined,
    value: 'artist',
  };

  const sp = new SuggestedProperty(parts, 'uploader', null, null, 'artist');
  // matched length = propertyName (8) + ':' (1) + value (6)
  expect(sp.calculateMatchedLength()).toBe(8 + 1 + 6);
  expect(sp.toString()).toBe('uploader:artist');
});
