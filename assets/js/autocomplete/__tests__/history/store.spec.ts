import { expect, test, vi } from 'vitest';
import store from '../../../utils/store';
import { HistoryStore } from '../../history/store';

test('HistoryStore: unknown schema disables writes and yields empty records', () => {
  const key = 'history-store-unknown-schema';
  // Bypass typing to simulate an unknown schema version in storage
  (store as unknown as { set: (k: string, v: unknown) => void }).set(key, {
    schemaVersion: 999,
    records: ['keep'],
  });

  const hs = new HistoryStore(key);
  expect(hs.read()).toEqual([]);

  // Spy on store.set to ensure write is not attempted
  const setSpy = vi.spyOn(store, 'set');
  hs.write(['new']);
  expect(setSpy).not.toHaveBeenCalledWith(key, expect.anything());
  setSpy.mockRestore();
});

test('HistoryStore: read and write happy path', () => {
  const key = 'history-store-happy-path';
  store.set(key, { schemaVersion: 1 as const, records: ['a', 'b'] });

  const hs = new HistoryStore(key);
  expect(hs.read()).toEqual(['a', 'b']);

  hs.write(['x', 'y', 'z']);

  const saved = store.get<{ schemaVersion: 1; records: string[] }>(key);
  expect(saved).not.toBeNull();
  expect(saved!.schemaVersion).toBe(1);
  expect(saved!.records).toEqual(['x', 'y', 'z']);
});
