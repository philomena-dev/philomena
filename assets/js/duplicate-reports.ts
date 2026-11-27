/**
 * Interactive behavior for duplicate reports.
 */

import { assertNotNull } from './utils/assert';
import { needsChromiumJpegNormalization, replaceFilterImageHrefIfNeeded } from './utils/browser-workarounds';
import { $, $$, makeEl } from './utils/dom';
import { isShortcutEvent, keys, normalizedKeyboardKey } from './utils/keyboard';

export function setupDupeReports() {
  const diffImageSource = $<SVGFEImageElement>('feImage#source');
  const diffImageTarget = $<SVGFEImageElement>('feImage#target');
  if (diffImageSource && diffImageTarget) {
    setupBrowserWorkarounds(diffImageSource, diffImageTarget);
  }

  const diff = $<SVGSVGElement>('.difference__image');
  const onion = $<SVGSVGElement>('.onion-skin__image');
  const slider = $<HTMLInputElement>('.onion-skin__slider');
  const swipe = $<SVGSVGElement>('.swipe__image');

  if (swipe) setupSwipe(swipe);
  if (onion && slider) setupOnionSkin(onion, slider);

  setupZoomForImages(diff, swipe, onion);
  setupKeyBindings();

  document.addEventListener('fetchcomplete', mergeDuplicateReportTable);
}

function setupBrowserWorkarounds(source: SVGFEImageElement, target: SVGFEImageElement) {
  if (!needsChromiumJpegNormalization()) return;
  replaceFilterImageHrefIfNeeded(source);
  replaceFilterImageHrefIfNeeded(target);
}

function setupSwipe(swipe: SVGSVGElement) {
  const [clip, divider] = $$<SVGRectElement>('#clip rect, #divider', swipe);
  const { width } = swipe.viewBox.baseVal;

  function moveDivider({ clientX }: MouseEvent) {
    // Move center to cursor
    const rect = swipe.getBoundingClientRect();
    const newX = (clientX - rect.left) * (width / rect.width);

    divider.setAttribute('x', newX.toString());
    clip.setAttribute('width', newX.toString());
  }

  swipe.addEventListener('mousemove', moveDivider);
}

function setupOnionSkin(onion: SVGSVGElement, slider: HTMLInputElement) {
  const target = assertNotNull($<SVGImageElement>('#target', onion));
  const [sourceButton, targetButton] = $$<HTMLButtonElement>('.onion-skin__button');

  slider.addEventListener('input', setOpacity);

  function setOpacity() {
    target.setAttribute('opacity', slider.value);
  }

  function setSliderAndOpacity(value: number) {
    slider.value = `${value}`;
    setOpacity();
  }

  setOpacity();

  sourceButton.addEventListener('click', () => {
    setSliderAndOpacity(0);
  });
  targetButton.addEventListener('click', () => {
    setSliderAndOpacity(1);
  });
}

function setupKeyBindings() {
  const onionSkinButtons = $$<HTMLButtonElement>('.onion-skin__button');
  if (onionSkinButtons.length !== 2) return;

  const [onionSkinSourceButton, onionSkinTargetButton] = onionSkinButtons;

  const navigationButtons = $$<HTMLButtonElement>('.comparison--navigation__button');
  if (navigationButtons.length !== 5) return;

  const [
    _navigationSourceButton,
    _navigationTargetButton,
    subtractiveDifferenceButton,
    swipeDifferenceButton,
    onionSkinDifferenceButton,
  ] = navigationButtons;

  const actions = {
    [keys.KeyJ]: () => subtractiveDifferenceButton.click(),
    [keys.KeyK]: () => swipeDifferenceButton.click(),
    [keys.KeyL]: () => onionSkinDifferenceButton.click(),
    [keys.Comma]: () => onionSkinSourceButton.click(),
    [keys.Period]: () => onionSkinTargetButton.click(),
  };

  document.addEventListener('keydown', (event: KeyboardEvent) => {
    const key = normalizedKeyboardKey(event);

    if (isShortcutEvent(event) && actions[key]) {
      actions[key]();
    }
  });
}

function mergeDuplicateReportTable({ target, detail }: FetchcompleteEvent) {
  if (!target.matches('.js-duplicate-report')) {
    return;
  }

  const container = makeEl('template');

  detail.text().then(text => {
    container.innerHTML = text;

    for (const child of container.content.children) {
      if (!(child instanceof HTMLElement)) continue;

      for (const updateTarget of document.querySelectorAll(`.${child.className}`)) {
        updateTarget.outerHTML = child.outerHTML;
      }
    }
  });
}

function setupZoomForImages(...zoomableElements: (Element | null)[]) {
  for (const zoomableElement of zoomableElements) {
    if (!(zoomableElement instanceof SVGElement)) continue;

    const zoomableContainer = zoomableElement?.closest('.zoomable');
    if (!(zoomableContainer instanceof HTMLElement)) continue;

    initializeZoom(zoomableContainer, zoomableElement);
  }
}

function clamp(minValue: number, value: number, maxValue: number) {
  return Math.min(Math.max(minValue, value), maxValue);
}

/**
 * Setting up zoom for each of the duplicate report image diffs.
 *
 * Zooming is configured as Ctrl + MouseWheel, while panning can be done by regular vertical/horizontal scroll.
 *
 * @param container Outer container.
 * @param imageElement Element that should be zoomed.
 */
function initializeZoom(container: HTMLElement, imageElement: SVGElement) {
  const maxZoomPower = 5;

  let zoomPower = 0,
    zoomRatio = 1,
    offsetX: number | null = null,
    offsetY: number | null = null;

  const applyZoomAndScrollOffset = () => {
    // Just to be safer, on the first refresh we should force the static height for the container.
    container.style.height ||= `${container.offsetHeight}px`;
    imageElement.style.zoom = zoomRatio.toString();

    // When scroll offset compensation is required, apply it.
    if (offsetX !== null || offsetY !== null) {
      const scrollOptions: ScrollToOptions = {
        behavior: 'instant',
      };

      if (offsetX !== null) {
        scrollOptions.left = offsetX;
        offsetX = null;
      }

      if (offsetY !== null) {
        scrollOptions.top = offsetY;
        offsetY = null;
      }

      container.scrollTo(scrollOptions);
    }
  };

  container.addEventListener('wheel', wheelEvent => {
    if (!wheelEvent.ctrlKey) return;

    wheelEvent.preventDefault();

    const anyScrollDelta = wheelEvent.deltaX || wheelEvent.deltaY;
    const zoomRatioDirection = (anyScrollDelta > 0 && -1) || (anyScrollDelta < 0 && 1) || 0;

    if (!zoomRatioDirection) return;

    // To make it so image is zoomed in centered on cursor, we need to figure out where it's located.
    // Should avoid using this one for other calculations, since it depends on the browser global zoom, fine for
    // calculating ratio.
    const containerRect = container.getBoundingClientRect();

    let cursorRatioX = (wheelEvent.clientX - containerRect.x) / containerRect.width;
    let cursorRatioY = (wheelEvent.clientY - containerRect.y) / containerRect.height;

    cursorRatioX = clamp(0, cursorRatioX, 1);
    cursorRatioY = clamp(0, cursorRatioY, 1);

    const cursorOffsetX = container.offsetWidth * cursorRatioX;
    const cursorOffsetY = container.offsetHeight * cursorRatioY;

    // Zooming using top-left corner + cursor offset
    const baseZoomOffsetX = (container.scrollLeft + cursorOffsetX) / zoomRatio;
    const baseZoomOffsetY = (container.scrollTop + cursorOffsetY) / zoomRatio;

    // Changing the zoom
    zoomPower += zoomRatioDirection;
    zoomPower = clamp(0, zoomPower, maxZoomPower);
    zoomRatio = Math.pow(2, zoomPower);

    // And then applying the zoom and un-compensating cursor offset back
    offsetX = baseZoomOffsetX * zoomRatio - cursorOffsetX;
    offsetY = baseZoomOffsetY * zoomRatio - cursorOffsetY;

    applyZoomAndScrollOffset();
  });
}
