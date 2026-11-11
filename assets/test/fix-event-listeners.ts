// Removes the event listeners that a test adds to the target after the test

export function fixEventListeners(t: EventTarget) {
  const added: Parameters<EventTarget['addEventListener']>[] = [];
  const addEventListener = t.addEventListener;

  beforeAll(() => {
    t.addEventListener = (...args: Parameters<EventTarget['addEventListener']>) => {
      added.push(args);
      addEventListener.apply(t, args);
    };
  });

  afterEach(() => {
    for (const args of added.splice(0)) t.removeEventListener(...args);
  });
}
