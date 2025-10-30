import { describe, expect, it } from 'vitest';
import { AutocompletableInput } from '../input';

// Covers the constructor guard for invalid autocomplete type
describe('AutocompletableInput invalid type', () => {
  it('throws when data-autocomplete has an unknown value', () => {
    const el = document.createElement('input');
    el.dataset.autocomplete = 'unknown-type';
    // Must set a condition attribute so the element is considered AC-capable
    el.dataset.autocompleteCondition = 'enable_search_ac';

    document.body.appendChild(el);

    expect(() => AutocompletableInput.fromElement(el)).toThrow(/invalid autocomplete type/);
  });
});
