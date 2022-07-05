const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const testing = std.testing;

pub const Slab = struct {
    list: ArrayList(u64),
    next: u64,

    pub fn init(allocator: Allocator) Slab {
        const s = Slab{
            .list = ArrayList(u64).init(allocator),
            .next = 0,
        };

        return s;
    }

    pub fn allocate(self: *Slab) !u64 {
        if (self.next == self.list.items.len) {
            try self.list.append(self.next + 1);
        }
        const ret = self.next;
        self.next = self.list.items[ret];
        return ret;
    }

    pub fn deallocate(self: *Slab, slot: u64) void {
        self.list.items[slot] = self.next;
        self.next = slot;
    }
};

test "wasmtime.Slab" {
    var slab = Slab.init(std.heap.c_allocator);

    var al = try slab.allocate();
    if (al != 0) {
        @panic("bad alloc");
    }
    al = try slab.allocate();
    if (al != 1) {
        @panic("bad alloc");
    }
    slab.deallocate(0);
    al = try slab.allocate();
    if (al != 0) {
        @panic("bad alloc");
    }
    al = try slab.allocate();
    if (al != 2) {
        @panic("bad alloc");
    }
}
