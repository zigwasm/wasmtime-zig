# wasmtime-zig
[<img alt="github" src="https://img.shields.io/badge/github-kubkon/wasmtime--zig-8da0cb?style=for-the-badge&labelColor=555555&logo=github" height="20">](https://github.com/kubkon/wasmtime-zig)
[<img alt="build status" src="https://img.shields.io/github/workflow/status/kubkon/wasmtime-zig/CI/master?style=for-the-badge" height="20">](https://github.com/kubkon/wasmtime-zig/actions?query=branch%3Amaster)

Zig embedding of [Wasmtime]

[Wasmtime]: https://github.com/bytecodealliance/wasmtime

## Disclaimer

This is a very much work-in-progress library so drastic changes to the API are anything
but expected, and things might just not work as expected yet.

## Building

To build this library, you will need Zig nightly 0.8.0, as well as [`gyro`] package manager.

[`gyro`]: https://github.com/mattnite/gyro

This library consumes the C API of the Wasmtime project which you can download with every release of
Wasmtime. It relies on version `v0.24.0` of Wasmtime and you need it to build tests and examples.
You can download the library from [here].

After you unpack it, if you installed the lib in path that is not your system search path for lld,
you can add the installed path to the build command using the following flag

```
gyro build --search-prefix=<path-to-libwasmtime>
```

[here]: https://github.com/bytecodealliance/wasmtime/releases/tag/v0.24.0

## Running examples

### `simple.zig`

The `simple.zig` example is equivalent to [`hello.c`] example in Wasmtime. You can run it with

```
gyro build run -Dexample=simple
```

Optionally, if you installed `libwasmtime` into some custom path, you can tell zig where to find it
with

```
gyro build run -Dexample=simple --search-prefix=<path-to-libwasmtime>
```

[`hello.c`]: https://github.com/bytecodealliance/wasmtime/blob/master/examples/hello.c

