const std = @import("std");
const dvui = @import("dvui");

const _channel_ = @import("channel");
const _screen_pointers_ = @import("../../../screen_pointers.zig");
const _startup_ = @import("startup");

const Messenger = @import("view/messenger.zig").Messenger;
const PanelTags = @import("panels.zig").PanelTags;
const Container = @import("various").Container;
const ContainerLabel = @import("various").ContainerLabel;
const Content = @import("various").Content;
const ExitFn = @import("various").ExitFn;
const MainView = @import("framers").MainView;
const ScreenPointers = _screen_pointers_.ScreenPointers;
const Tab = @import("widget").Tab;
const Tabs = @import("widget").Tabs;

const HelloWorldScreen = _screen_pointers_.HelloWorld;

/// KICKZIG TODO:
/// Options will need to be customized.
/// Keep each value optional and set to null by default.
//KICKZIG TODO: Customize Options to your requirements.
pub const Options = struct {
    screen_name: ?[]const u8 = null, // Example field.

    fn label(self: *Options, allocator: std.mem.Allocator) ![]const u8 {
        _ = self;
        return try std.fmt.allocPrint(allocator, "{s}", .{"Icons"});
    }

    fn copyOf(values: Options, allocator: std.mem.Allocator) !*Options {
        var copy_of: *Options = try allocator.create(Options);
        // Null optional members for fn reset.
        copy_of.screen_name = null;
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
        );
    }

    fn _reset(
        self: *Options,
        allocator: std.mem.Allocator,
        screen_name: ?[]const u8,
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
    }
};

/// Screen is content for the main view or a container.
/// Screen is the container for Tabs.
pub const Screen = struct {
    allocator: std.mem.Allocator,
    window: *dvui.Window,
    main_view: *MainView,
    container: ?*Container,
    tabs: ?*Tabs,
    messenger: ?*Messenger,
    send_channels: *_channel_.FrontendToBackend,
    receive_channels: *_channel_.BackendToFrontend,
    exit: ExitFn,
    screen_pointers: *ScreenPointers,
    startup: _startup_.Frontend,
    state: ?*Options,

    const default_settings = Options{
        .screen_name = "Icons",
    };
    pub fn AddNewHelloWorldTab(
        self: *Screen,
        selected: bool,
    ) !void {
        // The HelloWorld tab uses the HelloWorld screen for content.
        // The HelloWorldScreen.init second param container, is null because Tab will set it.
        // The HelloWorldScreen.init third param screen_options, is a the options for the HelloWorldScreen.
        // * KICKZIG TODO: You may find setting some screen_options to be usesful.
        // * Param screen_options has no members defined so the HelloWorldScreen will use it default settings.
        // * See screen/panel/HelloWorld/screen.Options.
        const screen: *HelloWorldScreen = try HelloWorldScreen.init(
            self.startup,
            null,
            .{},
        );
        const screen_as_content: *Content = try screen.asContent();
        errdefer screen.deinit();
        // screen_as_content now owns screen.

        const tab: *Tab = try Tab.init(
            self.tabs.?,
            self.main_view,
            screen_as_content,
            .{
                // KICKZIG TODO:
                // You can override the options for the HelloWorld tab.
                // .closable = true,
                // .movable = true,
                // .show_close_icon = true,
                // .show_move_icons = true,
                // .show_context_menu = true,
            },
        );
        errdefer {
            screen_as_content.deinit();
        }
        try self.tabs.?.appendTab(tab, selected);
        errdefer {
            tab.deinit(); // will deinit screen_as_content.
        }
    }

    /// init constructs this screen, subscribes it to all_screens and returns the error.
    /// Param tabs_options is a Tabs.Options.
    pub fn init(
        startup: _startup_.Frontend,
        container: ?*Container,
        tabs_options: Tabs.Options,
        screen_options: Options,
    ) !*Screen {
        var self: *Screen = try startup.allocator.create(Screen);
        self.allocator = startup.allocator;
        self.main_view = startup.main_view;
        self.receive_channels = startup.receive_channels;
        self.send_channels = startup.send_channels;
        self.screen_pointers = startup.screen_pointers;
        self.window = startup.window;
        self.startup = startup;

        self.state = Options.copyOf(default_settings, startup.allocator) catch |err| {
            self.state = null;
            self.deinit();
            return err;
        };
        try self.state.?.reset(startup.allocator, screen_options);
        errdefer self.deinit();

        const self_as_container: *Container = try self.asContainer();
        errdefer startup.allocator.destroy(self);

        self.tabs = try Tabs.init(
            startup,
            self_as_container,
            tabs_options,
        );
        errdefer self.deinit();

        // Create the messenger.
        self.messenger = try Messenger.init(
            startup.allocator,
            self.tabs.?,
            startup.main_view,
            startup.send_channels,
            startup.receive_channels,
            startup.exit,
            self.state.?.*,
        );
        errdefer self.deinit();

        // Create 3 of each type of tab.

        try self.AddNewHelloWorldTab(false);
        errdefer self.deinit();

        try self.AddNewHelloWorldTab(false);
        errdefer self.deinit();

        try self.AddNewHelloWorldTab(true);
        errdefer self.deinit();

        self.container = container;
        return self;
    }

    pub fn willFrame(self: *Screen) bool {
        return self.tabs.?.willFrame();
    }

    pub fn close(self: *Screen) bool {
        _ = self;
    }

    pub fn deinit(self: *Screen) void {
        // A screen is deinited by it's container or by a failed init.
        // So don't deinit the container.
        if (self.messenger) |member| {
            member.deinit();
        }
        self.allocator.destroy(self);
    }

    /// The caller owns the returned value.
    pub fn mainMenuLabel(self: *Screen, arena: std.mem.Allocator) ![]const u8 {
        return self.state.?.label(arena);
    }

    pub fn frame(self: *Screen, arena: std.mem.Allocator) !void {
        try self.tabs.?.frame(arena);
    }

    pub fn setContainer(self: *Screen, container: *Container) void {
        self.container = container;
    }

    // Content interface functions.

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

    /// setContainerContentFn is an implementation of the Content interface.
    /// The Container calls this to set itself as this Content's Container.
    pub fn setContainerContentFn(implementor: *anyopaque, container: *Container) !void {
        var self: *Screen = @alignCast(@ptrCast(implementor));
        return self.setContainer(container);
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

    /// labelContentFn is an implementation of the Content interface.
    /// The Container may call this when it refreshes.
    pub fn labelContentFn(implementor: *anyopaque, arena: std.mem.Allocator) anyerror!*ContainerLabel {
        var self: *Screen = @alignCast(@ptrCast(implementor));
        const text: []const u8 = try self.mainMenuLabel(arena);
        defer arena.free(text);
        return ContainerLabel.init(
            arena,
            text,
            null, // icons
            null, // badge
        );
    }

    // Container interface functions.

    /// Convert this Screen to a Container interface.
    pub fn asContainer(self: *Screen) anyerror!*Container {
        return Container.init(
            self.allocator,
            self,
            Screen.closeContainerFn,
            Screen.refreshContainerFn,
        );
    }

    /// Close the top container.
    pub fn closeContainerFn(implementor: *anyopaque) void {
        const self: *Screen = @alignCast(@ptrCast(implementor));
        self.container.?.close();
    }

    /// Refresh a container up to dvui.window if visible.
    pub fn refreshContainerFn(implementor: *anyopaque) void {
        const self: *Screen = @alignCast(@ptrCast(implementor));
        self.container.?.refresh();
    }
};
