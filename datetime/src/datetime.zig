const std = @import("std");

pub const DateTime = struct {
    year: u32,
    month: u32,
    day: u32,
    hour: u32,
    minute: u32,
    second: u32,

    pub fn write(self: DateTime, writer: std.io.AnyWriter) !void {
        try writer.print(
            "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}",
            .{
                self.year,
                self.month,
                self.day,
                self.hour,
                self.minute,
                self.second,
            },
        );
    }
};

pub fn now() DateTime {
    const epoch_seconds = std.time.epoch.EpochSeconds{
        .secs = @intCast(std.time.timestamp()),
    };

    const epoch_day = epoch_seconds.getEpochDay();
    const day_seconds = epoch_seconds.getDaySeconds();
    const year_day = epoch_day.calculateYearDay();
    const month_day = year_day.calculateMonthDay();

    return .{
        .year = year_day.year,
        .month = month_day.month.numeric(),
        .day = month_day.day_index + 1,
        .hour = day_seconds.getHoursIntoDay(),
        .minute = day_seconds.getMinutesIntoHour(),
        .second = day_seconds.getSecondsIntoMinute(),
    };
}

test "datetime conversion" {
    var buffer: [32]u8 = undefined;

    const datetime = now();
    const formatted = try datetime.format(&buffer);
    std.debug.print("\nFormatted time: {s}\n", .{formatted});
}
