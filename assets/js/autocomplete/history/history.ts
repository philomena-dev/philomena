import { HistoryStore, HistoryRecord } from './store';
import fuzzysort from 'fuzzysort';

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
 * This class tracks the search history under the specified `historyId` key.
 * It takes care of versioning and schema migrations, and provides a simple
 * CRUD/watch API for the search history data.
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

  /**
   * The length of this array must be equal to the length of `records`.
   * Every element has a corresponding record from the `records` array.
   * This list is fed to the fuzzy search algorithm to speed up the search.
   */
  private index: Fuzzysort.Prepared[];

  constructor(store: HistoryStore) {
    this.store = store;

    const parsing = performance.now();
    this.records = store.read();

    const indexing = performance.now();
    this.index = this.reindex();

    const end = performance.now();
    console.debug(
      `Loading input history took ${end - parsing}ms. ` +
        `Parsing: ${indexing - parsing}ms. ` +
        `Indexing: ${end - indexing}ms.`,
    );

    store.watch(records => {
      this.records = records;
      this.index = this.reindex();
    });
  }

  reindex(): Fuzzysort.Prepared[] {
    return this.records.map(record => fuzzysort.prepare(record.content));
  }

  /**
   * Save the input into the history and commit it to the `localStorage`.
   */
  write(input: string) {
    if (this.records === null) {
      return;
    }

    if (input.length > maxInputLength) {
      console.warn(`The input is too long to be saved in the search history (length: ${input.length}.`);
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
    record.updatedAt = new Date();

    // The records were fully sorted before we updated one of them. Fixing up
    // a nearly sorted sequence with `sort()` should be blazingly ⚡️ fast.
    // Usually, standard `sort` implementations are optimized for this case.
    this.records.sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());
  }

  private insert(input: string) {
    if (this.records.length >= maxRecords) {
      // Bye-bye, least popular record! 👋 Nopony will miss you 🔪🩸
      this.records.pop();
    }

    const now = new Date();

    this.records.unshift({
      content: input,
      createdAt: now,
      updatedAt: now,
    });

    // Today this isn't required, because after a new record is added, the
    // page is going to be re-rendered anyway, but preparing just one record
    // should be fast enough to not worry about it. In return we guarantee
    // the consistency of the `index` array with the `records` array.
    this.index.unshift(fuzzysort.prepare(input));
  }

  listSuggestions(query: string, limit: number): readonly Fuzzysort.Result[] {
    return fuzzysort.go(query, this.index, {
      limit,

      // 0 is a perfect match and -1000 is the worst match.
      threshold: -500,

      // Return all results for an empty search no matter what's the threshold.
      all: true,
    });
  }
}
