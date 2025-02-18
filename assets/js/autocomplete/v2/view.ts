import { LocalAutocompleter } from '../../utils/local-autocompleter';
import * as history from '../history/view';
import { AutocompletableInput, TextInputElement } from './input';
import {
  fetchLocalAutocomplete,
  SuggestionsDropdown,
  Suggestions,
  TagSuggestion,
  Suggestion,
  HistorySuggestion,
} from '../../utils/suggestions';
import { $$ } from '../../utils/dom';

class Autocomplete {
  input: AutocompletableInput | null = null;
  localAutocompleter: 'fetching' | 'unavailable' | LocalAutocompleter | null = null;
  popup = new SuggestionsDropdown();

  constructor() {
    this.popup.onItemSelected(this.onItemSelected.bind(this));
  }

  /**
   * Layzy-load the local autocomplete data.
   */
  async fetchLocalAutocomplete() {
    if (this.localAutocompleter) {
      // The autocompleter is already either fetching or initialized, nothing to do.
      return;
    }

    // Indicate that the autocompleter is in the process of fetching so that
    // we don't try to fetch it again while it's still loading.
    this.localAutocompleter = 'fetching';
    try {
      this.localAutocompleter = await fetchLocalAutocomplete();
    } catch (error) {
      this.localAutocompleter = 'unavailable';
      console.error('Failed to fetch local autocomplete data:', error);
    }
  }

  refresh(event?: Event) {
    console.log('refresh()', event?.type);

    // TODO: avoid rerenders. E.g. if multiple events like focusin and click are received
    // this.popup.hide();

    // Initiate the lazy local autocomplete fetch if it hasn't been done yet.
    this.fetchLocalAutocomplete();

    const input = AutocompletableInput.fromElement(document.activeElement);
    this.input = input;

    if (!input?.isEnabled()) {
      this.input = null;
      this.popup.hide();
      return;
    }

    // Show all history suggestions if the input is empty.
    if (input.snapshot.trimmedValue === '') {
      this.popup
        .setSuggestions({
          history: history.listSuggestions(input),
          tags: [],
        })
        .showForElement(input.element);
      return;
    }

    // When the input is not empty the history suggestions take up
    // only a small portion of the suggestions.
    const suggestions: Suggestions = {
      history: history.listSuggestions(input, 3),
      tags: [],
    };

    if (!input.snapshot.activeTerm) {
      this.popup.setSuggestions(suggestions).showForElement(input.element);
      return;
    }

    if (this.localAutocompleter instanceof LocalAutocompleter) {
      const activeTerm = input.snapshot.activeTerm.term;

      suggestions.tags = this.localAutocompleter
        .matchPrefix(activeTerm, input.maxSuggestions - suggestions.history.length)
        .map(result => new TagSuggestion({ ...result, matchLength: activeTerm.length }));
    }

    // Only if the local autocompleter had its chance to provide suggestions
    // and produced nothing, do we try to fetch server suggestions.
    if (this.localAutocompleter && this.localAutocompleter !== 'fetching' && suggestions.tags.length === 0) {
      // TODO: fetch server suggestions. Use the min length of the term 3 as a condition as well.
      // TODO: clicking on history item should submit the form right away?
    }

    this.popup.setSuggestions(suggestions).showForElement(input.element);
  }

  onKeyDown(event: KeyboardEvent) {
    if (!this.input?.isEnabled() || this.input.element !== event.target) return;

    // Prevent submission of the search field when Enter was hit
    if (this.popup.selectedSuggestion && event.code === 'Enter') {
      event.preventDefault();
    }

    if (event.code === 'ArrowLeft' || event.code === 'ArrowRight') {
      this.refresh();
      return;
    }

    if (!this.input) return;

    if (event.code === 'Enter' || event.code === 'Escape') {
      this.popup.hide();
      return;
    }

    if (event.code === 'ArrowUp' || event.code === 'ArrowDown') {
      if (event.code === 'ArrowUp') this.popup.selectPrevious();
      if (event.code === 'ArrowDown') this.popup.selectNext();

      if (this.popup.selectedSuggestion) {
        this.updateInputWithSelectedValue(this.popup.selectedSuggestion);
      } else {
        // Restore the original input state
        const { element, snapshot } = this.input;
        element.value = snapshot.origValue;
        element.setSelectionRange(snapshot.selection.start, snapshot.selection.end);
      }

      event.preventDefault();
    }
  }

  onItemSelected(event: CustomEvent<Suggestion>) {
    const input = this.unwrapInput();

    const { detail: suggestion } = event;

    this.updateInputWithSelectedValue(suggestion);

    const prefix = input.snapshot.activeTerm?.prefix ?? '';

    const detail = `${prefix}${suggestion.value()}`;

    const newEvent = new CustomEvent<string>('autocomplete', { detail });

    input.element.dispatchEvent(newEvent);
  }

  updateInputWithSelectedValue(suggestion: Suggestion) {
    const {
      element,
      snapshot: { activeTerm, origValue },
    } = this.unwrapInput();

    const value = suggestion.value();

    if (!activeTerm || suggestion instanceof HistorySuggestion) {
      element.value = value;
      element.focus();
      return;
    }

    const { range, prefix } = activeTerm;

    element.value = origValue.slice(0, range.start) + prefix + value + origValue.slice(range.end);

    const newCursorIndex = range.start + value.length;

    element.setSelectionRange(newCursorIndex, newCursorIndex);
    element.focus();
  }

  unwrapInput(): AutocompletableInput {
    if (!this.input) {
      throw new Error(`Expected an active input element, but it is ${this.input}`);
    }
    return this.input;
  }
}

/**
 * Our custom autocomplete isn't compatible with the native browser autocomplete,
 * so we have to turn it off if our autocomplete is enabled, or turn it back on
 * if it's disabled.
 */
function refreshNativeAutocomplete() {
  const elements = $$<TextInputElement>(':is(input, textarea)[data-autocomplete][data-autocomplete-condition]');

  for (const element of elements) {
    const input = AutocompletableInput.fromElement(element);
    if (!input) {
      continue;
    }

    element.autocomplete = input.isEnabled() ? 'off' : 'on';
  }
}

export function listenAutocompleteV2() {
  history.listen();

  // TODO: refresh autocomplete when the store value changes
  refreshNativeAutocomplete();

  const autocomplete = new Autocomplete();

  // By the time this script loads, the input elements might already be focused,
  // so we refresh the autocomplete state immediately to trigger the initial completions.
  autocomplete.refresh();

  document.addEventListener('focusin', autocomplete.refresh.bind(autocomplete));
  document.addEventListener('input', autocomplete.refresh.bind(autocomplete));
  document.addEventListener('click', autocomplete.refresh.bind(autocomplete));
  document.addEventListener('keydown', autocomplete.onKeyDown.bind(autocomplete));
}
