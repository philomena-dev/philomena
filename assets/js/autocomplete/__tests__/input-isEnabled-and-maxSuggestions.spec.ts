import { AutocompletableInput } from '../input';

test('isEnabled: no condition => enabled; condition false => disabled; true => enabled', () => {
  // No condition
  const el1 = document.createElement('input');
  el1.setAttribute('data-autocomplete', 'properties');
  const ai1 = AutocompletableInput.fromElement(el1)!;
  expect(ai1.isEnabled()).toBe(true);

  // Condition false
  const el2 = document.createElement('input');
  el2.setAttribute('data-autocomplete', 'multi-tags');
  el2.setAttribute('data-autocomplete-condition', 'flag2');
  const ai2 = AutocompletableInput.fromElement(el2)!;
  expect(ai2.isEnabled()).toBe(false);

  // Condition true
  localStorage.setItem('flag2', JSON.stringify(true));
  const ai2b = AutocompletableInput.fromElement(el2)!;
  expect(ai2b.isEnabled()).toBe(true);
});

test('maxSuggestions: respects data attribute when present', () => {
  const el = document.createElement('input');
  el.setAttribute('data-autocomplete', 'multi-tags');
  el.setAttribute('data-autocomplete-max-suggestions', '5');

  const ai = AutocompletableInput.fromElement(el)!;
  expect(ai.maxSuggestions).toBe(5);
});

test('hasTagSuggestions false for properties inputs', () => {
  const el = document.createElement('input');
  el.setAttribute('data-autocomplete', 'properties');

  const ai = AutocompletableInput.fromElement(el)!;
  expect(ai.hasTagSuggestions()).toBe(false);
});
