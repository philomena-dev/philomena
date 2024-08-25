export function compileShader(gl: WebGL2RenderingContext, shaderSource: string, shaderType: GLenum) {
  const shader = gl.createShader(shaderType);
  if (!shader) {
    throw new Error(`failed to create shader of type ${shaderType}`);
  }

  gl.shaderSource(shader, shaderSource);
  gl.compileShader(shader);

  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    throw new Error(`Shader compilation failed: ${gl.getShaderInfoLog(shader)}`);
  }

  return shader;
}

export function createProgramFromSources(
  gl: WebGL2RenderingContext,
  vertexShaderSource: string,
  fragmentShaderSource: string,
) {
  const vertexShader = compileShader(gl, vertexShaderSource, gl.VERTEX_SHADER);
  const fragmentShader = compileShader(gl, fragmentShaderSource, gl.FRAGMENT_SHADER);

  const program = gl.createProgram();
  if (!program) {
    throw new Error('failed to create vertex + fragment program');
  }

  gl.attachShader(program, vertexShader);
  gl.attachShader(program, fragmentShader);
  gl.linkProgram(program);

  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    throw new Error(`Program link failed: ${gl.getProgramInfoLog(program)}`);
  }

  return program;
}

export function createOffscreenCanvasRenderingContext(): WebGL2RenderingContext {
  const canvas = document.createElement('canvas');
  const gl = canvas.getContext('webgl2');

  if (!gl) {
    throw new Error('failed to create WebGL2 context');
  }

  if (!gl.getExtension('EXT_color_buffer_float')) {
    throw new Error('failed to enable EXT_color_buffer_float extension');
  }

  return gl;
}

export interface TextureParameters {
  width: number;
  height: number;
  internalFormat: GLenum;
  format: GLenum;
  type: GLenum;
  pixels?: ImageBitmap;
}

export interface Texture extends TextureParameters {
  object: WebGLTexture;
}

export interface Framebuffer {
  object: WebGLFramebuffer;
  texture: Texture;
}

export function createNonMippedLinearTexture(gl: WebGL2RenderingContext, params: TextureParameters): Texture {
  const texture = gl.createTexture();
  if (!texture) {
    throw new Error('failed to create texture');
  }

  const level = 0;
  const internalFormat = params.internalFormat;
  const border = 0;
  const format = params.format;
  const type = params.type;
  const data = params.pixels;

  gl.bindTexture(gl.TEXTURE_2D, texture);
  if (data) {
    gl.texImage2D(gl.TEXTURE_2D, level, internalFormat, format, type, data);
  } else {
    gl.texImage2D(gl.TEXTURE_2D, level, internalFormat, params.width, params.height, border, format, type, null);
  }
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

  return { object: texture, ...params };
}

export function createNonMippedLinearTextureFbo(gl: WebGL2RenderingContext, params: TextureParameters): Framebuffer {
  const texture = createNonMippedLinearTexture(gl, params);
  const fbo = gl.createFramebuffer();
  if (!fbo) {
    throw new Error('failed to create framebuffer object');
  }

  gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);
  gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture.object, 0);

  return { object: fbo, texture };
}

export function getUniformLocation(
  gl: WebGL2RenderingContext,
  program: WebGLProgram,
  name: string,
): WebGLUniformLocation {
  const location = gl.getUniformLocation(program, name);
  if (!location) {
    throw new Error('failed to get uniform location');
  }

  return location;
}
