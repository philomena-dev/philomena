/**
 * Graph Logic
 *
 * Scales graphs, makes graphs resizable, and stuff like that
 */

import { $, $$ } from './utils/dom';

function setGraphWidth(el: SVGSVGElement, width: number) {
  el.viewBox.baseVal.width = Math.max(width, 0);

  const graph: SVGPathElement | null = $<SVGPathElement>('#js-graph', el);

  if (graph) {
    graph.style.transform = `scaleX(${Math.max(width, 0) / 375})`;
  }
}

function graphSlice(el: SVGSVGElement, width: number, offset: number) {
  setGraphWidth(el, width);
  el.viewBox.baseVal.x = Math.max(offset, 0);
}

function resizeGraphs() {
  $$<SVGSVGElement>('#js-graph-svg').forEach(el => {
    const parent: HTMLElement | null = el.parentElement;

    if (parent) {
      setGraphWidth(el, parent.clientWidth);
    }
  });
}

function scaleGraph(target: HTMLElement, min: number, max: number) {
  const targetSvg = $<SVGSVGElement>('#js-graph-svg', target);

  if (!targetSvg) return;

  const cw = target.clientWidth;
  const diff = 100 - (max - min);
  const targetWidth = cw + cw * (diff / 100);
  const targetOffset = targetWidth * (min / 100);

  targetSvg.style.minWidth = `${targetWidth}px`;

  graphSlice(targetSvg, targetWidth, targetOffset);
}

function setupSliders() {
  $$<HTMLInputElement>('#js-graph-slider').forEach(el => {
    const targetId = el.getAttribute('data-target');

    if (!targetId) return;

    const target = $<HTMLElement>(targetId);

    if (!target) return;

    el.addEventListener('input', () => {
      const min = Number(el.getAttribute('valuemin') || '0');
      const max = Number(el.getAttribute('valuemax') || '0');

      scaleGraph(target, min, max);
    });
  });
}

function sizeGraphs() {
  resizeGraphs();
  setupSliders();
  window.addEventListener('resize', resizeGraphs);
}

export { sizeGraphs };
