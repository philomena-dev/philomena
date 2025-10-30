import { expect, test } from 'vitest';
import { AutocompletableInput } from '../input';

test('findActiveTerm range accounts for multiline offsets', () => {
  const ta = document.createElement('textarea');
  ta.setAttribute('data-autocomplete', 'multi-tags');
  ta.value = 'hello\nworld';

  // Place cursor inside the second line ("world"), after "wo"
  ta.selectionStart = 9; // index of 'r' in 'world' (lineStart is 6)
  ta.selectionEnd = 9;

  const input = AutocompletableInput.fromElement(ta);
  expect(input).not.toBeNull();

  const active = input!.snapshot.activeTerm;
  expect(active).not.toBeNull();

  // The whole term is "world" with correct absolute range
  expect(active!.term).toBe('world');
  expect(active!.range.start).toBe(6);
  expect(active!.range.end).toBe(11);
});
