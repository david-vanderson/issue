// This file is re-generated by kickzig when a message is added or removed.
// DO NOT EDIT THIS FILE.
const std = @import("std");

const BackToFrontDispatcher = @import("backtofront/general_dispatcher.zig").GeneralDispatcher;
const FrontToBackDispatcher = @import("fronttoback/general_dispatcher.zig").GeneralDispatcher;
const ExitFn = @import("various").ExitFn;


/// FrontendToBackend is each message's channel.
pub const FrontendToBackend = struct {
    allocator: std.mem.Allocator,
    // Dispatcher.
    general_dispatcher: *FrontToBackDispatcher,

    // Channels.

    pub fn deinit(self: *FrontendToBackend) void {
        self.general_dispatcher.deinit();
        self.allocator.destroy(self);
    }

    pub fn init(allocator: std.mem.Allocator, exit: ExitFn) !*FrontendToBackend {
        var self: *FrontendToBackend = try allocator.create(FrontendToBackend);
        self.allocator = allocator;
        self.general_dispatcher = try FrontToBackDispatcher.init(allocator, exit);

        return self;
    }
};


/// BackendToFrontend is each message's channel.
pub const BackendToFrontend = struct {
    allocator: std.mem.Allocator,
    // Dispatcher.
    general_dispatcher: *BackToFrontDispatcher,
    // Channels.

    pub fn deinit(self: *BackendToFrontend) void {
        self.general_dispatcher.deinit();
        self.allocator.destroy(self);
    }

    pub fn init(allocator: std.mem.Allocator, exit: ExitFn) !*BackendToFrontend {
        var self: *BackendToFrontend = try allocator.create(BackendToFrontend);
        self.allocator = allocator;
        // Dispatcher.
        self.general_dispatcher = try BackToFrontDispatcher.init(allocator, exit);
        // Channels.

        return self;
    }
};

/// Trigger is each trigger.
pub const Trigger = struct {
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Trigger) void {
        self.allocator.destroy(self);
    }
    pub fn init(allocator: std.mem.Allocator, exit: ExitFn) !*Trigger {
        var self: *Trigger = try allocator.create(Trigger);
        self.allocator = allocator;
    
        _ = exit;

        return self;
    }
};
