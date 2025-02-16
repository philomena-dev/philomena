import { HistoryStore, HistoryRecord } from './store';

/**
 * Maximum number of records we keep in the history. If the limit is reached,
 * the least popular records will be removed to make space for new ones.
 */
const maxRecords = 1000;

/**
 * Maximum length of the input content we store in the history. If the input
 * exceeds this value it won't be saved in the history.
 */
const maxInputLength = 256;

/**
 * Input history is a mini DB limited in size and stored in the `localStorage`.
 * It provides a simple CRUD/watch API for the search history data.
 *
 * Note that `localStorage` is not transactional. Other browser tabs may modify
 * it concurrently, which may lead to version mismatches and potential TOCTOU
 * issues. However, search history data is not critical, and the probability of
 * concurrent usage patterns is almost 0. The worst thing that can happen in
 * such a rare scenario is that a search query may not be saved to the storage
 * or the search history may be temporarily disabled for the current session
 * until the page is reloaded or a newer version of the frontend code is loaded.
 */
export class InputHistory {
  private readonly store: HistoryStore;

  /**
   * The list of history records sorted by `updatedAt` in descending order.
   */
  private records: HistoryRecord[];

  constructor(store: HistoryStore) {
    this.store = store;

    const parsing = performance.now();
    this.records = store.read();

    const end = performance.now();
    console.debug(`Loading input history took ${end - parsing}ms. Records: ${this.records.length}.`);

    store.watch(records => {
      this.records = records;
    });
  }

  /**
   * Save the input into the history and commit it to the `localStorage`.
   */
  write(input: string) {
    // eslint-disable-next-line no-param-reassign
    input = input.trim();

    if (input === '') {
      return;
    }

    if (input.length > maxInputLength) {
      console.warn(`The input is too long to be saved in the search history (length: ${input.length}).`);
    }

    const record = this.records.find(historyRecord => historyRecord.content === input);

    if (record) {
      this.update(record);
    } else {
      this.insert(input);
    }

    this.store.write(this.records);
  }

  private update(record: HistoryRecord) {
    record.updatedAt = nowRfc3339();

    // The records were fully sorted before we updated one of them. Fixing up
    // a nearly sorted sequence with `sort()` should be blazingly ⚡️ fast.
    // Usually, standard `sort` implementations are optimized for this case.
    this.records.sort((a, b) => (b.updatedAt > a.updatedAt ? 1 : -1));
  }

  private insert(input: string) {
    if (this.records.length >= maxRecords) {
      // Bye-bye, least popular record! 👋 Nopony will miss you 🔪🩸
      this.records.pop();
    }

    const now = nowRfc3339();

    this.records.unshift({
      content: input,
      createdAt: now,
      updatedAt: now,
    });
  }

  listSuggestions(query: string, limit: number): string[] {
    const results = [];

    for (const record of this.records) {
      if (results.length >= limit) {
        break;
      }

      if (record.content.startsWith(query)) {
        results.push(record.content);
      }
    }

    return results;
  }
}

function nowRfc3339(): string {
  const date = new Date();
  // Second-level precision is enough for our use case.
  date.setMilliseconds(0);
  return date.toISOString().replace('.000Z', 'Z');
}
