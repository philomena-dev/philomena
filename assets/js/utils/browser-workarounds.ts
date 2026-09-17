import { assertNotNull } from './assert';

export function needsChromiumJpegNormalization() {
  if (navigator.userAgentData?.brands) {
    return navigator.userAgentData.brands.some(({ brand }) => brand === 'Chromium');
  }

  return /\b(?:Chrome|Chromium|Edg|OPR)\//.test(navigator.userAgent);
}

export async function replaceFilterImageHrefIfNeeded(element: SVGFEImageElement) {
  if (!element.href.baseVal.endsWith('.jpg')) return;
  element.href.baseVal = await rasterizeToDataURL(element.href.baseVal);
}

async function rasterizeToDataURL(source: string) {
  const image = await loadCORSImage(source);
  return rasterizeCanvas(image);
}

function loadCORSImage(source: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject();

    image.crossOrigin = 'anonymous';
    image.src = source;
  });
}

function rasterizeCanvas(image: HTMLImageElement): string {
  const canvas = document.createElement('canvas');
  canvas.width = image.naturalWidth;
  canvas.height = image.naturalHeight;

  // Set willReadFrequently to avoid bugged Chromium GPU decode path
  const context = assertNotNull(canvas.getContext('2d', { willReadFrequently: true }));
  context.drawImage(image, 0, 0);

  return canvas.toDataURL('image/png');
}
