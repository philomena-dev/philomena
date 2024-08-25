import { loadImageCroppedPowerOfTwo } from './load';
import {
  createNonMippedLinearTexture,
  createNonMippedLinearTextureFbo,
  createOffscreenCanvasRenderingContext,
  createProgramFromSources,
  Framebuffer,
  getUniformLocation,
  Texture,
} from './webgl';

const vert = `#version 300 es

void main() {
  float x = float((gl_VertexID & 1) << 2);
  float y = float((gl_VertexID & 2) << 1);
  gl_Position = vec4(x - 1.0, -1.0 * (y - 1.0), 0.0, 1.0);
}
`;

const mapFragment = `#version 300 es

precision highp float;

uniform highp sampler2D image;
uniform highp uvec2 windowResolution;
uniform highp ivec2 dynamicOffset;

out vec3 outCov;

vec2 linearRGBToPbPr(vec3 rgb) {
  float rPrime = rgb.r;
  float gPrime = rgb.g;
  float bPrime = rgb.b;

  float pb = - (0.168736 * rPrime) - (0.331264 * gPrime) + (0.5      * bPrime);
  float pr =   (0.5      * rPrime) - (0.418688 * gPrime) - (0.081312 * bPrime);

  return vec2(pb, pr);
}

float coefficientOfVariation(vec4 values) {
  float mean   = dot(values, vec4(1.0)) / 4.0;
  float stddev = length(values - mean) / sqrt(4.0);

  if (abs(mean) > 1e-4) {
    return abs(stddev / mean);
  } else {
    return 0.0;
  }
}

vec4 fetchWithOffset(ivec2 coord, ivec2 size) {
  int x = min(coord.x + dynamicOffset.x, size.x - 1);
  int y = min(coord.y + dynamicOffset.y, size.y - 1);

  return texelFetch(image, ivec2(x, y), 0);
}

void main() {
  ivec2 windowCoord = ivec2(vec2(gl_FragCoord.x, float(windowResolution.y) - gl_FragCoord.y) - 0.5);
  ivec2 size = ivec2(textureSize(image, 0));

  vec4 nw = fetchWithOffset(windowCoord * 2 + ivec2(0, 0), size);
  vec4 ne = fetchWithOffset(windowCoord * 2 + ivec2(0, 1), size);
  vec4 sw = fetchWithOffset(windowCoord * 2 + ivec2(1, 0), size);
  vec4 se = fetchWithOffset(windowCoord * 2 + ivec2(1, 1), size);

  vec2 chromaNw = linearRGBToPbPr(nw.rgb);
  vec2 chromaNe = linearRGBToPbPr(ne.rgb);
  vec2 chromaSw = linearRGBToPbPr(sw.rgb);
  vec2 chromaSe = linearRGBToPbPr(se.rgb);

  float covPb = coefficientOfVariation(vec4(chromaNw.x, chromaNe.x, chromaSw.x, chromaSe.x));
  float covPr = coefficientOfVariation(vec4(chromaNw.y, chromaNe.y, chromaSw.y, chromaSe.y));

  bvec4 nonOpaqueAlpha = lessThan(vec4(nw.a, ne.a, sw.a, se.a), vec4(1.0));
  float alphaAny = dot(vec4(nonOpaqueAlpha), vec4(1.0));

  outCov = vec3(covPb, covPr, alphaAny);
}
`;

const reduceFragment = `#version 300 es

precision highp float;

uniform highp sampler2D image;
uniform highp uvec2 windowResolution;

#define REDUCE_HORIZONTAL 0
#define REDUCE_VERTICAL 1
uniform uint reduceDimension;

out vec3 outCov;

void main() {
  ivec2 windowCoord = ivec2(vec2(gl_FragCoord.x, float(windowResolution.y) - gl_FragCoord.y) - 0.5);
  if (windowCoord[reduceDimension] > 0) {
    discard;
  }

  vec3 result = vec3(0.0);
  ivec2 offset = ivec2(0);
  int n = textureSize(image, 0)[reduceDimension];

  for (int i = 0; i < n; i++) {
    offset[reduceDimension] += 1;
    result += texelFetch(image, windowCoord + offset, 0).xyz;
  }

  outCov = result;
}
`;
const reduceHorizontal = 0;
const reduceVertical = 1;

function getDynamicOffset(round: number): [GLint, GLint] {
  switch (round) {
    case 0:
      return [0, 0];
    case 1:
      return [1, 0];
    case 2:
      return [0, 1];
    default:
      return [1, 1];
  }
}

function coefficientOfVariation(values: number[]): number {
  const mean = values.reduce((a, n) => a + n, 0) / values.length;
  const stddev = Math.sqrt(values.reduce((a, n) => a + (n - mean) * (n - mean), 0) / values.length);

  if (Math.abs(mean) > 1e-4) {
    return Math.abs(stddev / mean);
  }

  return 0;
}

type CovCovPb = number;
type CovCovPr = number;
type SumAlpha = number;

async function detectChromaSubsampling(imageUrl: string): Promise<[CovCovPb, CovCovPr, SumAlpha]> {
  const bitmap = await loadImageCroppedPowerOfTwo(imageUrl);
  const gl = createOffscreenCanvasRenderingContext();

  const mapProgram = createProgramFromSources(gl, vert, mapFragment);
  const mapImage = getUniformLocation(gl, mapProgram, 'image');
  const mapWindowResolution = getUniformLocation(gl, mapProgram, 'windowResolution');
  const mapDynamicOffset = getUniformLocation(gl, mapProgram, 'dynamicOffset');

  const reduceProgram = createProgramFromSources(gl, vert, reduceFragment);
  const reduceImage = getUniformLocation(gl, reduceProgram, 'image');
  const reduceWindowResolution = getUniformLocation(gl, reduceProgram, 'windowResolution');
  const reduceReduceDimension = getUniformLocation(gl, reduceProgram, 'reduceDimension');

  const sourceFormat = {
    internalFormat: gl.RGBA,
    format: gl.RGBA,
    type: gl.UNSIGNED_BYTE,
  };

  const targetFormat = {
    internalFormat: gl.RGBA32F,
    format: gl.RGBA,
    type: gl.FLOAT,
  };

  const sourceTexture = createNonMippedLinearTexture(gl, {
    width: bitmap.width,
    height: bitmap.height,
    pixels: bitmap.data,
    ...sourceFormat,
  });

  const mapFbo = createNonMippedLinearTextureFbo(gl, {
    width: Math.max(1, bitmap.width >> 1),
    height: Math.max(1, bitmap.height >> 1),
    ...targetFormat,
  });

  const reduceHorizontalFbo = createNonMippedLinearTextureFbo(gl, {
    width: 1,
    height: Math.max(1, bitmap.height >> 1),
    ...targetFormat,
  });

  const reduceVerticalFbo = createNonMippedLinearTextureFbo(gl, {
    width: 1,
    height: 1,
    ...targetFormat,
  });

  function configure(
    program: WebGLProgram,
    srcLocation: WebGLUniformLocation,
    srcTex: Texture,
    dstResLocation: WebGLUniformLocation,
    dstFramebuffer: Framebuffer,
  ) {
    // Set up program
    gl.useProgram(program);

    // Bind FBO for offscreen rendering
    gl.bindFramebuffer(gl.FRAMEBUFFER, dstFramebuffer.object);

    // Configure sampler
    gl.uniform1i(srcLocation, 0);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, srcTex.object);

    // Configure resolution
    gl.uniform2ui(dstResLocation, dstFramebuffer.texture.width, dstFramebuffer.texture.height);

    // Set viewport and scissor
    gl.viewport(0, 0, dstFramebuffer.texture.width, dstFramebuffer.texture.height);
    gl.disable(gl.SCISSOR_TEST);
    gl.disable(gl.DEPTH_TEST);

    // Discard existing contents
    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);
  }

  function generateSumCoeffs(round: number): [number, number, number] {
    // Map pixels into the given format
    configure(mapProgram, mapImage, sourceTexture, mapWindowResolution, mapFbo);
    gl.uniform2i(mapDynamicOffset, ...getDynamicOffset(round));
    gl.drawArrays(gl.TRIANGLES, 0, 3);

    // Horizontal reduction
    configure(reduceProgram, reduceImage, mapFbo.texture, reduceWindowResolution, reduceHorizontalFbo);
    gl.uniform1ui(reduceReduceDimension, reduceHorizontal);
    gl.drawArrays(gl.TRIANGLES, 0, 3);

    // Vertical reduction
    configure(reduceProgram, reduceImage, reduceHorizontalFbo.texture, reduceWindowResolution, reduceVerticalFbo);
    gl.uniform1ui(reduceReduceDimension, reduceVertical);
    gl.drawArrays(gl.TRIANGLES, 0, 3);

    // Output
    const sumCoeffs = new Float32Array(4);
    gl.readPixels(0, 0, 1, 1, targetFormat.format, targetFormat.type, sumCoeffs);

    return [sumCoeffs[0], sumCoeffs[1], sumCoeffs[2]];
  }

  const allCovPb: number[] = [];
  const allCovPr: number[] = [];
  let sumAlpha: number = 0;

  for (let i = 0; i < 4; i++) {
    const [covPb, covPr, alpha] = generateSumCoeffs(i);
    allCovPb.push(covPb);
    allCovPr.push(covPr);
    sumAlpha += alpha;
  }

  const covCovPb = coefficientOfVariation(allCovPb);
  const covCovPr = coefficientOfVariation(allCovPr);

  return [covCovPb, covCovPr, sumAlpha];
}

export type SubsampleClassification = 'probablyNotSubsampled' | 'probablySubsampled' | 'hasTransparency';

export async function classifyChromaSubsampling(imageUrl: string): Promise<SubsampleClassification> {
  const [covCovPb, covCovPr, sumAlpha] = await detectChromaSubsampling(imageUrl);

  if (sumAlpha > 0) {
    // Regardless of whether it was subsampled, this image has transparency
    // and so classifications about its quality are no longer relevant
    return 'hasTransparency';
  }

  if (covCovPb * covCovPr > 1e-3) {
    return 'probablySubsampled';
  }

  return 'probablyNotSubsampled';
}

(window as any).detectChromaSubsampling = detectChromaSubsampling;
