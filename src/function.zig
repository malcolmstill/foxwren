const std = @import("std");
const ValueType = @import("common.zig").ValueType;
const Interpreter = @import("interpreter.zig").Interpreter;
const Instance = @import("instance.zig").Instance;
const Opcode = @import("instruction.zig").Opcode;
const Range = @import("common.zig").Range;

pub const Function = union(enum) {
    function: struct {
        locals: []const u8,
        locals_count: usize,
        code: []Instruction,
        params: []const ValueType,
        results: []const ValueType,
        instance: usize,
    },
    host_function: struct {
        func: fn (*Interpreter) anyerror!void,
        params: []const ValueType,
        results: []const ValueType,
    },
};

pub const Code = struct {
    locals: []const u8,
    locals_count: usize,
    code: Range,
};

pub const Instruction = union(Opcode) {
    @"unreachable": void,
    nop: void,
    block: struct {
        param_arity: usize,
        return_arity: usize,
        continuation: Range,
    },
    loop: struct {
        param_arity: usize,
        return_arity: usize,
        continuation: Range,
    },
    @"if": struct {
        param_arity: usize,
        return_arity: usize,
        continuation: Range,
        else_continuation: ?Range,
    },
    @"else": void,
    end: void,
    br: u32,
    br_if: u32,
    br_table: struct {
        ls: Range,
        ln: u32,
    },
    @"return": void,
    call: usize, // u32?
    call_indirect: struct {
        @"type": u32,
        table: u32,
    },
    drop: void,
    select: void,
    @"local.get": u32,
    @"local.set": u32,
    @"local.tee": u32,
    @"global.get": u32,
    @"global.set": u32,
    @"i32.load": struct {
        alignment: u32,
        offset: u32,
    },
    @"i64.load": struct {
        alignment: u32,
        offset: u32,
    },
    @"f32.load": struct {
        alignment: u32,
        offset: u32,
    },
    @"f64.load": struct {
        alignment: u32,
        offset: u32,
    },
    @"i32.load8_s": struct {
        alignment: u32,
        offset: u32,
    },
    @"i32.load8_u": struct {
        alignment: u32,
        offset: u32,
    },
    @"i32.load16_s": struct {
        alignment: u32,
        offset: u32,
    },
    @"i32.load16_u": struct {
        alignment: u32,
        offset: u32,
    },
    @"i64.load8_s": struct {
        alignment: u32,
        offset: u32,
    },
    @"i64.load8_u": struct {
        alignment: u32,
        offset: u32,
    },
    @"i64.load16_s": struct {
        alignment: u32,
        offset: u32,
    },
    @"i64.load16_u": struct {
        alignment: u32,
        offset: u32,
    },
    @"i64.load32_s": struct {
        alignment: u32,
        offset: u32,
    },
    @"i64.load32_u": struct {
        alignment: u32,
        offset: u32,
    },
    @"i32.store": struct {
        alignment: u32,
        offset: u32,
    },
    @"i64.store": struct {
        alignment: u32,
        offset: u32,
    },
    @"f32.store": struct {
        alignment: u32,
        offset: u32,
    },
    @"f64.store": struct {
        alignment: u32,
        offset: u32,
    },
    @"i32.store8": struct {
        alignment: u32,
        offset: u32,
    },
    @"i32.store16": struct {
        alignment: u32,
        offset: u32,
    },
    @"i64.store8": struct {
        alignment: u32,
        offset: u32,
    },
    @"i64.store16": struct {
        alignment: u32,
        offset: u32,
    },
    @"i64.store32": struct {
        alignment: u32,
        offset: u32,
    },
    @"memory.size": u32,
    @"memory.grow": u32,
    @"i32.const": i32,
    @"i64.const": i64,
    @"f32.const": f32,
    @"f64.const": f64,
    @"i32.eqz": void,
    @"i32.eq": void,
    @"i32.ne": void,
    @"i32.lt_s": void,
    @"i32.lt_u": void,
    @"i32.gt_s": void,
    @"i32.gt_u": void,
    @"i32.le_s": void,
    @"i32.le_u": void,
    @"i32.ge_s": void,
    @"i32.ge_u": void,
    @"i64.eqz": void,
    @"i64.eq": void,
    @"i64.ne": void,
    @"i64.lt_s": void,
    @"i64.lt_u": void,
    @"i64.gt_s": void,
    @"i64.gt_u": void,
    @"i64.le_s": void,
    @"i64.le_u": void,
    @"i64.ge_s": void,
    @"i64.ge_u": void,
    @"f32.eq": void,
    @"f32.ne": void,
    @"f32.lt": void,
    @"f32.gt": void,
    @"f32.le": void,
    @"f32.ge": void,
    @"f64.eq": void,
    @"f64.ne": void,
    @"f64.lt": void,
    @"f64.gt": void,
    @"f64.le": void,
    @"f64.ge": void,
    @"i32.clz": void,
    @"i32.ctz": void,
    @"i32.popcnt": void,
    @"i32.add": void,
    @"i32.sub": void,
    @"i32.mul": void,
    @"i32.div_s": void,
    @"i32.div_u": void,
    @"i32.rem_s": void,
    @"i32.rem_u": void,
    @"i32.and": void,
    @"i32.or": void,
    @"i32.xor": void,
    @"i32.shl": void,
    @"i32.shr_s": void,
    @"i32.shr_u": void,
    @"i32.rotl": void,
    @"i32.rotr": void,
    @"i64.clz": void,
    @"i64.ctz": void,
    @"i64.popcnt": void,
    @"i64.add": void,
    @"i64.sub": void,
    @"i64.mul": void,
    @"i64.div_s": void,
    @"i64.div_u": void,
    @"i64.rem_s": void,
    @"i64.rem_u": void,
    @"i64.and": void,
    @"i64.or": void,
    @"i64.xor": void,
    @"i64.shl": void,
    @"i64.shr_s": void,
    @"i64.shr_u": void,
    @"i64.rotl": void,
    @"i64.rotr": void,
    @"f32.abs": void,
    @"f32.neg": void,
    @"f32.ceil": void,
    @"f32.floor": void,
    @"f32.trunc": void,
    @"f32.nearest": void,
    @"f32.sqrt": void,
    @"f32.add": void,
    @"f32.sub": void,
    @"f32.mul": void,
    @"f32.div": void,
    @"f32.min": void,
    @"f32.max": void,
    @"f32.copysign": void,
    @"f64.abs": void,
    @"f64.neg": void,
    @"f64.ceil": void,
    @"f64.floor": void,
    @"f64.trunc": void,
    @"f64.nearest": void,
    @"f64.sqrt": void,
    @"f64.add": void,
    @"f64.sub": void,
    @"f64.mul": void,
    @"f64.div": void,
    @"f64.min": void,
    @"f64.max": void,
    @"f64.copysign": void,
    @"i32.wrap_i64": void,
    @"i32.trunc_f32_s": void,
    @"i32.trunc_f32_u": void,
    @"i32.trunc_f64_s": void,
    @"i32.trunc_f64_u": void,
    @"i64.extend_i32_s": void,
    @"i64.extend_i32_u": void,
    @"i64.trunc_f32_s": void,
    @"i64.trunc_f32_u": void,
    @"i64.trunc_f64_s": void,
    @"i64.trunc_f64_u": void,
    @"f32.convert_i32_s": void,
    @"f32.convert_i32_u": void,
    @"f32.convert_i64_s": void,
    @"f32.convert_i64_u": void,
    @"f32.demote_f64": void,
    @"f64.convert_i32_s": void,
    @"f64.convert_i32_u": void,
    @"f64.convert_i64_s": void,
    @"f64.convert_i64_u": void,
    @"f64.promote_f32": void,
    @"i32.reinterpret_f32": void,
    @"i64.reinterpret_f64": void,
    @"f32.reinterpret_i32": void,
    @"f64.reinterpret_i64": void,
    @"i32.extend8_s": void,
    @"i32.extend16_s": void,
    @"i64.extend8_s": void,
    @"i64.extend16_s": void,
    @"i64.extend32_s": void,
    trunc_sat: u32,
};

pub fn calculateContinuations(parsed_code_offset: usize, code: []Instruction) !void {
    var offset: usize = 0;
    for (code) |*opcode| {
        switch (opcode.*) {
            .block => |*block_instr| {
                const end_offset = try findEnd(code[offset..]);

                const continuation = code[offset + end_offset + 1 ..];
                block_instr.continuation = Range{ .offset = parsed_code_offset + offset + end_offset + 1, .count = continuation.len };
            },
            .@"if" => |*if_instr| {
                const end_offset = try findEnd(code[offset..]);
                const optional_else_offset = try findElse(code[offset..]);

                const continuation = code[offset + end_offset + 1 ..];
                if_instr.continuation = Range{ .offset = parsed_code_offset + offset + end_offset + 1, .count = continuation.len };
                if (optional_else_offset) |else_offset| {
                    const else_continuation = code[offset + else_offset + 1 ..];
                    if_instr.else_continuation = Range{ .offset = parsed_code_offset + offset + else_offset + 1, .count = else_continuation.len };
                }
            },
            .loop => |*loop_instr| {
                // const end_offset = try findEnd(code[offset..]);
                const continuation = code[offset..];
                loop_instr.continuation = Range{ .offset = parsed_code_offset + offset, .count = continuation.len };
            },
            else => {},
        }
        offset += 1;
    }
}

pub fn findEnd(code: []Instruction) !usize {
    var offset: usize = 0;
    var i: usize = 1;
    for (code) |opcode| {
        defer offset += 1;
        if (offset == 0) {
            switch (opcode) {
                .block, .loop, .@"if" => continue,
                else => return error.NotBranchTarget,
            }
        }

        switch (opcode) {
            .block, .loop, .@"if" => i += 1,
            .end => i -= 1,
            else => {},
        }
        if (i == 0) return offset;
    }
    return error.CouldntFindEnd;
}

pub fn findElse(code: []Instruction) !?usize {
    var offset: usize = 0;
    var i: usize = 1;
    for (code) |opcode| {
        defer offset += 1;
        if (offset == 0) {
            switch (opcode) {
                .@"if" => continue,
                else => return error.NotBranchTarget,
            }
        }

        switch (opcode) {
            .block, .@"if" => i += 1,
            .@"else" => {
                if (i < 2) i -= 1;
            },

            .end => i -= 1,
            else => {},
        }
        if (i == 0 and opcode == .end) return null;
        if (i == 0) return offset;

        // offset += 1;
    }
    return null;
}
