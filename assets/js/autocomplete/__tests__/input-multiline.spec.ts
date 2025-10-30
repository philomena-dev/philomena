import { AutocompletableInput } from '../input';
import { fireEvent } from '@testing-library/dom';

test('findActiveTerm respects multi-line boundaries and end-of-text', () => {
  const el = document.createElement('textarea');
  el.setAttribute('data-autocomplete', 'multi-tags');
  document.body.appendChild(el);
  // Two lines, cursor on the last line at the very end
  el.value = 'first line\nsecond';
  el.focus();
  el.selectionStart = el.value.length;
  el.selectionEnd = el.value.length;
  fireEvent.input(el);

  const ai = AutocompletableInput.fromElement(el)!;
  const term = ai.snapshot.activeTerm!;

  // Should capture the term from the last line fully
  expect(term.term).toBe('second');
  expect(term.range.end).toBe(el.value.length);
});
