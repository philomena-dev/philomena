/**
 * localStorage utils
 */

export const lastUpdatedSuffix = '__lastUpdated';

export default {

  set(key: string, value: unknown) {
    try {
      localStorage.setItem(key, JSON.stringify(value));
      return true;
    }
    catch {
      return false;
    }
  },

  get<Value = unknown>(key: string): Value | null {
    const value = localStorage.getItem(key);
    if (value === null) return null;
    try {
      return JSON.parse(value);
    }
    catch {
      return value as unknown as Value;
    }
  },

  remove(key: string) {
    try {
      localStorage.removeItem(key);
      return true;
    }
    catch {
      return false;
    }
  },

  // Watch changes to a specified key - returns value on change
  watch<Value = unknown>(key: string, callback: (value: Value | null) => void) {
    const handler = (event: StorageEvent) => {
      if (event.key === key) callback(this.get<Value>(key));
    };
    window.addEventListener('storage', handler);
    return () => window.removeEventListener('storage', handler);
  },

  // set() with an additional key containing the current time + expiration time
  setWithExpireTime(key: string, value: unknown, maxAge: number) {
    const lastUpdatedKey = key + lastUpdatedSuffix;
    const lastUpdatedTime = Date.now() + maxAge;

    return this.set(key, value) && this.set(lastUpdatedKey, lastUpdatedTime);
  },

  // Whether the value of a key set with setWithExpireTime() has expired
  hasExpired(key: string) {
    const lastUpdatedKey = key + lastUpdatedSuffix;
    const lastUpdatedTime = this.get<number>(lastUpdatedKey);

    return lastUpdatedTime === null || Date.now() > lastUpdatedTime;
  },

};
