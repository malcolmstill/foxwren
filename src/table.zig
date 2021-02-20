const std = @import("std");
const mem = std.mem;

pub const Table = struct {
    data: []?u32,
    max: ?u32,

    pub fn init(alloc: *mem.Allocator, min: u32, max: ?u32) !Table {
        return Table{
            .data = try alloc.alloc(?u32, min),
            .max = max,
        };
    }

    pub fn lookup(self: *Table, index: u32) !u32 {
        if (index >= self.data.len) return error.OutOfBoundsMemoryAccess;
        return self.data[index] orelse return error.UndefinedElement;
    }

    pub fn set(self: *Table, index: u32, value: u32) !void {
        if (index >= self.data.len) return error.OutOfBoundsMemoryAccess;
        self.data[index] = value;
    }
};