/**
 * Slider Logic
 *
 * Provides functionality for <input type="dualrange">
 *
 * Example usage:
 *
 * <input type="dualrange" min="0" max="100" valuemin="0" valuemax="100">
 */

import { $$ } from './utils/dom';

function lerp(delta: number, from: number, to: number): number {
  if (delta >= 1) { return to; }
  else if (delta <= 0) { return from; }

  return from + (to - from) * delta;
}

function setupDrag(el: HTMLDivElement, dataEl: HTMLInputElement, valueProperty: string, limitProperty: string) {
  const parent = el.parentElement;

  if (!parent) {
    return;
  }

  let minPos = 0;
  let maxPos = 0;
  let curValue = 0;
  let dragging = false;

  function initVars() {
    if (!parent) { return; }

    const rect = parent.getBoundingClientRect();

    minPos = rect.x;
    maxPos = rect.x + rect.width - el.clientWidth;
    curValue = Number(dataEl.getAttribute(valueProperty) || '0');
  }

  function clampValue(value: number): number {
    const storedValue = Number(dataEl.getAttribute(valueProperty) || '0');
    const limitValue = Number(dataEl.getAttribute(limitProperty) || '0');

    if (storedValue >= limitValue && value < limitValue) {
      return limitValue;
    }
    else if (storedValue < limitValue && value >= limitValue) {
      return limitValue - 1; // Offset by 1 to ensure stored value is less than limit.
    }

    return value;
  }

  function getMin(): number {
    return Number(dataEl.getAttribute('min') || '0');
  }

  function getMax(): number {
    return Number(dataEl.getAttribute('max') || '0');
  }

  // Define functions to control the drag behavior of the slider.
  function dragMove(e: PointerEvent) {
    if (!dragging) { return; }

    e.preventDefault();

    let desiredPos = e.clientX;

    if (desiredPos > maxPos) {
      desiredPos = maxPos;
    }
    else if (desiredPos < minPos) {
      desiredPos = minPos;
    }

    curValue = clampValue(
      lerp(
        (desiredPos - minPos) / (maxPos - minPos),
        getMin(),
        getMax()
      )
    );

    desiredPos = lerp(curValue / getMax(), minPos, maxPos);

    el.style.left = `${desiredPos}px`;

    dataEl.setAttribute(valueProperty, curValue.toString());
    dataEl.dispatchEvent(new InputEvent('input'));
  }

  function dragEnd(e: PointerEvent) {
    if (!dragging) { return; }

    e.preventDefault();

    dataEl.setAttribute(valueProperty, curValue.toString());
    dataEl.dispatchEvent(new InputEvent('input'));

    dragging = false;
  }

  function dragBegin(e: PointerEvent) {
    if (!parent) { return; }

    e.preventDefault();
    initVars();

    dragging = true;
  }

  // Set initial position;
  initVars();
  el.style.left = `${lerp(curValue / getMax(), minPos, maxPos)}px`;

  // Attach event listeners for dragging the head.
  el.addEventListener('pointerdown', dragBegin);
  window.addEventListener('pointerup', dragEnd);
  window.addEventListener('pointermove', dragMove);
}

function setupSlider(el: HTMLInputElement) {
  const parent = el.parentElement;

  if (!parent) {
    return;
  }

  // Create a bunch of divs for presentation.
  const sliderContainer: HTMLDivElement = document.createElement('div');
  const minHead: HTMLDivElement = document.createElement('div');
  const maxHead: HTMLDivElement = document.createElement('div');
  const body: HTMLDivElement = document.createElement('div');

  // Hide the real input, and add CSS classes to our divs.
  el.classList.add('hidden');
  sliderContainer.classList.add('slider');
  minHead.classList.add('slider__head');
  minHead.classList.add('slider__head--min');
  maxHead.classList.add('slider__head');
  maxHead.classList.add('slider__head--max');
  body.classList.add('slider__body');

  // Insert divs into other divs and subsequently into the document.
  sliderContainer.appendChild(body);
  sliderContainer.appendChild(minHead);
  sliderContainer.appendChild(maxHead);
  parent.insertBefore(sliderContainer, el);

  // Setup drag events on head elements.
  setupDrag(minHead, el, 'valuemin', 'valuemax');
  setupDrag(maxHead, el, 'valuemax', 'valuemin');
}

function setupSliders() {
  $$<HTMLInputElement>('input[type="dualrange"]').forEach(el => {
    setupSlider(el);
  });
}

export { setupSliders };
