/// This is the back-end messenger's API.
/// This file is re-generated by kickzig when you you add or remove a message.
const std = @import("std");

const _startup_ = @import("startup");


/// Messenger is the collection of the back-end messengers.
/// These messengers are how the back-end communicate with the front-end.
pub const Messenger = struct {
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Messenger) void {
        self.allocator.destroy(self);
    }

    /// init constructs a Messenger.
    /// It initializes each unique message handler.
    pub fn init(startup: _startup_.Backend) !*Messenger {
        var messenger: *Messenger = try startup.allocator.create(Messenger);
        errdefer {
            startup.allocator.destroy(messenger);
        }
        messenger.allocator = startup.allocator;
        return messenger;
    }
};
