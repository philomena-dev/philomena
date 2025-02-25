import { LocalAutocompleter } from '../utils/local-autocompleter';
import * as history from './history';
import { AutocompletableInput, TextInputElement } from './input';
import {
  SuggestionsPopup,
  Suggestions,
  TagSuggestion,
  Suggestion,
  HistorySuggestion,
  ItemSelectedEvent,
} from '../utils/suggestions';
import { $$ } from '../utils/dom';
import { AutocompleteClient, GetTagSuggestionsRequest } from './client';
import { DebouncedCache } from './debounced-cache';
import store from '../utils/store';

// eslint-disable-next-line no-use-before-define
type ActiveAutocomplete = Autocomplete & { input: AutocompletableInput };

function readHistoryConfig() {
  if (store.get<boolean>('autocomplete_search_history_hidden')) {
    return null;
  }

  return {
    maxSuggestionsWhenTyping: store.get<number>('autocomplete_search_history_max_suggestions_when_typing') ?? 3,
  };
}

class Autocomplete {
  index: 'fetching' | 'unavailable' | LocalAutocompleter | null = null;
  input: AutocompletableInput | null = null;
  popup = new SuggestionsPopup();
  client = new AutocompleteClient();

  serverSideTagSuggestions = new DebouncedCache(this.client.getTagSuggestions.bind(this.client));

  constructor() {
    this.popup.onItemSelected(this.confirmSuggestion.bind(this));
  }

  /**
   * Lazy-load the local autocomplete data.
   */
  async fetchLocalAutocomplete() {
    if (this.index) {
      // The index is already either fetching or initialized, so nothing to do.
      return;
    }

    // Indicate that the index is in the process of fetching so that
    // we don't try to fetch it again while it's still loading.
    this.index = 'fetching';
    try {
      const index = await this.client.getCompiledAutocomplete();
      this.index = new LocalAutocompleter(index);
      this.refresh();
    } catch (error) {
      this.index = 'unavailable';
      console.error('Failed to fetch local autocomplete data', error);
    }
  }

  refresh(event?: Event) {
    this.serverSideTagSuggestions.abortLastSchedule('[Autocomplete] A new user input was received');

    console.debug('refresh', event);

    this.input = AutocompletableInput.fromElement(document.activeElement);
    if (!this.isActive()) {
      // If the input is not enabled, we don't need to show the popup.
      this.popup.hide();
      return;
    }

    const { input } = this;

    // Initiate the lazy local autocomplete fetch if it hasn't been done yet.
    this.fetchLocalAutocomplete();

    const historyConfig = readHistoryConfig();

    // Show all history suggestions if the input is empty.
    if (historyConfig && input.snapshot.normalizedValue === '') {
      this.showSuggestions({
        history: history.listSuggestions(input),
        tags: [],
      });
      return;
    }

    // When the input is not empty the history suggestions take up
    // only a small portion of the suggestions.
    const suggestions: Suggestions = {
      history: historyConfig ? history.listSuggestions(input, historyConfig.maxSuggestionsWhenTyping) : [],
      tags: [],
    };

    // There may be several scenarios here:
    //
    // 1. The `index` is still `fetching`.
    //    We should wait until it's done. Doing concurrent server-side suggestions
    //    request in this case would be optimistically wasteful.
    //
    // 2. The `index` is `unavailable`.
    //    We shouldn't fetch server suggestions either because there may be something
    //    horribly wrong on the backend, so we don't want to spam it with even more
    //    requests. This scenario should be extremely rare though.
    //
    // 3. The `index` was loaded (Flutter-Yay 🎉).
    if (
      !input.snapshot.activeTerm ||
      !(this.index instanceof LocalAutocompleter) ||
      suggestions.history.length === this.input.maxSuggestions
    ) {
      this.showSuggestions(suggestions);
      return;
    }

    const activeTerm = input.snapshot.activeTerm.term;

    suggestions.tags = this.index
      .matchPrefix(activeTerm, input.maxSuggestions - suggestions.history.length)
      .map(result => new TagSuggestion({ ...result, matchLength: activeTerm.length }));

    // Used for debugging server-side completions, to ensure local autocomplete
    // doesn't prevent sever-side completions from being shown. Use these console
    // commands to enable/disable server-side completions:
    // ```js
    // localStorage.setItem('SERVER_SIDE_COMPLETIONS_ONLY', true)
    // localStorage.removeItem('SERVER_SIDE_COMPLETIONS_ONLY')
    // ```
    if (store.get('SERVER_SIDE_COMPLETIONS_ONLY')) {
      suggestions.tags = [];
    }

    // Show suggestions that we arledy have early without waiting for a potential
    // server-side suggestions request.
    this.showSuggestions(suggestions);

    // Only if the index had its chance to provide suggestions
    // and produced nothing, do we try to fetch server suggestions.
    if (suggestions.tags.length > 0 || activeTerm.length < 3) {
      return;
    }

    this.scheduleServerSideSuggestions(activeTerm, suggestions.history);
  }

  scheduleServerSideSuggestions(this: ActiveAutocomplete, term: string, historySuggestions: HistorySuggestion[]) {
    const request: GetTagSuggestionsRequest = {
      term,
      limit: this.input.maxSuggestions - historySuggestions.length,
    };

    this.serverSideTagSuggestions.schedule(request, response => {
      if (!this.isActive()) {
        return;
      }

      this.showSuggestions({
        history: historySuggestions,
        tags: response.suggestions.map(
          suggestion =>
            new TagSuggestion({
              ...suggestion,
              matchLength: term.length,
            }),
        ),
      });
    });
  }

  showSuggestions(this: ActiveAutocomplete, suggestions: Suggestions) {
    this.popup.setSuggestions(suggestions).showForElement(this.input.element);
  }

  onFocusIn(event?: FocusEvent) {
    console.debug('focusin', event);
    if (this.popup.isHidden) {
      // The event we are processing comes before the input's selection is settled.
      // Defer the refresh to the next frame to get the updated selection.
      requestAnimationFrame(() => this.refresh());
    }
  }

  onClick(event: MouseEvent) {
    console.debug('click', event);
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
    if (!this.isActive() || this.input.element !== event.target) {
      return;
    }

    if ((event.key === ',' || event.code === 'Enter') && this.input.type === 'single-tag') {
      // Coma means the end of input for the current tag in single-tag mode.
      this.popup.hide();
      return;
    }

    switch (event.code) {
      case 'Enter': {
        const { selectedSuggestion } = this.popup;
        if (selectedSuggestion) {
          // Prevent submission of the form when Enter was hit.
          // Note, however, that `confirmSuggestion` may still submit the form
          // manually if the selected suggestion is a history suggestion and
          // no `Shift` key was pressed.
          event.preventDefault();

          this.confirmSuggestion({
            suggestion: selectedSuggestion,
            shiftKey: event.shiftKey,
            ctrlKey: event.ctrlKey,
          });
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

  confirmSuggestion({ suggestion, shiftKey, ctrlKey }: ItemSelectedEvent) {
    this.assertActive();

    this.updateInputWithSelectedValue(suggestion);

    const prefix = this.input.snapshot.activeTerm?.prefix ?? '';

    const detail = `${prefix}${suggestion.value()}`;

    const newEvent = new CustomEvent<string>('autocomplete', { detail });

    this.input.element.dispatchEvent(newEvent);

    if (ctrlKey || (suggestion instanceof HistorySuggestion && !shiftKey)) {
      this.input.element.form?.submit();
    }

    this.popup.hide();
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

  isActive(): this is ActiveAutocomplete {
    return Boolean(this.input?.isEnabled());
  }

  assertActive(): asserts this is ActiveAutocomplete {
    if (this.isActive()) {
      return;
    }

    console.debug('Current input when the error happened', this.input);
    throw new Error(`Expected active autocomplete, but it isn't`);
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

export function listenAutocomplete() {
  history.listen();

  const autocomplete = new Autocomplete();

  store.watchAll(key => {
    if (!key || (key !== 'enable_search_ac' && !key.startsWith('autocomplete'))) {
      return;
    }

    refreshNativeAutocomplete();
    autocomplete.refresh();
  });

  refreshNativeAutocomplete();

  // By the time this script loads, the input elements may already be focused,
  // so we refresh the autocomplete state immediately to trigger the initial completions.
  autocomplete.refresh();

  document.addEventListener('focusin', autocomplete.onFocusIn.bind(autocomplete));
  document.addEventListener('input', autocomplete.refresh.bind(autocomplete));
  document.addEventListener('click', autocomplete.onClick.bind(autocomplete));
  document.addEventListener('keydown', autocomplete.onKeyDown.bind(autocomplete));
}
