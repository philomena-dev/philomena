/**
 * Simple image spoiler functionality.
 */

import { $, hideEl, showEl } from './utils/dom';
import { delegate, leftClick } from './utils/events';

function loadSpoilerAndTarget(event, target, cb) {
  const spoilerImage = $('.js-spoiler-image', target);
  const targetImage = $('.js-spoiler-target', target);

  if (!spoilerImage || !targetImage) return;
  
  event.preventDefault();

  cb(spoilerImage, targetImage);
}

function unspoiler(event, target) {
  loadSpoilerAndTarget(event, target, (spoilerImage, targetImage) => {
    hideEl(spoilerImage);
    showEl(targetImage);
  });
}

function spoiler(event, target) {
  loadSpoilerAndTarget(event, target, (spoilerImage, targetImage) => {
    showEl(spoilerImage);
    hideEl(targetImage);
  });
}

export function configureSpoilers() {
  switch (window.booru.spoilerType) {
  case 'click':
    delegate(document, 'click', {'.image-container': leftClick(unspoiler)});
    delegate(document, 'mouseleave', {'.image-container': spoiler});
    break;
  case 'hover':
    delegate(document, 'mouseenter', {'.image-container': unspoiler});
    delegate(document, 'mouseleave', {'.image-container': spoiler});
    break;
  default:
    break;
  }
}
