/**
 * Autocomplete.
 */

import { LocalAutocompleter } from '../utils/local-autocompleter';
import { getTermContexts } from '../match_query';
import store from '../utils/store';
import { TermContext } from '../query/lex';
import { $$ } from '../utils/dom';
import {
  formatLocalAutocompleteResult,
  fetchLocalAutocomplete,
  fetchSuggestions,
  SuggestionsPopup,
  Suggestion,
} from '../utils/suggestions';
import * as history from './history/view';

type AutocompletableInputElement = HTMLInputElement | HTMLTextAreaElement;

function hasAutocompleteEnabled(element: unknown): element is AutocompletableInputElement {
  return (
    (element instanceof HTMLInputElement || element instanceof HTMLTextAreaElement) &&
    Boolean(element.dataset.autocomplete)
  );
}

let inputField: AutocompletableInputElement | null = null;
let originalTerm: string | undefined;
let originalQuery: string | undefined;
let selectedTerm: TermContext | null = null;

const popup = new SuggestionsPopup();

function isSearchField(targetInput: HTMLElement): boolean {
  return targetInput.dataset.autocompleteMode === 'search';
}

function restoreOriginalValue() {
  if (!inputField) return;

  if (isSearchField(inputField) && originalQuery) {
    inputField.value = originalQuery;

    if (selectedTerm) {
      const [, selectedTermEnd] = selectedTerm[0];

      inputField.setSelectionRange(selectedTermEnd, selectedTermEnd);
    }

    return;
  }

  if (originalTerm) {
    inputField.value = originalTerm;
  }
}

function applySelectedValue(selection: string) {
  if (!inputField) return;

  if (!isSearchField(inputField)) {
    let resultValue = selection;

    if (originalTerm?.startsWith('-')) {
      resultValue = `-${selection}`;
    }

    inputField.value = resultValue;
    return;
  }

  if (selectedTerm && originalQuery) {
    const [startIndex, endIndex] = selectedTerm[0];
    inputField.value = originalQuery.slice(0, startIndex) + selection + originalQuery.slice(endIndex);
    inputField.setSelectionRange(startIndex + selection.length, startIndex + selection.length);
    inputField.focus();
  }
}

function isSelectionOutsideCurrentTerm(): boolean {
  if (!inputField || !selectedTerm) return true;
  if (inputField.selectionStart === null || inputField.selectionEnd === null) return true;

  const selectionIndex = Math.min(inputField.selectionStart, inputField.selectionEnd);
  const [startIndex, endIndex] = selectedTerm[0];

  return startIndex > selectionIndex || endIndex < selectionIndex;
}

function keydownHandler(event: KeyboardEvent) {
  if (inputField !== event.currentTarget) return;

  if (inputField && isSearchField(inputField)) {
    // Prevent submission of the search field when Enter was hit
    if (popup.selectedTerm && event.keyCode === 13) event.preventDefault(); // Enter

    // Close autocompletion popup when text cursor is outside current tag
    if (selectedTerm && (event.keyCode === 37 || event.keyCode === 39)) {
      // ArrowLeft || ArrowRight
      requestAnimationFrame(() => {
        if (isSelectionOutsideCurrentTerm()) popup.hide();
      });
    }
  }

  if (!popup.isActive) return;

  if (event.keyCode === 38) popup.selectPrevious(); // ArrowUp
  if (event.keyCode === 40) popup.selectNext(); // ArrowDown
  if (event.keyCode === 13 || event.keyCode === 27 || event.keyCode === 188) popup.hide(); // Enter || Esc || Comma
  if (event.keyCode === 38 || event.keyCode === 40) {
    // ArrowUp || ArrowDown
    if (popup.selectedTerm) {
      applySelectedValue(popup.selectedTerm);
    } else {
      restoreOriginalValue();
    }

    event.preventDefault();
  }
}

function findSelectedTerm(targetInput: AutocompletableInputElement, searchQuery: string): TermContext | null {
  if (targetInput.selectionStart === null || targetInput.selectionEnd === null) return null;

  const selectionIndex = Math.min(targetInput.selectionStart, targetInput.selectionEnd);

  // Multi-line textarea elements should treat each line as the different search queries. Here we're looking for the
  // actively edited line and use it instead of the whole value.
  const activeLineStart = searchQuery.slice(0, selectionIndex).lastIndexOf('\n') + 1;
  const lengthAfterSelectionIndex = Math.max(searchQuery.slice(selectionIndex).indexOf('\n'), 0);
  const targetQuery = searchQuery.slice(activeLineStart, selectionIndex + lengthAfterSelectionIndex);

  const terms = getTermContexts(targetQuery);
  const searchIndex = selectionIndex - activeLineStart;
  const term = terms.find(([range]) => range[0] < searchIndex && range[1] >= searchIndex) ?? null;

  // Converting line-specific indexes back to absolute ones.
  if (term) {
    const [range] = term;

    range[0] += activeLineStart;
    range[1] += activeLineStart;
  }

  return term;
}

/**
 * Our custom autocomplete isn't compatible with the native browser autocomplete,
 * so we have to turn it off if our autocomplete is enabled, or turn it back on
 * if it's disabled.
 */
function toggleSearchNativeAutocomplete() {
  const enable = store.get('enable_search_ac');

  const searchFields = $$<AutocompletableInputElement>(
    ':is(input, textarea)[data-autocomplete][data-autocomplete-mode=search]',
  );

  for (const searchField of searchFields) {
    if (enable) {
      searchField.autocomplete = 'off';
    } else {
      searchField.removeAttribute('data-autocomplete');
      searchField.autocomplete = 'on';
    }
  }
}

function trimPrefixes(targetTerm: string): string {
  return targetTerm.trim().replace(/^-/, '');
}

/**
 * We control the autocomplete with `data-autocomplete*` attributes in HTML, and subscribe
 * event listeners to the `document`. This pattern is described in more detail
 * here: https://javascript.info/event-delegation
 */
export function listenAutocomplete() {
  history.listen();

  let serverSideSuggestionsTimeout: number | undefined;

  let localAutocomplete: LocalAutocompleter | null = null;

  document.addEventListener('focusin', event => suggest(event.target));
  document.addEventListener('input', event => suggest(event.target));

  // Lazy-load the local autocomplete index from the server only once.
  let localAutocompleteFetchNeeded = true;

  async function loadLocalAutocomplete() {
    if (!localAutocompleteFetchNeeded) {
      return;
    }

    localAutocompleteFetchNeeded = false;
    localAutocomplete = await fetchLocalAutocomplete();
  }

  suggest(document.activeElement);

  function suggest(element: unknown) {
    if (!hasAutocompleteEnabled(element)) return;

    loadLocalAutocomplete();
    window.clearTimeout(serverSideSuggestionsTimeout);

    // This is a crutch to make `Ctrl+Shift+C` + click on completion item work
    // when debugging the completions in devtools in browser. For some reason when
    // you select a completion HTML element this way a `focusin` event is triggered
    // against the input element again.
    if (popup.isActive && inputField === element && originalQuery === element.value) {
      return;
    }

    popup.hide();

    const targetedInput = element;

    targetedInput.addEventListener('keydown', keydownHandler as EventListener);

    inputField = targetedInput;

    let suggestionsLimit;

    if (isSearchField(targetedInput)) {
      suggestionsLimit = 10;
      originalQuery = targetedInput.value;
      selectedTerm = findSelectedTerm(targetedInput, originalQuery);
      originalTerm = selectedTerm?.[1].toLowerCase();
    } else {
      suggestionsLimit = 5;
      originalTerm = targetedInput.value.toLowerCase();
    }

    // Show all most recent history suggestions if the input is empty
    if (targetedInput.value.trim() === '') {
      const historySuggestions = history.listSuggestions(targetedInput, suggestionsLimit);
      popup.renderSuggestions(historySuggestions, []).showForField(targetedInput);
      return;
    }

    const historySuggestions = history.listSuggestions(targetedInput, 3);
    let termSuggestions: Suggestion[] = [];

    if (localAutocomplete !== null) {
      if (originalTerm) {
        termSuggestions = localAutocomplete
          .matchPrefix(trimPrefixes(originalTerm), suggestionsLimit - historySuggestions.length)
          .map(formatLocalAutocompleteResult);
      }
    }

    if (termSuggestions.length !== 0) {
      popup.renderSuggestions(historySuggestions, termSuggestions).showForField(targetedInput);
      return;
    }

    popup.renderSuggestions(historySuggestions, []).showForField(targetedInput);

    const { autocompleteMinLength: minTermLength, autocompleteSource: endpointUrl } = targetedInput.dataset;

    if (!endpointUrl) return;

    // Use a timeout to delay requests until the user has stopped typing
    serverSideSuggestionsTimeout = window.setTimeout(() => {
      originalTerm = targetedInput.value;

      const fetchedTerm = trimPrefixes(targetedInput.value);

      if (minTermLength && fetchedTerm.length < parseInt(minTermLength, 10)) return;

      fetchSuggestions(endpointUrl, fetchedTerm).then(serverSuggestions => {
        // inputField could get overwritten while the suggestions are being fetched - use previously targeted input
        if (fetchedTerm === trimPrefixes(targetedInput.value)) {
          popup.renderSuggestions(historySuggestions, serverSuggestions).showForField(targetedInput);
        }
      });
    }, 300);
  }

  // If there's a click outside the inputField, remove autocomplete
  document.addEventListener('click', event => {
    if (event.target && event.target !== inputField) popup.hide();
  });

  toggleSearchNativeAutocomplete();

  popup.onItemSelected((event: CustomEvent<Suggestion>) => {
    if (!event.detail || !inputField) return;

    const originalSuggestion = event.detail;
    applySelectedValue(originalSuggestion.value);

    if (originalTerm?.startsWith('-')) {
      originalSuggestion.value = `-${originalSuggestion.value}`;
    }

    inputField.dispatchEvent(
      new CustomEvent<Suggestion>('autocomplete', {
        detail: Object.assign(
          {
            type: 'click',
          },
          originalSuggestion,
        ),
      }),
    );
  });
}
