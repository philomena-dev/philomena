import { Suggestion } from 'utils/suggestions';
import { InputHistory } from './history';
import { HistoryStore } from './store';
import { makeEl } from '../../utils/dom';

/**
 * Stores a set of histories identified by their unique IDs.
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
  return (
    (element instanceof HTMLInputElement || element instanceof HTMLTextAreaElement) &&
    Boolean(element.dataset.autocompleteHistoryId)
  );
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

export function listSuggestions(element: HTMLInputElement | HTMLTextAreaElement, limit: number): Suggestion[] {
  if (!hasHistoryAutocompletion(element)) {
    return [];
  }

  const query = element.value.trim();

  return histories
    .load(element.dataset.autocompleteHistoryId)
    .listSuggestions(query, limit)
    .map(result => {
      const icon = makeEl('i', {
        className: 'autocomplete-item-history__icon fa-solid fa-history',
      });

      const prefix = makeEl('span', {
        textContent: ` ${query}`,
        className: 'autocomplete-item-history__match',
      });

      const suffix = makeEl('span', {
        textContent: result.slice(query.length),
      });

      return {
        value: result,
        label: [icon, prefix, suffix],
      };
    });
}
