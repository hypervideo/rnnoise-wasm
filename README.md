# @timephy/rnnoise-wasm

This library implements the [RNNoise](https://people.xiph.org/~jm/demo/rnnoise/) noise suppression library as a WASM module for use in web frontends.

This repository contains the necessary utilities to build RNNoise using a Docker build environment, compile it to WASM with Emscripten, and export a JavaScript library from the contained TypeScript source code.

## Forked from @jitsi/rnnoise-wasm

This library was originally forked from [@jitsi/rnnoise-wasm](https://github.com/jitsi/rnnoise-wasm).

### Changes

- Updated [RNNoise](https://github.com/xiph/rnnoise) to 0.2
- Implemented an `AudioWorkletNode` that can be used directly (taken from <https://github.com/jitsi/jitsi-meet/blob/master/react/features/stream-effects>)
- Implemented polyfills, because the exported WASM accesses `atob` and `self.location.href`
- Uses TypeScript

### Resources

- <https://jitsi.org/blog/enhanced-noise-suppression-in-jitsi-meet>
- <https://github.com/jitsi/rnnoise-wasm>
- <https://www.npmjs.com/package/@jitsi/rnnoise-wasm>

## How to use

```ts
import { NoiseSuppressorWorklet_Name } from "@timephy/rnnoise-wasm"
// This is an example how to get the script path using Vite, may be different when using other build tools
// NOTE: `?worker&url` is important (`worker` to generate a working script, `url` to get its url load it)
import NoiseSuppressorWorklet from "@timephy/rnnoise-wasm/NoiseSuppressorWorklet?worker&url"

async function example() {
    // Load the NoiseSuppressorWorklet into the AudioContext
    const ctx = new AudioContext()
    await ctx.audioWorklet.addModule(NoiseSuppressorWorklet)

    // Instantiate the Worklet as a Node
    const noiseSuppressionNode = new AudioWorkletNode(ctx, NoiseSuppressorWorklet_Name)

    // Setup the node graph
    const stream = new MediaStream() // containing the microphone track
    const source = ctx.createMediaStreamSource(stream)
    source
        .connect(noiseSuppressionNode) // pass audio through noise suppression
        .connect(ctx.destination) // playback audio on output device
}
```

## Build

### Prerequisites

- node - tested version v10.16.3
- npm - tested version v6.9.0
- docker - tested version 19.03.1

### Building

Building is straightforward, run:

```bash
# To build RNNoise, compile it into WASM, and build TypeScript
npm run build
```

The repository already has a pre-compiled WASM under the `src/generated` folder, running the above command will replace it with the newly compiled binaries and glue wasm .js file respectively.

In order to facilitate the build with docker the following prebuilt image is used [emscripten/emsdk](https://hub.docker.com/r/emscripten/emsdk) however, it is slightly altered by installing autotools components necessary for building rnnoise.

In summary the build process consists of three steps:

1. `build:dockerfile` - pulls in [emscripten/emsdk](https://hub.docker.com/r/emscripten/emsdk) which is then altered and saved. Any subsequent build is going to check if the images was already installed and use that, so if one wants to make changes to the Dockerfile be sure to first delete the build image from your local docker repo.
2. `build:emscripten` - mounts the repo to the docker image from step one and runs build.sh on it. The bash script contains all the steps necessary for building rnnoise as a wasm module.
3. `build:typescript` - exports the TypeScript source code to JavaScript and type declaration files
