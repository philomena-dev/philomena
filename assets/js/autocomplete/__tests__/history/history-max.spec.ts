import { expect, test } from 'vitest';
import store from '../../../utils/store';
import { HistoryStore } from '../../history/store';
import { InputHistory } from '../../history/history';

// Covers history.ts branch where maxRecords cap triggers dropping the oldest entry
test('InputHistory drops the oldest record when max is reached', () => {
  const key = 'search-history';

  // Pre-populate the history with 1000 items (maxRecords)
  const existing = Array.from({ length: 1000 }, (_, i) => `q${i}`);
  store.set(key, { schemaVersion: 1, records: existing });

  const history = new InputHistory(new HistoryStore(key));

  // Writing a new value should evict the oldest one and keep size at 1000
  history.write('new-query');

  const saved = store.get<{ schemaVersion: 1; records: string[] }>(key);
  expect(saved).not.toBeNull();
  expect(saved!.records.length).toBe(1000);
  expect(saved!.records[0]).toBe('new-query');
  // The oldest one should have been dropped
  expect(saved!.records.includes('q999')).toBe(false);
});
