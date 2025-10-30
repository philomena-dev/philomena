import { expect, test } from 'vitest';
import { SuggestedProperty, type MatchedPropertyParts, matchProperties } from '../../properties';
import type { LocalAutocompleter } from '../../../utils/local-autocompleter';
import { AutocompletableInput } from '../../input';

test('operatorless ":" suggestion is created and matched length includes ":" and typed value length', () => {
  // Build a properties-type input in the image search context (name: 'q')
  const el = document.createElement('input');
  el.name = 'q';
  el.value = 'score:1';
  el.setAttribute('data-autocomplete', 'properties');
  // Place cursor at the end so active term is detected
  el.setSelectionRange(el.value.length, el.value.length);

  const input = AutocompletableInput.fromElement(el)!;

  // Call the high-level matcher to ensure the empty-operator suggestion is added when only ':' is present
  const stub: Pick<LocalAutocompleter, 'matchPrefix'> = {
    // LocalAutocompleter is unused for numeric properties; provide minimal stub
    matchPrefix: () => [],
  };
  const suggestions = matchProperties(input, 'score:1', stub as unknown as LocalAutocompleter);

  // The first suggestion should be the variant without an explicit operator (empty string)
  const first = suggestions[0];
  expect(first).toBeInstanceOf(SuggestedProperty);
  expect(first.operator).toBe('');
  // toString should include the colon and the typed value when present
  expect(first.toString()).toBe('score:1');

  // Now validate matched length logic for the operatorless+colon case using the same matchedParts
  const parts: MatchedPropertyParts = {
    propertyName: 'score',
    hasOperatorSyntax: false,
    hasValueSyntax: true,
    operator: undefined,
    value: '1',
  };
  const sp = new SuggestedProperty(parts, 'score', null, '', '');
  // matched length = len('score') + ':' (1) + len(typed value '1')
  expect(sp.calculateMatchedLength()).toBe('score'.length + 1 + '1'.length);
});
