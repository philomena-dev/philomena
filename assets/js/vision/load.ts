export interface ResultImage {
  width: number;
  height: number;
  data: ImageBitmap;
}

function nextLowestDimension(dimension: number): number {
  return Math.min(Math.pow(2, Math.floor(Math.log2(dimension))), 4096);
}

export async function loadImageCroppedPowerOfTwo(url: string): Promise<ResultImage> {
  const image = document.createElement('img');
  const body = document.body;

  await new Promise<void>((resolve, reject) => {
    image.onload = () => resolve();
    image.onerror = () => reject();
    image.crossOrigin = '';
    image.style.width = '1px';
    image.style.height = '1px';
    image.src = url;

    body.insertAdjacentElement('beforeend', image);
  });

  const cropWidth = nextLowestDimension(image.naturalWidth);
  const cropHeight = nextLowestDimension(image.naturalHeight);
  const data = await createImageBitmap(image, 0, 0, cropWidth, cropHeight);
  body.removeChild(image);

  return {
    width: cropWidth,
    height: cropHeight,
    data,
  };
}
