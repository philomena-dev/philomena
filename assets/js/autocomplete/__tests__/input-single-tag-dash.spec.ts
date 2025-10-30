import { test, expect } from 'vitest';
import { AutocompletableInput } from '../input';

test('single-tag mode treats leading dash as NOT operator (not prefix)', () => {
  const el = document.createElement('input');
  el.setAttribute('data-autocomplete', 'single-tag');
  el.value = '-pony';
  el.selectionStart = el.selectionEnd = el.value.length;

  const input = AutocompletableInput.fromElement(el)!;
  const active = input.snapshot.activeTerm!;

  expect(active.term).toBe('pony');
  // The lexer treats a leading '-' as NOT operator, so it is not part of the term content.
  // Therefore, prefix is empty in practice, and the active term starts after '-'.
  expect(active.prefix).toBe('');
  expect(active.range.start).toBe(1);
  expect(active.range.end).toBe(5);
});
