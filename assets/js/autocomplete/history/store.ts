import store from '../../utils/store';

export interface HistoryRecord {
  /**
   * The textual payload. It shapes the record's identity.
   */
  content: string;

  /**
   * Time when the content was first used, and thus the record was created.
   */
  createdAt: Date;

  /**
   * Time when the content was last used, and thus the record was updated.
   */
  updatedAt: Date;
}

/**
 * The root JSON object that contains the history records and is persisted to disk.
 */
interface History {
  /**
   * Used to track the version of the schema layout just in case we do any
   * breaking changes to this schema so that we can properly migrate old
   * search history data. It's also used to prevent older versions of
   * the frontend code from trying to use the newer schema they no nothing
   * about (extremely improbable, but just in case).
   */
  schemaVersion: 1;

  /**
   * The list of history records sorted by `updatedAt` in descending order.
   */
  records: HistoryRecord[];
}

/**
 * History store backend is responsible for parsing and serializing the data
 * to/from `localStorage`. It handles versioning of the schema, and transparently
 * disables writing to the storage if the schema version is unknown to prevent
 * data loss (extremely improbable, but just in case).
 */
export class HistoryStore {
  private writable: boolean = true;
  private readonly key: string;

  constructor(key: string) {
    this.key = key;
  }

  read(): HistoryRecord[] {
    return this.extractRecords(store.get<History>(this.key));
  }

  write(records: HistoryRecord[]): void {
    if (!this.writable) {
      return;
    }

    const history: History = {
      schemaVersion: 1,
      records,
    };

    const start = performance.now();
    store.set(this.key, history);

    const end = performance.now();
    console.debug(`Writing ${records.length} history records to the localStorage took ${end - start}ms.`);
  }

  watch(callback: (value: HistoryRecord[]) => void): void {
    store.watch<History>(this.key, history => {
      callback(this.extractRecords(history));
    });
  }

  /**
   * Extracts the records from the history. To do this, it first needs to migrate
   * the history object to the latest schema version if necessary.
   */
  private extractRecords(history: null | History): HistoryRecord[] {
    // `null` here means we are starting from the initial state (empty list of records).
    if (history === null) {
      return [];
    }

    // We have only one version at the time of this writing, so we don't need
    // to do any migration yet. The schema should always be at the version `1`.
    const latestSchemaVersion = 1;

    switch (history.schemaVersion) {
      case latestSchemaVersion:
        return history.records;
      default:
        // It's very unlikely that we ever hit this branch.
        console.warn(
          `Unknown search history schema version: '${history.schemaVersion}', while ` +
            `this frontend code was built with the maximum supported schema version ` +
            `'${latestSchemaVersion}'. The search history will be disabled for this ` +
            `session to prevent potential history data loss. The cause of the version ` +
            `mismatch may be that a newer version of the frontend code is running in a ` +
            `separate tab, or git commits supporting the newer schema version were ` +
            `mistakenly reverted in the source repository.`,
        );

        // Disallow writing to the storage to prevent data loss.
        this.writable = false;

        return [];
    }
  }
}
