/**
 * Slider Logic
 *
 * Provides functionality for <input type="dualrange">
 *
 * Example usage:
 *
 * <input type="dualrange" min="0" max="100" valuemin="0" valuemax="100">
 */

import { lerp } from './utils/lerp';
import { $$ } from './utils/dom';

// Make a given slider head draggable.
function setupDrag(el: HTMLDivElement, dataEl: HTMLInputElement, valueProperty: string, limitProperty: string) {
  const parent = el.parentElement;

  if (!parent) {
    return;
  }

  // Initialize variables and constants.
  const inputEvent = new InputEvent('input');
  let minPos = 0;
  let maxPos = 0;
  let cachedMin = 0;
  let cachedMax = 0;
  let cachedValue = 0;
  let cachedLimit = 0;
  let curValue = 0;
  let dragging = false;

  // Clamps the slider head value to not cross over the other slider head's value.
  function clampValue(value: number): number {
    if (cachedValue >= cachedLimit && value < cachedLimit) {
      return cachedLimit;
    }
    else if (cachedValue < cachedLimit && value >= cachedLimit) {
      return cachedLimit - 1; // Offset by 1 to ensure stored value is less than limit.
    }

    return value;
  }

  // Utility accessor to get the minimum value of dualrange.
  function getMin(): number {
    return Number(dataEl.getAttribute('min') || '0');
  }

  // Utility accessor to get the maximum value of dualrange.
  function getMax(): number {
    return Number(dataEl.getAttribute('max') || '0');
  }

  // Initializes cached variables. Should be used
  // when the pointer event begins.
  function initVars() {
    if (!parent) { return; }

    const rect = parent.getBoundingClientRect();

    minPos = rect.x;
    maxPos = rect.x + rect.width - el.clientWidth;
    cachedMin = getMin();
    cachedMax = getMax();
    cachedValue = Number(dataEl.getAttribute(valueProperty) || '0');
    cachedLimit = Number(dataEl.getAttribute(limitProperty) || '0');
    curValue = Number(dataEl.getAttribute(valueProperty) || '0');
  }

  // Called during pointer movement.
  function dragMove(e: PointerEvent) {
    if (!dragging) { return; }

    e.preventDefault();

    let desiredPos = e.clientX;

    // `lerp` cleverly clamps the value between min and max,
    // so no need for any explicit checks for that here, only
    // the crossover check is required.
    curValue = clampValue(
      lerp(
        (desiredPos - minPos) / (maxPos - minPos),
        cachedMin,
        cachedMax
      )
    );

    // Same here, lerp clamps the value so it doesn't get out
    // of the slider boundary.
    desiredPos = lerp(curValue / cachedMax, minPos, maxPos);

    el.style.left = `${desiredPos}px`;

    dataEl.setAttribute(valueProperty, curValue.toString());
    dataEl.dispatchEvent(inputEvent);
  }

  // Called when the pointer is let go of.
  function dragEnd(e: PointerEvent) {
    if (!dragging) { return; }

    e.preventDefault();

    dataEl.setAttribute(valueProperty, curValue.toString());
    dataEl.dispatchEvent(inputEvent);

    dragging = false;
  }

  // Called when the slider head is clicked or tapped.
  function dragBegin(e: PointerEvent) {
    if (!parent) { return; }

    e.preventDefault();
    initVars();

    dragging = true;
  }

  // Set the initial variables and position;
  initVars();
  el.style.left = `${lerp(curValue / getMax(), minPos, maxPos)}px`;

  // Attach event listeners for dragging the head.
  el.addEventListener('pointerdown', dragBegin);
  window.addEventListener('pointerup', dragEnd);
  window.addEventListener('pointermove', dragMove);
}

// Sets up the slider input element.
// Creates `div` elements for presentation, hides the
// original `input` element. The logic is that
// we use divs for presentation, and input for data storage.
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

// Sets up all sliders currently on the page.
function setupSliders() {
  $$<HTMLInputElement>('input[type="dualrange"]').forEach(el => {
    setupSlider(el);
  });
}

export { setupSliders };
