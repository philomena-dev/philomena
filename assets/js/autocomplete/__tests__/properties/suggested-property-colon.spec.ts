import { expect, test } from 'vitest';
import { SuggestedProperty, type MatchedPropertyParts } from '../../properties';

test('SuggestedProperty: toString includes colon when operator is empty and matched length accounts for colon', () => {
  const matched: MatchedPropertyParts = {
    propertyName: 'score',
    hasOperatorSyntax: true,
    hasValueSyntax: true,
    operator: '',
    value: undefined,
  };

  // operator "" means we suggest just a colon next
  const sp = new SuggestedProperty(matched, 'score', Symbol('number'), '', null);

  expect(sp.containsColon()).toBe(true);
  expect(sp.toString()).toBe('score:');

  // matched length highlights property name and the ":"
  expect(sp.calculateMatchedLength()).toBe('score:'.length);
});
