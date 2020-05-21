# wasmtime-zig

Zig embedding of [Wasmtime]

[Wasmtime]: https://github.com/bytecodealliance/wasmtime

## Disclaimer

This is a very much work-in-progress library so drastic changes to the API are anything
but expected, and things might just not work as expected yet.

## Building

This library consumes the C API of the Wasmtime project which you can download with every release of
Wasmtime. It is envisaged that this library will pack the library for you, however, until then, you'll
need to manually download the Wasmtime lib package v0.16.0 from [here]. After you do that, unpack the
contents in `lib` dir in the root of this repo.

[here]: https://github.com/bytecodealliance/wasmtime/releases/tag/v0.16.0

Then you can run

```
zig build
```

## Running examples

### `simple.zig`

The `simple.zig` example is equivalent to [`hello.c`] example in Wasmtime. You can run it with

```
zig build example-simple
```

[`hello.c`]: https://github.com/bytecodealliance/wasmtime/blob/master/examples/hello.c
