/**
 * Graph Logic
 *
 * Scales graphs, makes graphs resizable, and stuff like that
 */

import { $, $$ } from './utils/dom';

function resizeGraphs() {
  $$<SVGSVGElement>('#js-sparkline-svg').forEach(el => {
    const parent: HTMLElement | null = el.parentElement;

    if (parent) {
      el.viewBox.baseVal.width = parent.clientWidth;

      const graph: SVGPathElement | null = $<SVGPathElement>('#js-barline-graph', el);

      if (graph) {
        graph.setAttribute('style', `transform: scale(${parent.clientWidth / 375});`);
      }
    }
  });
}

function sizeGraphs() {
  resizeGraphs();
  window.addEventListener('resize', resizeGraphs);
}

export { sizeGraphs };
