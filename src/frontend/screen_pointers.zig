const std = @import("std");

const _main_menu_ = @import("main_menu");
const _startup_ = @import("startup");

const Container = @import("various").Container;
const Content = @import("various").Content;
const ScreenTags = @import("framers").ScreenTags;

pub const Icons = @import("screen/tab/Icons/screen.zig").Screen;
pub const HelloWorld = @import("screen/panel/HelloWorld/screen.zig").Screen;
pub const YesNo = @import("screen/modal/YesNo/screen.zig").Screen;
pub const EOJ = @import("screen/modal/EOJ/screen.zig").Screen;
pub const OK = @import("screen/modal/OK/screen.zig").Screen;

pub const ScreenPointers = struct {
    allocator: std.mem.Allocator,
    Icons: ?*Icons,
    HelloWorld: ?*HelloWorld,
    YesNo: ?*YesNo,
    EOJ: ?*EOJ,
    OK: ?*OK,

    pub fn deinit(self: *ScreenPointers) void {
        if (self.Icons) |screen| {
            screen.deinit();
        }
        if (self.HelloWorld) |screen| {
            screen.deinit();
        }
        if (self.YesNo) |screen| {
            screen.deinit();
        }
        if (self.EOJ) |screen| {
            screen.deinit();
        }
        if (self.OK) |screen| {
            screen.deinit();
        }
        self.allocator.destroy(self);
    }

    pub fn init(startup: _startup_.Frontend) !*ScreenPointers {
        const self: *ScreenPointers = try startup.allocator.create(ScreenPointers);
        self.allocator = startup.allocator;
        self.Icons = null;
        self.HelloWorld = null;
        self.YesNo = null;
        self.EOJ = null;
        self.OK = null;
        return self;
    }

    pub fn init_screens(self: *ScreenPointers, startup: _startup_.Frontend) !void {
        const screen_tags: []ScreenTags = try _main_menu_.screenTagsForInitialization(self.allocator);
        defer self.allocator.free(screen_tags);
        for (screen_tags) |tag| {
            switch (tag) {
                .Icons => {
                    // KICKZIG TODO: You can customize the init_options. See deps/widgets/tabbar/api.zig.
                    const main_view_as_container: *Container = try startup.main_view.asIconsContainer();
                    self.Icons = try Icons.init(
                        startup,
                        main_view_as_container,
                        .{
                            // Tabs.Options.
                            // KICKZIG TODO:
                            // You can override the Tabs options for the Icons tab.

                            //.direction = .horizontal,
                            //.toggle_direction = true,
                            //.tabs_movable = true,
                            //.tabs_closable = true,
                            //.toggle_vertical_bar_visibility = true,
                            .show_tab_close_icon = false,
                            .show_tab_move_icons = false,
                            // .show_tab_context_menu = false,
                        },
                        .{
                            // Icons screen Options.
                            // KICKZIG TODO:
                            // You can override the Icons screen Options.
                            // See screen/tab/Icons.zig Options.
                        },
                    );
                    errdefer main_view_as_container.deinit();
                },

                .HelloWorld => {
                    const main_view_as_container: *Container = try startup.main_view.asHelloWorldContainer();
                    self.HelloWorld = try HelloWorld.init(
                        startup,
                        main_view_as_container,
                        .{
                            // HelloWorld screen Options.
                            // KICKZIG TODO:
                            // You can override the HelloWorld screen Options.
                            // See screen/tab/HelloWorld.zig Options.
                        },
                    );
                    errdefer main_view_as_container.deinit();
                },
                else => {
                    // No modals here. They are below.
                },
            }
        }

        // Set up each modal screen.

        // The YesNo screen is a modal screen.
        // Modal screens frame inside the main view.
        // The YesNo modal screen can not be used in the main menu.
        self.YesNo = try YesNo.init(startup);
        errdefer self.deinit();
        // The EOJ screen is a modal screen.
        // Modal screens frame inside the main view.
        // The EOJ modal screen can not be used in the main menu.
        self.EOJ = try EOJ.init(startup);
        errdefer self.deinit();
        // The OK screen is a modal screen.
        // Modal screens frame inside the main view.
        // It is the only modal screen that can be used in the main menu.
        self.OK = try OK.init(startup);
        errdefer self.deinit();
    }
};
