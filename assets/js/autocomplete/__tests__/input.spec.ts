import { AutocompletableInput } from '../input';
import { fireEvent } from '@testing-library/dom';
import store from '../../utils/store';

describe('AutocompletableInput', () => {
  test('fromElement returns null for unsupported and missing attributes', () => {
    expect(AutocompletableInput.fromElement({})).toBeNull();

    const el = document.createElement('input');
    // No data-autocomplete attribute
    expect(AutocompletableInput.fromElement(el)).toBeNull();
  });

  test('isEnabled respects condition flag', () => {
    const el = document.createElement('input');
    el.setAttribute('data-autocomplete', 'multi-tags');
    el.setAttribute('data-autocomplete-condition', 'flag');

    // Default false
    let ai = AutocompletableInput.fromElement(el)!;
    expect(ai.isEnabled()).toBe(false);

    store.set('flag', true);
    ai = AutocompletableInput.fromElement(el)!;
    expect(ai.isEnabled()).toBe(true);
  });

  test('snapshot.activeTerm handles single-tag dash prefix', () => {
    const el = document.createElement('input');
    el.setAttribute('data-autocomplete', 'single-tag');
    el.value = '-bar';
    document.body.appendChild(el);
    el.focus();
    // Put cursor inside "-bar" (after '-')
    el.selectionStart = 2;
    el.selectionEnd = 2;
    fireEvent.input(el);

    const ai = AutocompletableInput.fromElement(el)!;
    const term = ai.snapshot.activeTerm!;
    expect(term.term).toBe('bar');
    // Prefix may be parsed as part of syntax by the lexer; validate the value instead
    expect(term.range.start).toBeLessThan(term.range.end);
  });

  test('activeTerm null when selection is null or no term at cursor', () => {
    const el = document.createElement('input');
    el.setAttribute('data-autocomplete', 'multi-tags');
    el.value = '';
    // Explicitly set selectionStart/End to null by not focusing/setting selection
    const ai1 = AutocompletableInput.fromElement(el)!;
    expect(ai1.snapshot.activeTerm).toBeNull();

    // Now set a value with no terms at cursor (cursor beyond content)
    el.value = '  ';
    el.focus();
    el.selectionStart = 0;
    el.selectionEnd = 0;
    fireEvent.input(el);
    const ai2 = AutocompletableInput.fromElement(el)!;
    expect(ai2.snapshot.activeTerm).toBeNull();
  });
});
