import { test, expect } from 'vitest';
import { AutocompletableInput } from '../input';

// On inputs like type=number, selectionStart/End are null in JSDOM. That should yield a null active term.
test('active term is null when selection is unavailable', () => {
  const el = document.createElement('input');
  el.setAttribute('data-autocomplete', 'multi-tags');
  el.type = 'number';
  el.value = 'pony';

  const input = AutocompletableInput.fromElement(el)!;
  expect(input.snapshot.activeTerm).toBeNull();
});
