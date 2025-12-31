// Build script to bundle noble-post-quantum for service worker use
import * as esbuild from 'esbuild'

await esbuild.build({
  stdin: {
    contents: `
      import { ml_kem768 } from '@noble/post-quantum/ml-kem.js';
      self.noblePostQuantum = { ml_kem768 };
    `,
    resolveDir: process.cwd(),
    loader: 'js',
  },
  bundle: true,
  format: 'iife',
  target: 'es2020',
  outfile: 'public/sw-crypto.js',
  minify: true,
})

console.log('Built public/sw-crypto.js')
