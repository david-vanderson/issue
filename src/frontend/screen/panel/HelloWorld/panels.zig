const std = @import("std");
const dvui = @import("dvui");

const Container = @import("various").Container;
const ExitFn = @import("various").ExitFn;
const Messenger = @import("view/messenger.zig").Messenger;
const MainView = @import("framers").MainView;
const ScreenOptions = @import("screen.zig").Options;

const HelloWorldPanel = @import("HelloWorld.zig").Panel;

const PanelTags = enum {
    HelloWorld,
    none,
};

pub const Panels = struct {
    allocator: std.mem.Allocator,
    HelloWorld: ?*HelloWorldPanel,
    current_panel_tag: PanelTags,

    pub fn deinit(self: *Panels) void {
        if (self.HelloWorld) |member| {
            member.deinit();
        }
        self.allocator.destroy(self);
    }

    pub fn frameCurrent(self: *Panels, allocator: std.mem.Allocator) !void {
        return switch (self.current_panel_tag) {
            .HelloWorld => self.HelloWorld.?.view.?.frame(allocator),
            .none => self.HelloWorld.?.view.?.frame(allocator),
        };
    }

    pub fn refresh(self: *Panels) void {
        switch (self.current_panel_tag) {
            .HelloWorld => self.HelloWorld.?.view.?.refresh(),
            .none => self.HelloWorld.?.view.?.refresh(),
        }
    }

    pub fn setCurrentToHelloWorld(self: *Panels) void {
        self.current_panel_tag = PanelTags.HelloWorld;
    }

    pub fn setContainer(self: *Panels, container: *Container) !void {
        try self.HelloWorld.?.view.?.setContainer(container);
    }

    pub fn init(
        allocator: std.mem.Allocator,
        main_view: *MainView,
        messenger: *Messenger,
        exit: ExitFn,
        window: *dvui.Window,
        container: ?*Container,
        screen_options: ScreenOptions,
    ) !*Panels {
        var panels: *Panels = try allocator.create(Panels);
        panels.allocator = allocator;

        panels.HelloWorld = try HelloWorldPanel.init(
            allocator,
            window,
            main_view,
            panels,
            messenger,
            exit,
            container,
            screen_options,
        );
        errdefer panels.deinit();

        return panels;
    }
};
