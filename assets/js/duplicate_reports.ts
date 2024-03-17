/**
 * Interactive behavior for duplicate reports.
 */

import { assertNotNull, assertType } from './utils/assert';
import { $, $$ } from './utils/dom';

function setupDupeReports() {
  const [ onion, slider ] = $$('.onion-skin__image, .onion-skin__slider');
  const swipe = $('.swipe__image');

  if (swipe) {
    setupSwipe(assertType(swipe, SVGSVGElement));
  }

  if (onion) {
    setupOnionSkin(assertType(onion, SVGSVGElement), assertType(slider, HTMLInputElement));
  }
}

function setupSwipe(swipe: SVGSVGElement) {
  const [ clip, divider ] = $$('#clip rect, #divider', swipe);
  const { width } = swipe.viewBox.baseVal;

  function moveDivider({ clientX }: { clientX: number }) {
    // Move center to cursor
    const rect = swipe.getBoundingClientRect();
    const newX = (clientX - rect.left) * (width / rect.width);

    divider.setAttribute('x', `${newX}`);
    clip.setAttribute('width', `${newX}`);
  }

  swipe.addEventListener('mousemove', moveDivider);
}

function setupOnionSkin(onion: SVGSVGElement, slider: HTMLInputElement) {
  const target = assertNotNull($('#target', onion));

  function setOpacity() {
    target.setAttribute('opacity', slider.value);
  }

  setOpacity();
  slider.addEventListener('input', setOpacity);
}

export { setupDupeReports };
