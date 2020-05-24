# wasmtime-zig
[<img alt="github" src="https://img.shields.io/badge/github-kubkon/wasmtime--zig-8da0cb?style=for-the-badge&labelColor=555555&logo=github" height="20">](https://github.com/kubkon/wasmtime-zig)
[<img alt="build status" src="https://img.shields.io/github/workflow/status/kubkon/wasmtime-zig/CI/master?style=for-the-badge" height="20">](https://github.com/kubkon/wasmtime-zig/actions?query=branch%3Amaster)

Zig embedding of [Wasmtime]

[Wasmtime]: https://github.com/bytecodealliance/wasmtime

## Disclaimer

This is a very much work-in-progress library so drastic changes to the API are anything
but expected, and things might just not work as expected yet.

## Building

This library consumes the C API of the Wasmtime project which you can download with every release of
Wasmtime. It relies on version `v0.16.0` of Wasmtime and you need it to build tests and examples.
You can download the library from [here].

After you unpack it, if you installed the lib in path that is not your system search path for lld,
you can add the installed path to the build command using the following flag

```
zig build -Dlibrary-search-path=<path-to-libwasmtime>
```

[here]: https://github.com/bytecodealliance/wasmtime/releases/tag/v0.16.0

## Running examples

### `simple.zig`

The `simple.zig` example is equivalent to [`hello.c`] example in Wasmtime. You can run it with

```
zig build example-simple
```

Optionally, if you installed `libwasmtime` into some custom path, you can tell zig where to find it
with

```
zig build example-simple -Dlibrary-search-path=<path-to-libwasmtime>
```

[`hello.c`]: https://github.com/bytecodealliance/wasmtime/blob/master/examples/hello.c
