import { test, expect } from 'vitest';
import { SuggestedProperty, type MatchedPropertyParts } from '../../properties';

// When operator syntax is present and an operator is typed, matched length includes '.' and operator,
// and when value syntax is present but value is not, ':' is also included.
test('calculateMatchedLength includes ".", operator, and ":" when operator is typed', () => {
  const parts: MatchedPropertyParts = {
    propertyName: 'score',
    hasOperatorSyntax: true,
    hasValueSyntax: true,
    operator: 'gt',
    value: undefined,
  };

  const sp = new SuggestedProperty(parts, 'score', Symbol('number'), 'gt', null);

  // matched length = 'score' (5) + '.' (1) + 'gt' (2) + ':' (1) = 9
  expect(sp.calculateMatchedLength()).toBe(9);
  expect(sp.toString()).toBe('score.gt:');
});
