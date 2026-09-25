# 598APE-HW1

This repository contains code for homework 1 of 598APE.

In particular, this repository is an implementation of an optimized Raytracer.

Starting from the course baseline, we applied 11 optimizations 
(compiler optimization, efficient nearest-intersection search, redundant-work removal, and multithreading)
 that leave every output byte-identical to the baseline while running the scenes 19-21x faster
and making the 111,748-triangle elephant renderable in seconds instead of days.

To compile the program run:
```bash
make -j
```

To clean existing build artifacts run:
```bash
make clean
```

This program assumes the following are installed on your machine:
* A working C++ compiler (g++ is assumed in the Makefile)
* make
* ImageMagick (for importing and exporting non-ppm images)
* FFMpeg (for exporting movies from image sequences)
* `librsvg2-bin` (for converting flamegraph)

The raytracer program here is general and can be used to generate any number of different potential scenes.

Once compiled, one can call the raytracer program as follows:
```bash
./main.exe --help
# Prints the following
# Usage ./main.exe [-H <height>] [-W <width>] [-F <framecount>] [--movie] [--no-movie] [--png] [--ppm] [--help] [-o <outfile>] [-i <infile>] [-a <animationfile>]
```

The raytracer program takes a scene file (a text file ending in .ray) and generates an image or sequence of images corresponding to the specified scene.

One can tune the height, width, and format of the image being generated with optional command line arguments. For example, let's generate an 500x500 image corresponding to the scene in `inputs/pianoroom.ray`, in PPM format.

```bash
./main.exe -i inputs/pianoroom.ray --ppm -o output/pianoroom.ppm -H 500 -W 500
```

As we run the program, we see the following output:
```
Done Frame       0|
Total time to create images=1.334815 seconds
```

We have placed timer code surrounding the main computational loop inside main.cpp. It is your goal to reduce this runtime as much as possible, while maintaining or increasing the complexity (i.e. resolution, number of frames) of the scene.

Here we see that the image took 1.3 seconds to run and produced a result in `output/pianoroom.ppm`. Input and output of images is already handled by the library. In particular, the PPM format (see https://en.wikipedia.org/wiki/Netpbm for an example), represents images as text for data -- which makes it easy to input and output without the use of a library. However, as this is not the most efficient, this application uses the tool ImageMagick tool to convert to and from the PPM formats.


## Reproducing Benchmark and Verifying the Optimizations

### Performance (the numbers in the report)

`eval/bench.sh` reproduces every timing in the paper. It checks out each commit,
builds it, and runs each scene under `perf stat`, printing the program's own
`Total time` alongside cycle/instruction counts.

```bash
sudo sysctl kernel.perf_event_paranoid=1     # allow perf to count (resets on reboot)
eval/bench.sh 2>&1 | tee bench.log           # ~2h at REPS=5
REPS=3 eval/bench.sh                         # faster, slightly noisier
```

Baseline timings for the sphere and elephant are extrapolated from small frames,
because a full baseline render takes hours to days.

### Correctness (byte-identical output)

`bench.sh` byte-compares each commit's pianoroom output against the baseline:

```bash
# what bench.sh does, per commit:
cmp bench_out/piano_base.ppm bench_out/piano_<commit>.ppm
```

All 11 shipped commits produce output identical to baseline (`19bbc81`).

### Flame graphs

```bash
git submodule update --init             # fetches eval/FlameGraph
eval/pianoroom.sh                       # optimized pianoroom flame graph
eval/pianoroom_base.sh                  # baseline pianoroom flame graph
eval/realelephant.sh                    # optimized elephant flame graph
eval/realelephant_base.sh               # baseline elephant flame graph (tiny frame)
```

## Optimizations and How to Evaluate Individually

Each optimization is a single commit on top of the baseline. To measure one in
isolation, time the commit against its parent:

```bash
git checkout <commit>   && make clean && make -j    # optimized
git checkout <commit>~1 && make clean && make -j    # just before it
```

| # | Commit | Optimization |
|---|---|---|
| 0 | `19bbc81` | Baseline |
| 1 | `8c6b259` | Build at `-O3` instead of `-O0` |
| 2 | `f193627` | `Box::getIntersection`: check `time==inf` before `solveScalers` |
| 3 | `e2e6c3a` | Pass `Ray`/`Vector` by `const&` |
| 4 | `66fd713` | Hoist shadow-ray construction out of the `getLight` loop |
| 5 | `c1c40fc` | Pass textures by `const&` (no measurable effect) |
| 6 | `de0e21f` | `calcColor`: $O(N^2)$ grow-and-copy to $O(N)$ linear min scan |
| 7 | `79cdff5` | Enable `-flto` in all three Makefiles |
| 8 | `c936c54` | `getLight`: compute magnitude only when lit (no measurable effect) |
| 9 | `b12f292` | `calcColor`: fewer `sqrt` calls when normalizing |
| 10 | `381e77e` | `fix()`: replace `fmod(a,1.0)` with `a - floor(a)` |
| 11 | `c5d6565` | Parallelize the pixel loop in `refresh()`|

Notes for reproduction:

- **#6 is the change that makes the mesh scenes runnable.** Before it, the elephant
  cannot be rendered in reasonable time, so evaluate #1–#5 on pianoroom and globe.
- **#7 (`-flto`)** requires a clean rebuild (`make clean && make -j`); a partial
  rebuild will not relink with LTO.
- `inputs/realelephant.ray` was added after the baseline (commit `42b22ba`). To time
  the elephant on `19bbc81`, copy it in first:
  `git show c5d6565:inputs/realelephant.ray > /tmp/realelephant.ray`.

### Optimizations that did not help

Caching the `solveScalers` denominator (commit `f0389f0`, reverted in `cd4768f`)
This was scene-dependent and reproduced net negative. 
The denominator cache can be re-measured with:

```bash
git checkout f0389f0~1 && make clean && make -j   # before the cache
git checkout f0389f0   && make clean && make -j   # with the cache
```

## Input Programs
This project contains three (arguably four) input programs for you to optimize.

### PianoRoom

A simple room with a reflecting checkerboard floor, a stairwell, a sphere, a circular rug, and a mirror ref.

Here we want to produce the highest resolution single image of this format, as fast as possible. The relevant command for producing an output is:

```bash
./main.exe -i inputs/pianoroom.ray --ppm -o output/pianoroom.ppm -H 500 -W 500
```

### Globe

A video of the Earth floating on top of a sea with a sky in the background. The Earth and clouds are rotating (in opposite directions), and the sea beneath reflects the scene above, and moves.

Here we want to produce the highest resolution video, as fast as possible. The relevant command for producing an output is:

```bash
./main.exe -i inputs/globe.ray --ppm  -a inputs/globe.animate --movie -F 24 
```

Here, as we are generating multiple frames, the extra command `-a <animationfile>` is used to pass in a sequence of commands to generate subsequent frames.

The number of frames we wish to generate (24) is passed in as `-F <numframes>`.

Here we will produce 24 individual images for each frame. To produce a playable movie out of these images, the `--movie` command will call a program called FFMpeg to produce a playable video.

### Elephant

A mesh of objects. In practical graphics applications, designing a primitive for each possible object is too complex. Instead, one builds up a mesh of triangles to represent the object being shown. Given sufficiently many triangles, we can represent arbitrarily complex structures. Here, we wish to make a video circling around a Mesh object which we import.

The simple version of this program is generated by the following command:
```bash
./main.exe -i inputs/elephant.ray --ppm  -a inputs/elephant.animate --movie -F 24 -W 100 -H 100 -o output/sphere.mp4 
```

Note the reduced resolution (as the initial unoptimized code can be somewhat slow).

This initial mesh represents a sphere with 3168 triangles.

Here we produce a video in which we have the camera circles around the object.

If we inspect the input file `inputs/elephant.ray` we see that it loads the mesh from two files, as defined by the line
```
data/x.txt 1586 data/f.txt 3168 -1.58 -.43 2.7
```

The goal here is to speed up the program sufficiently to make a high resolution circle of the elephant mesh (found in `data/elepx.txt` and `data/elepf.txt`), which contains 111748 triangles. One can edit the `.ray` file and comment out the sphere mesh and replace it with `data/elepx.txt 62779 data/elepf.txt 111748 -1.58 -.43 2.7` (this is done in `inputs/realelephant.ray`).

## Code Overview

The raytracer contains several core utilities, defined in different files.

### Camera

The Camera class contains information about the position and direction we are facing. An image is constructed by creating a grid of points and sending out rays from each of these points, and determining what objects they collide with. Each result becomes an individual pixel in our resulting image.

### Shape

Each object in our scene is defined as a shape. There are several shapes subclasses in the application. This includes a plane (an infinitely long flat surface), a sphere (a collection of points equidistant from a center), a disk (a flat surface whose points are within a given distance of a center), a box (a flat rectangle), and a triangle.

Shapes have a position in space, and potentially an orientation (i.e. direction they face, as defined with the angles yaw pitch and roll).

Shapes also have a texture defining what color of each point of the shape, and optionally a "normalMap" texture which defines how light bounces off each point.

Core methods within shape include:
* `getIntersection`, which defines whether a given light ray will hit the shape, and if so returns time it takes the light to hit it (otherwise infinity).
* `getLightIntersection`: Given that a ray hits the shape, determine how a light source will illuminate the shape at that point based off of the color of the object, and its spectral properties (i.e. opaque, reflective, aminent lighting).
* `getNormal` determine the normal axis to the point of collision, in order to compute the direction in which light will bounce off the object.

### Texture

A texture object defines what color will be applied at a point in space. There are two textures implemented: a single color for all points, and one loaded from an image. Textures are used to define both the color of an object, and also can optionally be used to define normal axes for an object (using data stored in rgb to define the xyz axis).

### Light

Light objects illuminate a scene, resulting in differences in gradients of colors on an object and shadows. Lights have a color and a position.

### Autonoma

An Autonoma is a base class used to hold all of the shapes in scope, the camera, and all lights.


## Docker

For ease of use and installation, we provide a docker image capable of running and building code here. The source docker file is in /docker (which is essentially a list of commands to build an OS state from scratch). It contains the dependent compilers, and some other nice things.

You can build this yourself manually by running `cd docker && docker build -t <myusername>/598ape`. Alternatively we have pushed a pre-built version to `wsmoses/598ape` on Dockerhub.

You can then use the Docker container to build and run your code. If you run `./dockerrun.sh` you will enter an interactive bash session with all the packages from docker installed (that script by default uses `wsmoses/598ape`, feel free to replace it with whatever location you like if you built from scratch). The current directory (aka this folder) is mounted within `/host`. Any files you create on your personal machine will be available there, and anything you make in the container in that folder will be available on your personal machine.