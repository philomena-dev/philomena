import { LocalAutocompleter } from '../../utils/local-autocompleter';
import * as history from '../history/view';
import { AutocompletableInput, TextInputElement } from './input';
import {
  fetchLocalAutocomplete,
  SuggestionsPopup,
  Suggestions,
  TagSuggestion,
  Suggestion,
  HistorySuggestion,
} from '../../utils/suggestions';
import { $$ } from '../../utils/dom';

class Autocomplete {
  localAutocompleter: 'fetching' | 'unavailable' | LocalAutocompleter | null = null;
  input: AutocompletableInput | null = null;
  popup = new SuggestionsPopup();

  constructor() {
    this.popup.onItemSelected(this.onItemSelected.bind(this));
  }

  /**
   * Lazy-load the local autocomplete data.
   */
  async fetchLocalAutocomplete() {
    if (this.localAutocompleter) {
      // The autocompleter is already either fetching or initialized, so nothing to do.
      return;
    }

    // Indicate that the autocompleter is in the process of fetching so that
    // we don't try to fetch it again while it's still loading.
    this.localAutocompleter = 'fetching';
    try {
      this.localAutocompleter = await fetchLocalAutocomplete();
      this.refresh();
    } catch (error) {
      this.localAutocompleter = 'unavailable';
      console.error('Failed to fetch local autocomplete data', error);
    }
  }

  refresh(event) {
    console.log('refresh', event);

    this.input = AutocompletableInput.fromElement(document.activeElement);
    if (!this.isEnabled()) {
      // If the input is not enabled, we don't need to show the popup.
      this.popup.hide();
      return;
    }

    const { input } = this;

    // Initiate the lazy local autocomplete fetch if it hasn't been done yet.
    this.fetchLocalAutocomplete();

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

    // There may be several scenarios here:
    //
    // 1. The `localAutocompleter` is still `fetching`.
    //    We should wait until it's done. Doing concurrent server-side suggestions
    //    request in this case would be optimistically wasteful.
    //
    // 2. The `localAutocompleter` is `unavailable`.
    //    We shouldn't fetch server suggestions either because there may be something
    //    horribly wrong on the backend, so we don't want to spam it with even more
    //    requests. This scenario should be extremely rare though.
    //
    // 3. The `localAutocompleter` was loaded (Flutter-Yay 🎉).
    if (!(this.localAutocompleter instanceof LocalAutocompleter)) {
      return;
    }

    const activeTerm = input.snapshot.activeTerm.term;

    suggestions.tags = this.localAutocompleter
      .matchPrefix(activeTerm, input.maxSuggestions - suggestions.history.length)
      .map(result => new TagSuggestion({ ...result, matchLength: activeTerm.length }));

    // Only if the local autocompleter had its chance to provide suggestions
    // and produced nothing, do we try to fetch server suggestions.
    if (suggestions.tags.length === 0) {
      // TODO: fetch server suggestions. Use the min length of the term 3 as a condition as well.
      // TODO: clicking on history item should submit the form right away?
    }

    this.popup.setSuggestions(suggestions).showForElement(input.element);
  }

  onFocusIn(event) {
    console.log('focusin', event);
    if (this.popup.isHidden) {
      // The event we are processing comes before the input's selection is settled.
      // Defer the refresh to the next frame to get the updated selection.
      requestAnimationFrame(() => this.refresh());
    }
  }

  onClick(event: MouseEvent) {
    console.log('click', event);
    if (this.input?.isEnabled() && this.input.element !== event.target) {
      // We lost focus. Hide the popup.
      // We use this method instead of the `focusout` event because this way it's
      // easier to work in the developer tools when you want to inspect the element.
      // When you inspect it, a `focusout` happens.
      this.popup.hide();
      this.input = null;
    }
  }

  onKeyDown(event: KeyboardEvent) {
    if (!this.isEnabled() || this.input.element !== event.target) {
      return;
    }

    switch (event.code) {
      case 'Enter': {
        // Prevent submission of the search field when Enter was hit
        if (this.popup.selectedSuggestion) {
          event.preventDefault();
          this.popup.hide();
        }
        return;
      }
      case 'Escape': {
        this.popup.hide();
        return;
      }
      case 'ArrowLeft':
      case 'ArrowRight': {
        // The event we are processing comes before the input's selection changes.
        // Defer the refresh to the next frame to get the updated selection.
        requestAnimationFrame(() => this.refresh());
        return;
      }
      case 'ArrowUp':
      case 'ArrowDown': {
        if (event.code === 'ArrowUp') {
          if (event.ctrlKey) {
            this.popup.selectCtrlUp();
          } else {
            this.popup.selectUp();
          }
        } else {
          if (event.ctrlKey) {
            this.popup.selectCtrlDown();
          } else {
            this.popup.selectDown();
          }
        }

        if (this.popup.selectedSuggestion) {
          this.updateInputWithSelectedValue(this.popup.selectedSuggestion);
        } else {
          // Restore the original input state
          const { element, snapshot } = this.input;
          const { selection } = snapshot;
          element.value = snapshot.origValue;
          // eslint-disable-next-line no-undefined
          element.setSelectionRange(selection.start, selection.end, selection.direction ?? undefined);
        }

        // Prevent the cursor from moving to the start or end of the input field,
        // which is the default behavior of the arrow keys are used in a text input.
        event.preventDefault();

        return;
      }
      default:
    }
  }

  onItemSelected(event: CustomEvent<Suggestion>) {
    this.assertEnabled();

    const { detail: suggestion } = event;

    this.updateInputWithSelectedValue(suggestion);

    const prefix = this.input.snapshot.activeTerm?.prefix ?? '';

    const detail = `${prefix}${suggestion.value()}`;

    const newEvent = new CustomEvent<string>('autocomplete', { detail });

    this.input.element.dispatchEvent(newEvent);
  }

  updateInputWithSelectedValue(this: Autocomplete & { input: AutocompletableInput }, suggestion: Suggestion) {
    const {
      element,
      snapshot: { activeTerm, origValue },
    } = this.input;

    const value = suggestion.value();

    if (!activeTerm || suggestion instanceof HistorySuggestion) {
      element.value = value;
      return;
    }

    const { range, prefix } = activeTerm;

    element.value = origValue.slice(0, range.start) + prefix + value + origValue.slice(range.end);

    const newCursorIndex = range.start + value.length;
    element.setSelectionRange(newCursorIndex, newCursorIndex);
  }

  isEnabled(): this is this & { input: AutocompletableInput } {
    return Boolean(this.input?.isEnabled());
  }

  assertEnabled(): asserts this is this & { input: AutocompletableInput } {
    if (this.isEnabled()) {
      return;
    }

    console.debug('Current input', this.input);
    throw new Error(`Expected enabled autocomplete, but it's not enabled`);
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

  // By the time this script loads, the input elements may already be focused,
  // so we refresh the autocomplete state immediately to trigger the initial completions.
  autocomplete.refresh();

  document.addEventListener('focusin', autocomplete.onFocusIn.bind(autocomplete));
  document.addEventListener('input', autocomplete.refresh.bind(autocomplete));
  document.addEventListener('click', autocomplete.onClick.bind(autocomplete));
  document.addEventListener('keydown', autocomplete.onKeyDown.bind(autocomplete));
}
