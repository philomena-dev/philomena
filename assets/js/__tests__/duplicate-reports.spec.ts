import { setupDupeReports } from '../duplicate-reports';
import { needsChromiumJpegNormalization, replaceFilterImageHrefIfNeeded } from '../utils/browser-workarounds';
import { fixEventListeners } from '../../test/fix-event-listeners';

vi.mock('../utils/browser-workarounds');
fixEventListeners(document);

afterEach(() => {
  document.body.innerHTML = '';
  vi.resetAllMocks();
});

it.each([true, false])('normalizes both difference filter images only for Chromium: %s', chromium => {
  document.body.innerHTML = `
    <svg><filter><feImage id="source"/><feImage id="target"/></filter></svg>
    <svg><image id="source"/><image id="target"/></svg>`;
  vi.mocked(needsChromiumJpegNormalization).mockReturnValue(chromium);

  setupDupeReports();

  expect(needsChromiumJpegNormalization).toHaveBeenCalledOnce();
  const expectedCalls = chromium
    ? [[document.querySelector('feImage#source')], [document.querySelector('feImage#target')]]
    : [];
  expect(vi.mocked(replaceFilterImageHrefIfNeeded).mock.calls).toEqual(expectedCalls);
});

it.each(['', '<feImage id="source"/>', '<feImage id="target"/>'])(
  'skips normalization without a complete filter pair: %s',
  markup => {
    document.body.innerHTML = `<svg><filter>${markup}</filter></svg>`;
    setupDupeReports();
    expect(needsChromiumJpegNormalization).not.toHaveBeenCalled();
    expect(replaceFilterImageHrefIfNeeded).not.toHaveBeenCalled();
  },
);
