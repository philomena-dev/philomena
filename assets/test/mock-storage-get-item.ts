export function mockStorageGetItem(valueGetter?: (key: string) => string | null): jest.SpyInstance {
  const storageGetItemSpy: jest.SpyInstance = jest.spyOn(Storage.prototype, 'getItem');

  beforeAll(() => {
    if (valueGetter) {
      storageGetItemSpy.mockImplementation(valueGetter);
    }
    else {
      storageGetItemSpy.mockReturnValue(null);
    }
  });

  afterEach(() => {
    storageGetItemSpy.mockClear();
  });

  afterAll(() => {
    storageGetItemSpy.mockRestore();
  });

  return storageGetItemSpy;
}
