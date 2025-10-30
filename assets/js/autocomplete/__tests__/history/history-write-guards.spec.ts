import { expect, test, vi } from 'vitest';
import store from '../../../utils/store';
import { HistoryStore } from '../../history/store';
import { InputHistory } from '../../history/history';

test('InputHistory: write ignores empty and overly long inputs', () => {
  const key = 'history-write-guards';
  const hs = new InputHistory(new HistoryStore(key));

  // Empty input
  hs.write('');
  expect((store as unknown as { get: (k: string) => unknown }).get(key)).toBeNull();

  // Overly long input
  const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {});
  hs.write('x'.repeat(300));
  expect((store as unknown as { get: (k: string) => unknown }).get(key)).toBeNull();
  expect(warnSpy).toHaveBeenCalled();
  warnSpy.mockRestore();
});
