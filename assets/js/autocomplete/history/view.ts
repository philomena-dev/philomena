import { TermSuggestion } from 'utils/suggestions';
import { InputHistory } from './history';
import { HistoryStore } from './store';
import { makeEl } from 'utils/dom';
/**
 * Stores a set of histories identified by their unique IDs.
 *
 * Instead, we could attach the history objects to the respective input HTML
 * elements by monkey-patching them, but that would look a bit uglier and otherwise
 * with this approach we wouldn't be able to share the same history object between
 * multiple input elements.
 */
class InputHistoriesPool {
  private histories = new Map<string, InputHistory>();

  load(historyId: string): InputHistory {
    const existing = this.histories.get(historyId);

    if (existing) {
      return existing;
    }

    const store = new HistoryStore(historyId);

    const newHistory = new InputHistory(store);
    this.histories.set(historyId, newHistory);

    return newHistory;
  }
}

type HistoryAutocompletableInputElement = (HTMLInputElement | HTMLTextAreaElement) & {
  dataset: { autocompleteHistoryId: string };
};

function hasHistoryAutocompletion(element: unknown): element is HistoryAutocompletableInputElement {
  return element instanceof HTMLInputElement && Boolean(element.dataset.autocompleteHistoryId);
}

const histories = new InputHistoriesPool();

export function listen(): InputHistoriesPool {
  // Only load the history for the input element when it gets focused.
  document.addEventListener('focusin', event => {
    if (!hasHistoryAutocompletion(event.target)) {
      return;
    }

    const historyId = event.target.dataset.autocompleteHistoryId;

    histories.load(historyId);
  });

  document.addEventListener('submit', event => {
    if (!(event.target instanceof HTMLFormElement)) {
      return;
    }

    const input = [...event.target.elements].find(hasHistoryAutocompletion);

    if (!input) {
      return;
    }

    const content = input.value.trim();

    histories.load(input.dataset.autocompleteHistoryId).write(content);
  });

  return histories;
}

export function listSuggestions(element: HTMLInputElement | HTMLTextAreaElement, limit: number): TermSuggestion[] {
  if (!hasHistoryAutocompletion(element)) {
    return [];
  }

  return histories
    .load(element.dataset.autocompleteHistoryId)
    .listSuggestions(element.value, limit)
    .map(result => {
      return {
        value: result.target,
        label: result.highlight(char => makeEl('strong', { innerText: char })),
      };
    });
}
