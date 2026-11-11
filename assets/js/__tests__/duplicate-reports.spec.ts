import { setupDupeReports } from '../duplicate-reports';
import { needsChromiumJpegNormalization, replaceFilterImageHrefIfNeeded } from '../utils/browser-workarounds';
import { fixEventListeners } from '../../test/fix-event-listeners';
import { assertNotNull } from '../utils/assert';
import { $ } from '../utils/dom';
import { fireEvent } from '@testing-library/dom';
import { MockInstance } from 'vitest';

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

describe('onion skin', () => {
  beforeEach(() => {
    document.body.innerHTML = `
      <svg class="onion-skin-image"><image id="source"/><image id="target"/></svg>
      <input class="js-onion-skin-slider" type="range" min="0" max="1" step="0.01" value="0.5">
      <button class="js-onion-skin-button">0%</button>
      <button class="js-onion-skin-button">100%</button>`;
    setupDupeReports();
  });

  const target = () => assertNotNull($<SVGImageElement>('#target'));
  const slider = () => assertNotNull($<HTMLInputElement>('.js-onion-skin-slider'));

  it('shows the target at the opacity of the slider and fills the track up to it', () => {
    expect(target().getAttribute('opacity')).toBe('0.5');

    fireEvent.input(slider(), { target: { value: '0.25' } });

    expect(target().getAttribute('opacity')).toBe('0.25');
    expect(slider().style.getPropertyValue('--slider-fill')).toBe('25%');
  });

  it('jumps to the source or the target with the buttons', () => {
    const [sourceButton, targetButton] = document.querySelectorAll<HTMLButtonElement>('.js-onion-skin-button');

    targetButton.click();
    expect(target().getAttribute('opacity')).toBe('1');
    expect(slider().style.getPropertyValue('--slider-fill')).toBe('100%');

    sourceButton.click();
    expect(target().getAttribute('opacity')).toBe('0');
  });
});

describe('key bindings', () => {
  let swipeClick: MockInstance;

  beforeEach(() => {
    document.body.innerHTML = `
      <button class="js-onion-skin-button"></button>
      <button class="js-onion-skin-button"></button>
      <button class="js-comparison-button"></button>
      <button class="js-comparison-button"></button>
      <button class="js-comparison-button"></button>
      <button class="js-comparison-button" id="swipe"></button>
      <button class="js-comparison-button"></button>
      <input type="text">`;
    swipeClick = vi.spyOn(assertNotNull($<HTMLButtonElement>('#swipe')), 'click');
    setupDupeReports();
  });

  it('clicks the bound button on a plain key press', () => {
    fireEvent.keyDown(document, { key: 'k', keyCode: 75 });
    expect(swipeClick).toHaveBeenCalledOnce();
  });

  it('ignores keys typed into a text field', () => {
    const input = assertNotNull($<HTMLInputElement>('input'));
    input.focus();
    fireEvent.keyDown(input, { key: 'k', keyCode: 75 });
    expect(swipeClick).not.toHaveBeenCalled();
  });

  it('ignores keys pressed with a modifier', () => {
    fireEvent.keyDown(document, { key: 'k', keyCode: 75, ctrlKey: true });
    expect(swipeClick).not.toHaveBeenCalled();
  });
});
