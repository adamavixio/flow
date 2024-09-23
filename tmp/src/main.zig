pub fn tagIs(self: *Self, tag: Lexer.Lexeme.Tag) bool {
    return self.token.lexeme.isTag(tag);
}

pub fn valueIs(self: *Self, value: Lexer.Lexeme.Value) bool {
    return self.token.lexeme.isValue(value);
}

pub fn nextTagIs(self: *Self, tag: Lexer.Lexeme.Tag) bool {
    self.next();
    return self.tagIs(tag);
}

pub fn nextValueIs(self: *Self, value: Lexer.Lexeme.Value) bool {
    self.next();
    return self.valueIs(tag);
}

pub fn assertTagIs(self: *Self, tag: Lexer.Lexeme.Tag) !void {
    if (!self.tagIs(tag)) return Error.InvalidTag;
}

pub fn assertValueIs(self: *Self, value: Lexer.Lexeme.Value) !void {
    if (!self.valueIs()) return Error.InvalidValue;
}

pub fn assertNextTagIs(self: *Self, tag: Lexer.Lexeme.Tag) !void {
    self.next();
    return self.assertTagIs(tag);
}

pub fn assertNextValueIs(self: *Self, value: Lexer.Lexeme.Value) !void {
    self.next();
    return self.assertValueIs(value);
}
