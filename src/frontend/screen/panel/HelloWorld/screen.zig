const std = @import("std");
const dvui = @import("dvui");

const _channel_ = @import("channel");
const _embed_ = @import("embed");
const _startup_ = @import("startup");

fn next_reference_count() usize {
    const count = reference_count;
    reference_count += 1;
    if (reference_count == badges.len) {
        reference_count = 0;
    }
    return count;
}

const Container = @import("various").Container;
const ContainerLabel = @import("various").ContainerLabel;
const Content = @import("various").Content;
const MainView = @import("framers").MainView;
const Messenger = @import("view/messenger.zig").Messenger;
const Panels = @import("panels.zig").Panels;

var reference_count: usize = 0;
const Counts = [_][]const u8{ "First", "Second", "Third", "Fourth" };
const badges = [_][]const u8{
    _embed_.badge_zig_yellow_png,
    _embed_.badge_zig_pink_png,
    _embed_.badge_zig_green_png,
    _embed_.badge_zig_brown_png,
};

/// KICKZIG TODO:
/// Options will need to be customized.
/// Keep each value optional and set to null by default.
//KICKZIG TODO: Customize Options to your requirements.
pub const Options = struct {
    screen_name: ?[]const u8 = null, // Example field.
    opened_ok_modal: ?bool = null,
    opened_yesno_modal: ?bool = null,

    fn copyOf(values: Options, allocator: std.mem.Allocator) !*Options {
        var copy_of: *Options = try allocator.create(Options);
        // Null optional members for fn reset.
        copy_of.screen_name = null;
        copy_of.opened_ok_modal = null;
        copy_of.opened_yesno_modal = null;
        try copy_of.reset(allocator, values);
        errdefer copy_of.deinit();
        return copy_of;
    }

    fn deinit(self: *Options, allocator: std.mem.Allocator) void {
        // Screen name.
        if (self.screen_name) |member| {
            allocator.free(member);
        }
        allocator.destroy(self);
    }

    fn reset(
        self: *Options,
        allocator: std.mem.Allocator,
        settings: Options,
    ) !void {
        return self._reset(
            allocator,
            settings.screen_name,
            settings.opened_ok_modal,
            settings.opened_yesno_modal,
        );
    }

    fn _reset(
        self: *Options,
        allocator: std.mem.Allocator,
        screen_name: ?[]const u8,
        opened_ok_modal: ?bool,
        opened_yesno_modal: ?bool,
    ) !void {
        // Screen name.
        if (screen_name) |reset_value| {
            if (self.screen_name) |value| {
                allocator.free(value);
            }
            self.screen_name = try allocator.alloc(u8, reset_value.len);
            errdefer {
                self.screen_name = null;
                self.deinit();
            }
            @memcpy(@constCast(self.screen_name.?), reset_value);
        }
        // Opened the ok modal screen.
        if (opened_ok_modal) |reset_value| {
            self.opened_ok_modal = reset_value;
        }
        // Opened the yesno modal screen.
        if (opened_yesno_modal) |reset_value| {
            self.opened_yesno_modal = reset_value;
        }
    }
};

///The HelloWorld screen is a panel screen.
///Panel screens function by showing only one panel at a time.
///Panel screens are always content and so they implement Content.
///You can:
/// 1. Put this screen in the main menu. Add .HelloWorld to pub const sorted_main_menu_screen_tags in src/deps/main_menu/api.zig.
/// 2. Use this screen as content for a tab. Example: kickzig add-tab «new-screen-name» *HelloWorld «another-tab-name» ...
///
pub const Screen = struct {
    allocator: std.mem.Allocator,
    main_view: *MainView,
    all_panels: ?*Panels,
    messenger: ?*Messenger,
    send_channels: *_channel_.FrontendToBackend,
    receive_channels: *_channel_.BackendToFrontend,
    container: ?*Container,
    state: ?*Options,
    count: usize,

    const default_settings = Options{
        .screen_name = "HelloWorld",
    };
    /// init constructs this self, subscribes it to main_view and returns the error.
    pub fn init(
        startup: _startup_.Frontend,
        container: ?*Container,
        screen_options: Options,
    ) !*Screen {
        var self: *Screen = try startup.allocator.create(Screen);
        // KICKZIG EXAMPLE: Close down jobs fn.
        try startup.close_down_jobs.add("Example", self, &Screen.exampleCloseDownJob);
        errdefer startup.allocator.destroy(self);

        self.allocator = startup.allocator;
        self.main_view = startup.main_view;
        self.receive_channels = startup.receive_channels;
        self.send_channels = startup.send_channels;

        self.state = Options.copyOf(default_settings, startup.allocator) catch |err| {
            self.state = null;
            self.deinit();
            return err;
        };
        try self.state.?.reset(startup.allocator, screen_options);
        errdefer self.deinit();
        // The messenger.
        self.messenger = try Messenger.init(startup.allocator, startup.main_view, startup.send_channels, startup.receive_channels, startup.exit, screen_options);
        errdefer {
            self.deinit();
        }

        // All of the panels.
        self.all_panels = try Panels.init(startup.allocator, startup.main_view, self.messenger.?, startup.exit, startup.window, container, screen_options);
        errdefer self.deinit();

        self.messenger.?.all_panels = self.all_panels.?;
        // The HelloWorld panel is the default.
        self.all_panels.?.setCurrentToHelloWorld();

        self.container = container;

        self.count = next_reference_count();

        return self;
    }

    pub fn deinit(self: *Screen) void {
        if (self.state) |state| {
            state.deinit(self.allocator);
        }
        // A screen is deinited by it's container or by a failed init.
        // So don't deinit the container.
        if (self.messenger) |member| {
            member.deinit();
        }
        if (self.all_panels) |member| {
            member.deinit();
        }
        self.allocator.destroy(self);
    }

    /// The caller owns the returned value.
    /// Returns this screen's text label for the main menu.
    pub fn mainMenuLabel(self: *Screen, allocator: std.mem.Allocator) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "{s} {s}", .{ Counts[self.count], self.state.?.screen_name.? });
    }

    pub fn frame(self: *Screen, arena: std.mem.Allocator) !void {
        try self.all_panels.?.frameCurrent(arena);
    }

    fn setContainer(self: *Screen, container: *Container) !void {
        self.container = container;
        return self.all_panels.?.setContainer(container);
    }

    /// KICKZIG TODO: You may find a reason to modify willFrame.
    pub fn willFrame(self: *Screen) bool {
        return self.container != null;
    }

    // Content functions.

    /// Convert this Screen to a Content interface.
    pub fn asContent(self: *Screen) !*Content {
        return Content.init(
            self.allocator,
            self,

            Screen.deinitContentFn,
            Screen.frameContentFn,
            Screen.labelContentFn,
            Screen.willFrameContentFn,
            Screen.setContainerContentFn,
        );
    }

    /// deinitContentFn is an implementation of the Content interface.
    /// The Container calls this when it closes or deinits.
    pub fn deinitContentFn(implementor: *anyopaque) void {
        var self: *Screen = @alignCast(@ptrCast(implementor));
        self.deinit();
    }

    /// willFrameContentFn is an implementation of the Content interface.
    /// The Container calls this when it wants to frame.
    /// Returns if this content will frame under it's current state.
    pub fn willFrameContentFn(implementor: *anyopaque) bool {
        var self: *Screen = @alignCast(@ptrCast(implementor));
        return self.willFrame();
    }

    /// frameContentFn is an implementation of the Content interface.
    /// The Container calls this when it frames.
    pub fn frameContentFn(implementor: *anyopaque, arena: std.mem.Allocator) anyerror!void {
        var self: *Screen = @alignCast(@ptrCast(implementor));
        return self.frame(arena);
    }

    pub fn labelContentFn(implementor: *anyopaque, arena: std.mem.Allocator) anyerror!*ContainerLabel {
        var self: *Screen = @alignCast(@ptrCast(implementor));
        const text: []const u8 = try self.mainMenuLabel(arena);
        defer arena.free(text);
        const view_state = try self.all_panels.?.HelloWorld.?.view.?.getState();
        defer view_state.deinit();
        const opened_ok_modal: bool = view_state.opened_ok_modal orelse false;
        const opened_yesno_modal: bool = view_state.opened_yesno_modal orelse false;
        var all_icons: ?[]*ContainerLabel.Icon = null;
        std.log.info("opened_ok_modal:{0} or opened_yesno_modal:{1}", .{ opened_ok_modal, opened_yesno_modal });
        if (opened_ok_modal or opened_yesno_modal) {
            var icons = std.ArrayList(*ContainerLabel.Icon).init(arena);
            var icon: *ContainerLabel.Icon = undefined;
            icon = try ContainerLabel.Icon.init(
                arena,
                "dvui.entypo.popup",
                dvui.entypo.popup,
                null,
                null,
                null,
            );
            try icons.append(icon);
            all_icons = try icons.toOwnedSlice();
            std.log.info("all_icons.?.len is {d}", .{all_icons.?.len});
            if (all_icons.?.len == 0) {
                all_icons = null;
            }
        }
        return ContainerLabel.init(
            arena,
            text,
            all_icons,
            badges[self.count],
        );
    }

    /// setContainerContentFn is an implementation of the Content interface.
    /// The Container calls this to set itself as this Content's Container.
    pub fn setContainerContentFn(implementor: *anyopaque, container: *Container) !void {
        var self: *Screen = @alignCast(@ptrCast(implementor));
        return self.setContainer(container);
    }

    // KICKZIG EXAMPLE: Close down jobs fn.
    fn exampleCloseDownJob(_: *anyopaque) void {
        std.log.info("This is an example close down job in frontend/screen/panel/HelloWorld/screen.zig", .{});
    }
};
