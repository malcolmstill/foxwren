<h1 align="center">foxwren</h1>

<div align="center">
  <img src="https://github.com/malcolmstill/web-assembly-logo/blob/master/dist/icon/web-assembly-icon-128px.png" alt="WebAssembly logo: a purple-blue square containing the uppercase letters W A. The square has a semicirclular notch on the top edge in the middle" />
  <br />
  <strong>A WebAssembly runtime environment (written in Zig)</strong>
</div>

## About

`foxwren` is a library for executing WebAssembly embedded in [Zig](https://ziglang.org) programs.

## Example

From `examples/fib`:

```zig
const std = @import("std");
const foxwren = @import("foxwren");
const Module = foxwren.Module;
const Store = foxwren.Store;
const Instance = foxwren.Instance;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const ArenaAllocator = std.heap.ArenaAllocator;
var gpa = GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    defer _ = gpa.deinit();

    var arena = ArenaAllocator.init(&gpa.allocator);
    defer _ = arena.deinit();

    const bytes = @embedFile("../../../test/fib.wasm");

    var store: Store = Store.init(&arena.allocator);

    var module = Module.init(&arena.allocator, bytes);
    try module.decode();

    var new_inst = Instance.init(&arena.allocator, &store, module);
    const index = try store.addInstance(new_inst);
    var inst = try store.instance(index);
    try inst.instantiate(index);

    const n = 28;
    var in = [1]u64{n};
    var out = [1]u64{0};
    try inst.invoke("fib", in[0..], out[0..], .{});
    std.debug.warn("fib({}) = {}\n", .{ n, @bitCast(i32, @truncate(u32, out[0])) });
}
```

## Requirements

### Compile-time

- Zig 0.8.0

### Run-time

- None, zig generates static binaries:

```bash
➜  foxwren git:(master) ✗ ldd fib
        not a dynamic executable
```

## Goals

- To allow the author, gentle reader, to understand WebAssembly
- Embed WebAssembly programs in other zig programs
- Be fast enough to be useful
- Implement some of the proposed extensions
- Implement WASI

## Status

- The project is very much alpha quality
- The majority of the WebAssembly MVP spec testsuite passes (and is integrated into the CI) with a few exceptions and the type-checking validator code is not complete and so the `assert_invalid` tests are not included yet. See [#13](https://github.com/malcolmstill/foxwren/issues/13) and [#82](https://github.com/malcolmstill/foxwren/issues/82).
- Currently, only the MVP spec is implemented without any extensions other than multiple-return values.

## Running the testsuite

The testsuite requires a relatively recent version of `wabt` (specifically the `wast2json` tool). A `Dockerfile` is provided to avoid manually installing the dependency:

1. Build

```
docker build -t foxwren-test .
```

2. Run

```
docker run foxwren test
```