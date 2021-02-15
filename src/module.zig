const std = @import("std");
const mem = std.mem;
const leb = std.leb;
const ArrayList = std.ArrayList;
const Instruction = @import("instruction.zig").Instruction;
const FuncType = @import("common.zig").FuncType;
const ValueType = @import("common.zig").ValueType;
const Import = @import("common.zig").Import;
const Export = @import("common.zig").Export;
const Limit = @import("common.zig").Limit;
const LimitType = @import("common.zig").LimitType;
const Mutability = @import("common.zig").Mutability;
const Global = @import("common.zig").Global;
const Element = @import("common.zig").Element;
const Code = @import("common.zig").Code;
const Segment = @import("common.zig").Segment;
const Tag = @import("common.zig").Tag;
const common = @import("common.zig");
const instruction = @import("instruction.zig");
const Interpreter = @import("interpreter.zig").Interpreter;
const Store = @import("store.zig").Store;

pub const Module = struct {
    alloc: *mem.Allocator,
    module: []const u8 = undefined,
    buf: std.io.FixedBufferStream([]const u8) = undefined,
    version: u32 = 0,
    customs: ArrayList(Custom),
    types: ArrayList(FuncType),
    value_types: ArrayList(ValueType),
    imports: ArrayList(Import),
    functions: ArrayList(u32),
    tables: ArrayList(Limit),
    memories: ArrayList(Limit),
    globals: ArrayList(Global),
    exports: ArrayList(Export),
    start: u32,
    elements: ArrayList(Segment),
    codes: ArrayList(Code),
    datas: ArrayList(Segment),

    pub fn init(alloc: *mem.Allocator, module: []const u8) Module {
        return Module{
            .alloc = alloc,
            .module = module,
            .buf = std.io.fixedBufferStream(module),
            .customs = ArrayList(Custom).init(alloc),
            .types = ArrayList(FuncType).init(alloc),
            .value_types = ArrayList(ValueType).init(alloc),
            .imports = ArrayList(Import).init(alloc),
            .functions = ArrayList(u32).init(alloc),
            .tables = ArrayList(Limit).init(alloc),
            .memories = ArrayList(Limit).init(alloc),
            .globals = ArrayList(Global).init(alloc),
            .exports = ArrayList(Export).init(alloc),
            .start = undefined,
            .elements = ArrayList(Segment).init(alloc),
            .codes = ArrayList(Code).init(alloc),
            .datas = ArrayList(Segment).init(alloc),
        };
    }

    pub fn decode(self: *Module) !void {
        const rd = self.buf.reader();

        const magic = try rd.readBytesNoEof(4);
        if (!mem.eql(u8, magic[0..], "\x00asm")) return error.MagicNumberNotFound;

        const version = try rd.readIntLittle(u32);

        var i: usize = 0;
        while (true) : (i += 1) {
            var section = self.decodeSection() catch |err| {
                switch (err) {
                    error.EndOfStream => break,
                    else => return err,
                }
            };
        }
    }

    pub fn decodeSection(self: *Module) !SectionType {
        const rd = self.buf.reader();
        const id: SectionType = @intToEnum(SectionType, try rd.readByte());

        const size = try leb.readULEB128(u32, rd);

        _ = switch (id) {
            .Custom => try self.decodeCustomSection(size),
            .Type => try self.decodeTypeSection(),
            .Import => try self.decodeImportSection(),
            .Function => try self.decodeFunctionSection(),
            .Table => try self.decodeTableSection(),
            .Memory => try self.decodeMemorySection(),
            .Global => try self.decodeGlobalSection(),
            .Export => try self.decodeExportSection(),
            .Start => try self.decodeStartSection(),
            .Element => try self.decodeElementSection(size),
            .Code => try self.decodeCodeSection(),
            .Data => try self.decodeDataSection(size),
        };

        return id;
    }

    fn decodeTypeSection(self: *Module) !usize {
        const rd = self.buf.reader();
        const functype_count = try leb.readULEB128(u32, rd);

        var f: usize = 0;
        while (f < functype_count) : (f += 1) {
            const tag: u8 = try rd.readByte();
            if (tag != 0x60) return error.ExpectedFuncTypeTag;

            const param_count = try leb.readULEB128(u32, rd);
            const param_offset = self.value_types.items.len;

            {
                var i: usize = 0;
                while (i < param_count) : (i += 1) {
                    const v = try rd.readEnum(ValueType, .Little);
                    try self.value_types.append(v);
                }
            }

            const results_count = try leb.readULEB128(u32, rd);
            const results_offset = self.value_types.items.len;

            {
                var i: usize = 0;
                while (i < results_count) : (i += 1) {
                    const r = try rd.readEnum(ValueType, .Little);
                    try self.value_types.append(r);
                }
            }

            // TODO: rather than count we could store the first element / last element + 1
            // TODO: should we just index into the existing module data?
            try self.types.append(FuncType{
                .params_offset = param_offset,
                .params_count = param_count,
                .results_offset = results_offset,
                .results_count = results_count,
            });
        }

        return functype_count;
    }

    fn decodeImportSection(self: *Module) !usize {
        const rd = self.buf.reader();
        const count = try leb.readULEB128(u32, rd);

        var i: usize = 0;
        while (i < count) : (i += 1) {
            const module_name_length = try leb.readULEB128(u32, rd);
            const module_name = self.module[rd.context.pos .. rd.context.pos + module_name_length];
            try rd.skipBytes(module_name_length, .{});

            const name_length = try leb.readULEB128(u32, rd);
            const name = self.module[rd.context.pos .. rd.context.pos + name_length];
            try rd.skipBytes(name_length, .{});

            const desc_tag = try rd.readEnum(Tag, .Little);
            const desc = try rd.readByte(); // TODO: not sure if this is a byte or leb

            try self.imports.append(Import{
                .module = module_name,
                .name = name,
                .desc_tag = desc_tag,
                .desc = desc,
            });
        }

        return count;
    }

    fn decodeFunctionSection(self: *Module) !usize {
        const rd = self.buf.reader();
        const count = try leb.readULEB128(u32, rd);

        var i: usize = 0;
        while (i < count) : (i += 1) {
            const type_index = try leb.readULEB128(u32, rd);
            try self.functions.append(type_index);
        }

        return count;
    }

    fn decodeTableSection(self: *Module) !usize {
        const rd = self.buf.reader();
        const count = try leb.readULEB128(u32, rd);

        const tag = try rd.readByte();
        if (tag != 0x70) return error.ExpectedTable;

        var i: usize = 0;
        while (i < count) : (i += 1) {
            const limit_type = try rd.readEnum(LimitType, .Little);
            switch (limit_type) {
                .Min => {
                    const min = try leb.readULEB128(u32, rd);

                    try self.tables.append(Limit{
                        .min = min,
                        .max = min,
                    });
                },
                .MinMax => {
                    const min = try leb.readULEB128(u32, rd);
                    const max = try leb.readULEB128(u32, rd);

                    try self.tables.append(Limit{
                        .min = min,
                        .max = max,
                    });
                },
            }
        }

        return count;
    }

    fn decodeMemorySection(self: *Module) !usize {
        const rd = self.buf.reader();
        const count = try leb.readULEB128(u32, rd);

        var i: usize = 0;
        while (i < count) : (i += 1) {
            const limit_type = try rd.readEnum(LimitType, .Little);
            switch (limit_type) {
                .Min => {
                    const min = try leb.readULEB128(u32, rd);

                    try self.memories.append(Limit{
                        .min = min,
                        .max = std.math.maxInt(u32),
                    });
                },
                .MinMax => {
                    const min = try leb.readULEB128(u32, rd);
                    const max = try leb.readULEB128(u32, rd);

                    try self.memories.append(Limit{
                        .min = min,
                        .max = max,
                    });
                },
            }
        }

        return count;
    }

    fn decodeGlobalSection(self: *Module) !usize {
        const rd = self.buf.reader();
        const count = try leb.readULEB128(u32, rd);

        var i: usize = 0;
        while (i < count) : (i += 1) {
            const global_type = try rd.readEnum(ValueType, .Little);
            const mutability = try rd.readEnum(Mutability, .Little);
            const offset = rd.context.pos;

            var j: usize = 0;
            while (true) : (j += 1) {
                const byte = try rd.readByte();
                if (byte == @enumToInt(Instruction.End)) break;
            }
            const code = self.module[offset .. offset + j + 1];

            try self.globals.append(Global{
                .value_type = global_type,
                .mutability = mutability,
                .code = code,
            });
        }

        return count;
    }

    fn decodeExportSection(self: *Module) !usize {
        const rd = self.buf.reader();
        const count = try leb.readULEB128(u32, rd);

        var i: usize = 0;
        while (i < count) : (i += 1) {
            const name_length = try leb.readULEB128(u32, rd);
            const name = self.module[rd.context.pos .. rd.context.pos + name_length];
            try rd.skipBytes(name_length, .{});

            const tag = try rd.readEnum(Tag, .Little);
            const index = try leb.readULEB128(u32, rd);

            try self.exports.append(Export{
                .name = name,
                .tag = tag,
                .index = index,
            });
        }

        return count;
    }

    fn decodeStartSection(self: *Module) !usize {
        const rd = self.buf.reader();
        const index = try leb.readULEB128(u32, rd);

        self.start = index;

        return 1;
    }

    fn decodeElementSection(self: *Module, size: u32) !usize {
        const rd = self.buf.reader();
        const count = try leb.readULEB128(u32, rd);

        var i: usize = 0;
        while (i < count) : (i += 1) {
            const table_index = try leb.readULEB128(u32, rd);

            const expr_start = rd.context.pos;
            const expr = self.module[expr_start..];
            const meta = try instruction.findExprEnd(expr);

            try rd.skipBytes(meta.offset, .{});

            // Number of u32's in our data (not the length in bytes!)
            const data_length = try leb.readULEB128(u32, rd);
            const data_start = rd.context.pos;

            var j: usize = 0;
            while (j < data_length) : (j += 1) {
                // When we pre-process all this data we can just store this
                // but for the moment we're just using it to skip over
                _ = try leb.readULEB128(u32, rd);
            }

            try self.elements.append(Segment{
                .index = table_index,
                .offset = self.module[expr_start .. expr_start + meta.offset],
                .count = data_length,
                .data = self.module[data_start..rd.context.pos],
            });
        }

        return 1;
    }

    fn decodeCodeSection(self: *Module) !usize {
        const rd = self.buf.reader();
        var x = rd.context.pos;
        const count = try leb.readULEB128(u32, rd);

        var i: usize = 0;
        while (i < count) : (i += 1) {
            const size = try leb.readULEB128(u32, rd); // includes bytes defining locals
            const offset = rd.context.pos;
            try rd.skipBytes(size, .{});

            // TODO: run some verification on the code
            //      e.g. check last value is End instruction
            const locals_and_code = self.module[offset..rd.context.pos];
            const locals_definitions_count = locals_and_code[0]; // probably a leb so this won't work
            const locals_definitions = locals_and_code[1 .. 1 + 2 * locals_definitions_count];
            var j: usize = 0;
            var locals_count: usize = 0;
            while (j < locals_definitions_count) : (j += 1) {
                const definition = locals_definitions[2 * j .. 2 * j + 2];
                locals_count += definition[0];
            }

            const code = locals_and_code[1 + 2 * locals_definitions_count ..];

            try self.codes.append(Code{
                .locals = locals_definitions,
                .locals_count = locals_count,
                .code = code,
            });
        }

        return count;
    }

    fn decodeDataSection(self: *Module, size: u32) !usize {
        const rd = self.buf.reader();
        var section_offset = rd.context.pos;
        const count = try leb.readULEB128(u32, rd);

        var i: usize = 0;
        while (i < count) : (i += 1) {
            const mem_idx = try leb.readULEB128(u32, rd);

            const expr_start = rd.context.pos;
            const expr = self.module[expr_start..];
            const meta = try instruction.findExprEnd(expr);

            try rd.skipBytes(meta.offset, .{});
            const data_length = try leb.readULEB128(u32, rd);

            const offset = rd.context.pos;

            try rd.skipBytes(data_length, .{});

            try self.datas.append(Segment{
                .index = mem_idx,
                .offset = self.module[expr_start .. expr_start + meta.offset],
                .count = data_length,
                .data = self.module[offset..rd.context.pos],
            });
        }

        const remaining_data = size - (rd.context.pos - section_offset);
        try rd.skipBytes(remaining_data, .{});

        return count;
    }

    fn decodeCustomSection(self: *Module, size: u32) !usize {
        const rd = self.buf.reader();
        const offset = rd.context.pos;

        const name_length = try leb.readULEB128(u32, rd);
        const name = self.module[rd.context.pos .. rd.context.pos + name_length];
        try rd.skipBytes(name_length, .{});

        const remaining_size = size - (rd.context.pos - offset);

        const data = self.module[rd.context.pos .. rd.context.pos + remaining_size];
        try rd.skipBytes(remaining_size, .{});

        try self.customs.append(Custom{
            .name = name,
            .data = data,
        });

        return 1;
    }

    pub fn getExport(self: *Module, tag: Tag, name: []const u8) !usize {
        for (self.exports.items) |exported| {
            if (tag == exported.tag and mem.eql(u8, name, exported.name)) return exported.index;
        }

        return error.ExportNotFound;
    }

    pub fn signaturesEqual(self: *Module, a: FuncType, b: FuncType) bool {
        if (a.params_count != b.params_count) return false;
        if (a.results_count != b.results_count) return false;

        const params_a = self.value_types.items[a.params_offset .. a.params_offset + a.params_count];
        const params_b = self.value_types.items[b.params_offset .. b.params_offset + b.params_count];

        for (params_a) |p_a, i| {
            if (p_a != params_b[i]) return false;
        }

        const results_a = self.value_types.items[a.results_offset .. a.results_offset + a.results_count];
        const results_b = self.value_types.items[b.results_offset .. b.results_offset + b.results_count];

        for (results_a) |r_a, i| {
            if (r_a != results_b[i]) return false;
        }

        return true;
    }

    pub fn instantiate(self: *Module) !ModuleInstance {
        var store = Store.init(self.alloc);
        var inst = ModuleInstance{
            .module = self,
            .store = store,
        };

        // 2. Initialise globals
        const globals_count = self.globals.items.len;
        try inst.store.allocGlobals(globals_count);

        // 3. Initialise memories
        const memories_count = self.memories.items.len;
        try inst.store.addMemories(memories_count);

        for (self.memories.items) |memory_definition, i| {
            _ = try inst.store.memories.items[i].grow(memory_definition.min);
            inst.store.memories.items[i].max_size = memory_definition.max;
        }

        // 4. Initialise memories with data
        for (self.datas.items) |data, i| {
            // TODO: validate mem_idx
            const memory = inst.store.memories.items[data.index].asSlice();
            const data_len = data.data.len;

            // TODO: execute rather than take middle byte
            const offset = data.offset[1];
            mem.copy(u8, memory[offset .. offset + data_len], data.data);
        }

        // 5. Initialise tables
        const tables_count = self.tables.items.len;
        for (self.tables.items) |table_def, i| {
            const table = try inst.store.addTable(table_def.max);
        }

        // 6. Initialise from elements
        for (self.elements.items) |element_def, i| {
            const table_index = element_def.index;
            const table = inst.store.tables.items[table_index];

            // TODO: execute rather than take middle byte
            const offset = element_def.offset[1];
            var data = element_def.data;
            var j: usize = 0;
            while (j < element_def.count) : (j += 1) {
                const value = try instruction.readULEB128Mem(u32, &data);
                table.data[offset + j] = value;
            }
        }

        return inst;
    }

    pub fn print(module: *Module) void {
        std.debug.warn("    Types: {}\n", .{module.types.items.len});
        std.debug.warn("Functions: {}\n", .{module.functions.items.len});
        std.debug.warn("   Tables: {}\n", .{module.tables.items.len});
        std.debug.warn(" Memories: {}\n", .{module.memories.items.len});
        std.debug.warn("  Globals: {}\n", .{module.globals.items.len});
        std.debug.warn("  Exports: {}\n", .{module.exports.items.len});
        std.debug.warn("  Imports: {}\n", .{module.imports.items.len});
        std.debug.warn("    Codes: {}\n", .{module.codes.items.len});
        std.debug.warn("    Datas: {}\n", .{module.datas.items.len});
        std.debug.warn("  Customs: {}\n", .{module.customs.items.len});
    }
};

// Default stack sizes
const InterpreterOptions = struct {
    operand_stack_size: comptime_int = 64 * 1024,
    control_stack_size: comptime_int = 64 * 1024,
    label_stack_size: comptime_int = 64 * 1024,
};

pub const ModuleInstance = struct {
    module: *Module,
    store: Store,

    // invoke:
    //  1. Lookup our function by name with getExport
    //  2. Get the function type signature
    //  3. Check that the incoming arguments in `args` match the function signature
    //  4. Check that the return type in `Result` matches the function signature
    //  5. Get the code for our function
    //  6. Set up the stacks (operand stack, control stack)
    //  7. Push a control frame and our parameters
    //  8. Execute our function
    //  9. Pop our result and return it
    pub fn invoke(self: *ModuleInstance, name: []const u8, args: anytype, comptime Result: type, comptime options: InterpreterOptions) !Result {
        // 1.
        const index = try self.module.getExport(.Func, name);
        if (index >= self.module.functions.items.len) return error.FuncIndexExceedsTypesLength;

        const function_type_index = self.module.functions.items[index];

        // 2.
        const func_type = self.module.types.items[function_type_index];
        const params = self.module.value_types.items[func_type.params_offset .. func_type.params_offset + func_type.params_count];
        const results = self.module.value_types.items[func_type.results_offset .. func_type.results_offset + func_type.results_count];

        if (params.len != args.len) return error.ParamCountMismatch;

        // 3. check the types of params
        inline for (args) |arg, i| {
            if (params[i] != common.toValueType(@TypeOf(arg))) return error.ParamTypeMismatch;
        }

        // 4. check the result type
        if (results.len > 1) return error.OnlySingleReturnValueSupported;
        if (Result != void and results.len == 1) {
            if (results[0] != common.toValueType(Result)) return error.ResultTypeMismatch;
        }

        // 5. get the function bytecode
        const func = self.module.codes.items[index];

        // 6. set up our stacks
        var op_stack_mem: [options.operand_stack_size]u64 = [_]u64{0} ** options.operand_stack_size;
        var frame_stack_mem: [options.control_stack_size]Interpreter.Frame = [_]Interpreter.Frame{undefined} ** options.control_stack_size;
        var label_stack_mem: [options.label_stack_size]Interpreter.Label = [_]Interpreter.Label{undefined} ** options.control_stack_size;
        var interp = Interpreter.init(op_stack_mem[0..], frame_stack_mem[0..], label_stack_mem[0..], self);

        // I think everything below here should probably live in interpret

        const locals_start = interp.op_stack.len;

        // 7b. push params
        inline for (args) |arg, i| {
            try interp.pushOperand(@TypeOf(arg), arg);
        }

        // 7c. push (i.e. make space for) locals
        var i: usize = 0;
        while (i < func.locals_count) : (i += 1) {
            try interp.pushOperand(u64, 0);
        }

        // 7a. push control frame
        try interp.pushFrame(Interpreter.Frame{
            .op_stack_len = locals_start,
            .label_stack_len = interp.label_stack.len,
            .return_arity = results.len,
        }, func.locals_count + params.len);

        // 7a.2. push label for our implicit function block. We know we don't have
        // any code to execute after calling invoke, but we will need to
        // pop a Label
        try interp.pushLabel(Interpreter.Label{
            .return_arity = results.len,
            .op_stack_len = locals_start,
            .continuation = func.code[0..0],
        });

        // 8. Execute our function
        try interp.invoke(func.code);

        // 9.
        if (Result == void) return;
        return try interp.popOperand(Result);
    }

    // invokeDynamic
    //
    // Similar to invoke, but without some type checking
    pub fn invokeDynamic(self: *ModuleInstance, name: []const u8, in: []u64, out: []u64, comptime options: InterpreterOptions) !void {
        // 1.
        const index = try self.module.getExport(.Func, name);
        if (index >= self.module.functions.items.len) return error.FuncIndexExceedsTypesLength;

        const function_type_index = self.module.functions.items[index];

        // 2.
        const func_type = self.module.types.items[function_type_index];
        const params = self.module.value_types.items[func_type.params_offset .. func_type.params_offset + func_type.params_count];
        const results = self.module.value_types.items[func_type.results_offset .. func_type.results_offset + func_type.results_count];

        if (params.len != in.len) return error.ParamCountMismatch;

        // 3. check the types of params
        // for (args) |arg, i| {
        // if (params[i] != common.toValueType(@TypeOf(arg))) return error.ParamTypeMismatch;
        // }

        // 4. check the result type
        if (results.len > 1) return error.OnlySingleReturnValueSupported;
        // if (Result != void and results.len == 1) {
        // if (results[0] != common.toValueType(Result)) return error.ResultTypeMismatch;
        // }

        // 5. get the function bytecode
        const func = self.module.codes.items[index];

        // 6. set up our stacks
        var op_stack_mem: [options.operand_stack_size]u64 = [_]u64{0} ** options.operand_stack_size;
        var frame_stack_mem: [options.control_stack_size]Interpreter.Frame = [_]Interpreter.Frame{undefined} ** options.control_stack_size;
        var label_stack_mem: [options.label_stack_size]Interpreter.Label = [_]Interpreter.Label{undefined} ** options.control_stack_size;
        var interp = Interpreter.init(op_stack_mem[0..], frame_stack_mem[0..], label_stack_mem[0..], self);

        // I think everything below here should probably live in interpret

        const locals_start = interp.op_stack.len;

        // 7b. push params
        for (in) |arg, i| {
            try interp.pushOperand(u64, arg);
        }

        // 7c. push (i.e. make space for) locals
        var i: usize = 0;
        while (i < func.locals_count) : (i += 1) {
            try interp.pushOperand(u64, 0);
        }

        // 7a. push control frame
        try interp.pushFrame(Interpreter.Frame{
            .op_stack_len = locals_start,
            .label_stack_len = interp.label_stack.len,
            .return_arity = results.len,
        }, func.locals_count + params.len);

        // 7a.2. push label for our implicit function block. We know we don't have
        // any code to execute after calling invoke, but we will need to
        // pop a Label
        try interp.pushLabel(Interpreter.Label{
            .return_arity = results.len,
            .op_stack_len = locals_start,
            .continuation = func.code[0..0],
        });

        // 8. Execute our function
        try interp.invoke(func.code);

        // 9.
        for (out) |o, out_index| {
            out[out_index] = try interp.popOperand(u64);
        }
    }
};

const Section = struct {
    id: SectionType,
    size: u32,
    contents: []const u8,
};

const Custom = struct {
    name: []const u8,
    data: []const u8,
};

const SectionType = enum(u8) {
    Custom = 0x00,
    Type = 0x01,
    Import = 0x02,
    Function = 0x03,
    Table = 0x04,
    Memory = 0x05,
    Global = 0x06,
    Export = 0x07,
    Start = 0x08,
    Element = 0x09,
    Code = 0x0a,
    Data = 0x0b,
};

const testing = std.testing;

test "module loading (simple add function)" {
    const ArenaAllocator = std.heap.ArenaAllocator;
    var arena = ArenaAllocator.init(testing.allocator);
    defer _ = arena.deinit();

    const bytes = @embedFile("../test/test.wasm");

    var module = Module.init(&arena.allocator, bytes);
    try module.decode();
    var modinst = try module.instantiate();

    const result = try modinst.invoke("add", .{ @as(i32, 22), @as(i32, 23) }, i32, .{});
    testing.expectEqual(@as(i32, 45), result);
}

test "module loading (fib)" {
    const ArenaAllocator = std.heap.ArenaAllocator;
    var arena = ArenaAllocator.init(testing.allocator);
    defer _ = arena.deinit();

    const bytes = @embedFile("../test/fib.wasm");

    var module = Module.init(&arena.allocator, bytes);
    try module.decode();
    var modinst = try module.instantiate();

    testing.expectEqual(@as(i32, 1), try modinst.invoke("fib", .{@as(i32, 0)}, i32, .{}));
    testing.expectEqual(@as(i32, 1), try modinst.invoke("fib", .{@as(i32, 1)}, i32, .{}));
    testing.expectEqual(@as(i32, 2), try modinst.invoke("fib", .{@as(i32, 2)}, i32, .{}));
    testing.expectEqual(@as(i32, 3), try modinst.invoke("fib", .{@as(i32, 3)}, i32, .{}));
    testing.expectEqual(@as(i32, 5), try modinst.invoke("fib", .{@as(i32, 4)}, i32, .{}));
    testing.expectEqual(@as(i32, 8), try modinst.invoke("fib", .{@as(i32, 5)}, i32, .{}));
    testing.expectEqual(@as(i32, 13), try modinst.invoke("fib", .{@as(i32, 6)}, i32, .{}));
}

test "module loading (fact)" {
    const ArenaAllocator = std.heap.ArenaAllocator;
    var arena = ArenaAllocator.init(testing.allocator);
    defer _ = arena.deinit();

    const bytes = @embedFile("../test/fact.wasm");

    var module = Module.init(&arena.allocator, bytes);
    try module.decode();
    var modinst = try module.instantiate();

    testing.expectEqual(@as(i32, 1), try modinst.invoke("fact", .{@as(i32, 1)}, i32, .{}));
    testing.expectEqual(@as(i32, 2), try modinst.invoke("fact", .{@as(i32, 2)}, i32, .{}));
    testing.expectEqual(@as(i32, 6), try modinst.invoke("fact", .{@as(i32, 3)}, i32, .{}));
    testing.expectEqual(@as(i32, 24), try modinst.invoke("fact", .{@as(i32, 4)}, i32, .{}));
    testing.expectEqual(@as(i32, 479001600), try modinst.invoke("fact", .{@as(i32, 12)}, i32, .{}));
}
