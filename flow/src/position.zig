pub const Position = @This();

start: usize,
end: usize,

pub fn init(start: usize, end: usize) Position {
    return .{
        .start = start,
        .end = end,
    };
}

pub fn size(self: Position) usize {
    return self.end - self.start;
}
