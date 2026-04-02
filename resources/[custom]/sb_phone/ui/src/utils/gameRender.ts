/**
 * GameRender — Streams FiveM's game camera to a <canvas> via raw WebGL.
 *
 * FiveM's CEF recognizes a specific texParameterf sequence on TEXTURE_WRAP_T
 * (CLAMP→MIRRORED→REPEAT) as a signal to hook into that texture and provide
 * the live game render. No Three.js needed — pure WebGL.
 *
 * Based on: https://forum.cfx.re/t/how-to-use-x-cfx-game-view-cfxtexture/2270025
 * and https://gist.github.com/liquiad/f4952575cbff31f923d19b342b4d25f8
 */

const vertexShaderSrc = `
attribute vec2 a_position;
attribute vec2 a_texcoord;
varying vec2 textureCoordinate;

void main() {
  gl_Position = vec4(a_position, 0.0, 1.0);
  textureCoordinate = a_texcoord;
}
`

const fragmentShaderSrc = `
varying highp vec2 textureCoordinate;
uniform sampler2D external_texture;

void main() {
  gl_FragColor = texture2D(external_texture, textureCoordinate);
}
`

function makeShader(gl: WebGLRenderingContext, type: number, src: string) {
  const shader = gl.createShader(type)!
  gl.shaderSource(shader, src)
  gl.compileShader(shader)
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    console.error('[GameRender] Shader error:', gl.getShaderInfoLog(shader))
  }
  return shader
}

function createTexture(gl: WebGLRenderingContext) {
  const tex = gl.createTexture()
  gl.bindTexture(gl.TEXTURE_2D, tex)
  gl.texImage2D(
    gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0,
    gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array([0, 0, 0, 255])
  )
  gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
  gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
  gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)

  // Magic hook sequence — FiveM recognizes this and provides the game render
  gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
  gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.MIRRORED_REPEAT)
  gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
  // Reset
  gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)

  return tex
}

function createProgram(gl: WebGLRenderingContext) {
  const vertexShader = makeShader(gl, gl.VERTEX_SHADER, vertexShaderSrc)
  const fragmentShader = makeShader(gl, gl.FRAGMENT_SHADER, fragmentShaderSrc)
  const program = gl.createProgram()!
  gl.attachShader(program, vertexShader)
  gl.attachShader(program, fragmentShader)
  gl.linkProgram(program)
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    console.error('[GameRender] Link error:', gl.getProgramInfoLog(program))
  }
  gl.useProgram(program)
  return {
    program,
    vloc: gl.getAttribLocation(program, 'a_position'),
    tloc: gl.getAttribLocation(program, 'a_texcoord'),
  }
}

function createBuffers(gl: WebGLRenderingContext) {
  const vertexBuff = gl.createBuffer()
  gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuff)
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW)

  const texBuff = gl.createBuffer()
  gl.bindBuffer(gl.ARRAY_BUFFER, texBuff)
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([0, 0, 1, 0, 0, 1, 1, 1]), gl.STATIC_DRAW)

  return { vertexBuff, texBuff }
}

interface GameView {
  canvas: HTMLCanvasElement
  gl: WebGLRenderingContext
  animationFrame: number | undefined
  stop: () => void
}

export function createGameView(canvas: HTMLCanvasElement): GameView {
  const gl = canvas.getContext('webgl', {
    antialias: false,
    depth: false,
    stencil: false,
    alpha: false,
    desynchronized: true,
    failIfMajorPerformanceCaveat: false,
  }) as WebGLRenderingContext

  const gameView: GameView = {
    canvas,
    gl,
    animationFrame: undefined,
    stop: () => {
      if (gameView.animationFrame != null) {
        cancelAnimationFrame(gameView.animationFrame)
        gameView.animationFrame = undefined
      }
    },
  }

  // Set up WebGL pipeline
  const tex = createTexture(gl)
  const { program, vloc, tloc } = createProgram(gl)
  const { vertexBuff, texBuff } = createBuffers(gl)

  gl.useProgram(program)
  gl.bindTexture(gl.TEXTURE_2D, tex)
  gl.uniform1i(gl.getUniformLocation(program, 'external_texture'), 0)

  gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuff)
  gl.vertexAttribPointer(vloc, 2, gl.FLOAT, false, 0, 0)
  gl.enableVertexAttribArray(vloc)

  gl.bindBuffer(gl.ARRAY_BUFFER, texBuff)
  gl.vertexAttribPointer(tloc, 2, gl.FLOAT, false, 0, 0)
  gl.enableVertexAttribArray(tloc)

  gl.viewport(0, 0, canvas.width, canvas.height)

  // Render loop — each frame draws the game texture to the canvas
  function render() {
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
    gl.finish()
    gameView.animationFrame = requestAnimationFrame(render)
  }

  render()
  return gameView
}
