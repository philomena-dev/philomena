import { test, expect } from 'vitest';
import { AutocompletableInput } from '../input';

test('findActiveTerm returns null when cursor is on an empty line', () => {
  const el = document.createElement('textarea');
  el.setAttribute('data-autocomplete', 'multi-tags');
  document.body.appendChild(el);

  // Two lines, with the second line empty; cursor at the very end
  el.value = 'first line\n';
  el.focus();
  el.selectionStart = el.value.length;
  el.selectionEnd = el.value.length;

  const ai = AutocompletableInput.fromElement(el)!;
  expect(ai.snapshot.activeTerm).toBeNull();
});
