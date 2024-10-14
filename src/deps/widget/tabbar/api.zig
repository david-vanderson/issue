const std = @import("std");
const dvui = @import("dvui");

const _framers_ = @import("framers");
const _startup_ = @import("startup");
const _tab_bar_widget_ = @import("TabBarWidget.zig");
const _tab_bar_item_widget_ = @import("TabBarItemWidget.zig").TabBarItemWidget;

const Container = @import("various").Container;
const ContainerLabel = @import("various").ContainerLabel;
const Content = @import("various").Content;
const Direction = dvui.enums.Direction;
const MainView = @import("framers").MainView;
const UserAction = _tab_bar_item_widget_.UserAction;

const MaxTabs: usize = 100;
const MaxLabelSize: usize = 255;

const DoContextState = struct {
    arena: std.mem.Allocator,
    tabs: []*Tab,
    tab_settings: Tabs.Options,
    tab_index: usize,
    tab_label: *ContainerLabel,
};

/// Tab is a container and implements Container.
/// Tab has content.
pub const Tab = struct {
    allocator: std.mem.Allocator,
    main_view: *MainView,
    movable: bool,
    closable: bool,
    id: usize,
    tabs: *Tabs,
    content: *Content,
    as_container: ?*Container,
    to_be_closed: bool,
    to_be_refreshed: bool,

    settings: Options,

    const Options = struct {
        movable: ?bool = null,
        closable: ?bool = null,
        show_close_icon: ?bool = null,
        show_move_icons: ?bool = null,
        show_context_menu: ?bool = null,
    };

    pub fn asContainer(self: *Tab) !*Container {
        return self.as_container.?.copy();
    }

    fn _asContainer(self: *Tab) !*Container {
        var close_fn: ?*const fn (implementor: *anyopaque) void = undefined;
        if (self.settings.closable.?) {
            close_fn = Tab.closeContainerFn;
        } else {
            close_fn = null;
        }
        return Container.init(
            self.allocator,
            self,
            close_fn,
            Tab.refreshContainerFn,
        );
    }

    // The returned Tab owns param content.
    // Param content is deinit if there is an error.
    pub fn init(
        tabs: *Tabs,
        main_view: *MainView,
        content: *Content,
        options: Options,
    ) !*Tab {
        var self = try tabs.allocator.create(Tab);
        self.allocator = tabs.allocator;
        self.main_view = main_view;
        self.tabs = tabs;
        self.content = content;
        // Settings.
        self.settings = Options{};
        // The tabs options for each tab can be overridden with the init options.
        if (options.closable) |value| {
            self.settings.closable = value;
        } else {
            self.settings.closable = tabs.settings.tabs_closable;
        }
        if (options.movable) |value| {
            self.settings.movable = value;
        } else {
            self.settings.movable = tabs.settings.tabs_movable;
        }
        if (options.show_close_icon) |value| {
            self.settings.show_close_icon = value;
        } else {
            self.settings.show_close_icon = tabs.settings.show_tab_close_icon;
        }
        if (options.show_move_icons) |value| {
            self.settings.show_move_icons = value;
        } else {
            self.settings.show_move_icons = tabs.settings.show_tab_move_icons;
        }
        if (options.show_context_menu) |value| {
            self.settings.show_context_menu = value;
        } else {
            self.settings.show_context_menu = tabs.settings.show_tab_context_menu;
        }
        self.to_be_closed = false;
        // As container.
        const self_as_container: *Container = try self._asContainer();
        errdefer {
            content.deinit();
            self.allocator.destroy(self);
        }
        try content.setContainer(self_as_container);
        errdefer self_as_container.deinit();
        return self;
    }

    pub fn label(self: *Tab, allocator: std.mem.Allocator) !*ContainerLabel {
        return self.content.label(allocator);
    }

    pub fn frame(self: *Tab, arena: std.mem.Allocator) !void {
        return self.content.frame(arena);
    }

    pub fn refresh(self: *Tab) void {
        // The tab's label may have been changed.
        // Force refresh.
        self.tabs.container.refresh();
    }

    pub fn deinit(self: *Tab) void {
        self.as_container.?.deinit();
        // Deinit the panel or screen.
        self.content.deinit();
        // Destory self.
        self.allocator.destroy(self);
    }

    pub fn close(self: *Tab) void {
        self.to_be_closed = true;
        // self.tabs.removeTab(self);
    }

    // Container functions.

    pub fn refreshContainerFn(implementor: *anyopaque) void {
        var self: *Tab = @alignCast(@ptrCast(implementor));
        self.refresh();
    }

    pub fn closeContainerFn(implementor: *anyopaque) void {
        var self: *Tab = @alignCast(@ptrCast(implementor));
        self.close();
    }
};

/// Tabs is never content.
/// A screen that uses Tabs is the content.
pub const Tabs = struct {
    allocator: std.mem.Allocator,
    lock: std.Thread.Mutex,
    main_view: *MainView,
    tabs: ?std.ArrayList(*Tab),
    selected_tab: ?*Tab,
    vertical_bar_is_visible: bool,
    container: *Container,

    settings: Options,

    const default_settings: Options = Options{
        .direction = .horizontal,
        .toggle_direction = true,
        .tabs_movable = true,
        .tabs_closable = true,
        .toggle_vertical_bar_visibility = true,
        .show_tab_close_icon = true,
        .show_tab_move_icons = true,
        .show_tab_context_menu = true,
    };

    pub const Options = struct {
        direction: ?dvui.enums.Direction = null,
        toggle_direction: ?bool = null,
        tabs_movable: ?bool = null,
        tabs_closable: ?bool = null,
        toggle_vertical_bar_visibility: ?bool = null,
        show_tab_close_icon: ?bool = null,
        show_tab_move_icons: ?bool = null,
        show_tab_context_menu: ?bool = null,

        pub fn reset(
            original: Options,
            settings: Options,
        ) Options {
            var reset_options: Options = original;
            // Tab-bar direction.
            if (settings.direction) |value| {
                reset_options.direction = value;
            }
            // Allow the user to toggle the Tab-bar direction.
            if (settings.toggle_direction) |value| {
                reset_options.toggle_direction = value;
            }
            // Allow the user to move tabs.
            if (settings.tabs_movable) |value| {
                reset_options.tabs_movable = value;
            }
            // Allow the user to close tabs.
            if (settings.tabs_closable) |value| {
                reset_options.tabs_closable = value;
            }
            // Allow the user to toggle the visiblity of the vertical tab-bar.
            if (settings.toggle_vertical_bar_visibility) |value| {
                reset_options.toggle_vertical_bar_visibility = value;
            }
            if (settings.show_tab_close_icon) |value| {
                reset_options.show_tab_close_icon = value;
            }
            if (settings.show_tab_move_icons) |value| {
                reset_options.show_tab_move_icons = value;
            }
            if (settings.show_tab_context_menu) |value| {
                reset_options.show_tab_context_menu = value;
            }
            return reset_options;
        }
    };

    // Used by the screen implementing this Tabs.
    // The main menu will exclude tab screens that will not frame.
    // So that there are no empty tab screens in the main menu.
    // Returns true if at least 1 tab will frame.
    pub fn willFrame(self: *Tabs) bool {
        self.lock.lock();
        defer self.lock.unlock();

        return self._willFrame();
    }

    /// lock must be on.
    pub fn _willFrame(self: *Tabs) bool {
        const tabs: []*Tab = self._slice() catch {
            return false;
        };
        for (tabs) |tab| {
            if (!tab.to_be_closed and tab.content.willFrame()) {
                // At least 1 tab will frame.
                return true;
            }
        }
        // No tabs will frame.
        return false;
    }

    pub fn setSelected(self: *Tabs, selected_tab: *Tab) void {
        self.lock.lock();
        defer self.lock.unlock();

        self.selected_tab = selected_tab;
    }

    // Used in the content panel's fn refresh.
    pub fn isSelected(self: *Tabs, tab: *Tab) bool {
        self.lock.lock();
        defer self.lock.unlock();

        return self.selected_tab == tab;
    }

    pub fn hasTab(self: *Tabs, tab_ptr: *anyopaque) !bool {
        self.lock.lock();
        defer self.lock.unlock();

        const tabs: []*Tab = try self._slice();
        const has_tab: *Tab = @alignCast(@ptrCast(tab_ptr));
        for (tabs) |tab| {
            if (tab == has_tab) {
                return true;
            }
        }
        return false;
    }

    pub fn appendTab(self: *Tabs, tab: *Tab, selected: bool) !void {
        self.lock.lock();
        defer self.lock.unlock();

        try self.tabs.?.append(tab);
        if (selected) {
            self.selected_tab = tab;
        }
    }

    pub fn removeTab(self: *Tabs, tab: *Tab) void {
        self.lock.lock();
        defer self.lock.unlock();

        tab.to_be_closed = true;
    }

    /// lock must be on.
    fn _removeTab(self: *Tabs, tab: *Tab) !void {
        const tabs: []*Tab = try self._slice();
        var previous_tab: ?*Tab = null;
        var following_tab: ?*Tab = null;
        const max_at: usize = tabs.len - 1;
        for (tabs, 0..) |tab_at, at| {
            if (at < max_at) {
                following_tab = tabs[at + 1];
            } else {
                following_tab = null;
            }
            if (tab_at == tab) {
                _ = self.tabs.?.orderedRemove(at);
                if (self.selected_tab) |selected_tab| {
                    if (selected_tab == tab_at) {
                        if (previous_tab != null) {
                            self.selected_tab = previous_tab;
                        } else {
                            self.selected_tab = following_tab;
                        }
                    }
                }
                // tab.deinit();
                return;
            } else {
                previous_tab = tab_at;
            }
        }
        // Not found;
        return error.TabNotFound;
    }

    fn slice(self: *Tabs) ![]*Tab {
        self.lock.lock();
        defer self.lock.unlock();

        return self._slice();
    }

    /// lock must be on.
    fn _slice(self: *Tabs) ![]*Tab {
        var clone = try self.tabs.?.clone();
        return clone.toOwnedSlice();
    }

    // Param container is owned by fn init even if there is an error.
    // Param container will be deleted if error along with it's real self.
    pub fn init(startup: _startup_.Frontend, container: *Container, init_options: Options) !*Tabs {
        var self: *Tabs = try startup.allocator.create(Tabs);
        self.container = container;
        self.selected_tab = null;
        self.tabs = null;
        self.lock = std.Thread.Mutex{};
        errdefer self.deinit();
        self.main_view = startup.main_view;
        self.allocator = startup.allocator;
        self.tabs = std.ArrayList(*Tab).init(startup.allocator);
        self.settings = Options.reset(default_settings, init_options);
        self.vertical_bar_is_visible = true;
        return self;
    }

    pub fn deinit(self: *Tabs) void {
        defer self.allocator.destroy(self);

        self.container.deinit();

        if (self.tabs != null) {
            const tabs = self.tabs.?.toOwnedSlice() catch {
                return;
            };
            for (tabs) |tab| {
                tab.deinit();
            }
            self.allocator.free(tabs);
        }
    }

    fn moveTab(self: *Tabs, to: usize, from: usize) !void {
        const tab: *Tab = self.tabs.?.orderedRemove(from);
        std.log.debug("to is {d}, from is {d}", .{ to, from });
        try self.tabs.?.insert(to, @constCast(tab));
    }

    pub fn frame(self: *Tabs, arena: std.mem.Allocator) !void {
        self.lock.lock();
        defer self.lock.unlock();

        const tabs: []*Tab = try self._slice();
        for (tabs) |tab| {
            if (tab.to_be_closed) {
                try self._removeTab(tab);
            }
        }

        return switch (self.settings.direction.?) {
            .horizontal => self._frameHorizontalTabBar(arena),
            .vertical => self._frameVerticalTabBar(arena),
        };
    }

    /// lock must be on.
    fn _frameVerticalTabBar(self: *Tabs, arena: std.mem.Allocator) !void {
        var layout = try dvui.box(@src(), .horizontal, .{ .expand = .both });
        defer layout.deinit();

        {
            // The vertical column.
            var column = try _tab_bar_widget_.verticalTabBarColumn(@src());
            defer column.deinit();

            if (self.settings.toggle_vertical_bar_visibility.? or self.vertical_bar_is_visible) {
                // User can hide/show the tab-bar.
                // User can toggle the direction.

                if (self.settings.toggle_direction.?) {
                    // horizontal row of 2 icons above the tab-bar.
                    var direction: dvui.enums.Direction = undefined;
                    if (self.vertical_bar_is_visible) {
                        direction = .horizontal;
                    } else {
                        direction = .vertical;
                    }
                    const icons = try dvui.box(@src(), direction, .{ .gravity_x = 0.5, .gravity_y = 0.0 });
                    defer icons.deinit();

                    if (self.settings.toggle_vertical_bar_visibility.?) {
                        // Hide show tab-bar button.
                        if (self.vertical_bar_is_visible) {
                            // Icon to hide the tab-bar.
                            if (try dvui.buttonIcon(@src(), "hide_horizontal", dvui.entypo.eye_with_line, .{}, .{})) {
                                self.vertical_bar_is_visible = false;
                            }
                        } else {
                            // Icon to show the tab-bar.
                            if (try dvui.buttonIcon(@src(), "show_horizontal", dvui.entypo.eye, .{}, .{})) {
                                self.vertical_bar_is_visible = true;
                            }
                        }
                    }

                    // Switch to horizontal tab-bar button.
                    if (try dvui.buttonIcon(@src(), "horizontal_switch", dvui.entypo.align_top, .{}, .{ .gravity_x = 0.5, .gravity_y = 0.0 })) {
                        self.settings.direction.? = .horizontal;
                    }
                } else {
                    // User can't toggle direction.
                    // Icon to show the tab-bar.
                    if (self.settings.toggle_vertical_bar_visibility.?) {
                        // Hide show tab-bar button.
                        if (self.vertical_bar_is_visible) {
                            // Icon to hide the tab-bar.
                            if (try dvui.buttonIcon(@src(), "hide_horizontal", dvui.entypo.eye_with_line, .{}, .{})) {
                                self.vertical_bar_is_visible = false;
                            }
                        } else {
                            // Icon to show the tab-bar.
                            if (try dvui.buttonIcon(@src(), "show_horizontal", dvui.entypo.eye, .{}, .{})) {
                                self.vertical_bar_is_visible = true;
                            }
                        }
                    }
                }

                if (self.vertical_bar_is_visible) {
                    // Show the vertical tab-bar.
                    // // The vertical scroller.
                    var scroller = try _tab_bar_widget_.verticalTabScroller(@src());
                    defer scroller.deinit();

                    // // The tab bar.
                    var tabbar = try _tab_bar_widget_.verticalTabBar(@src());
                    defer tabbar.deinit();

                    const tabs: []*Tab = try self._slice();
                    var previous_tab: ?*Tab = null;
                    for (tabs, 0..) |tab, i| {
                        if (!tab.content.willFrame()) {
                            // This tab will not frame.
                            if (self.selected_tab == tab) {
                                self.selected_tab = previous_tab;
                            }
                            continue;
                        }

                        defer previous_tab = tab;
                        if (self.selected_tab == null) {
                            self.selected_tab = tab;
                        }
                        // Is this tab the currently selected tab?
                        const selected: bool = self.selected_tab == tab;

                        // Get the label information for this tab.
                        const tab_label: *ContainerLabel = try tab.label(arena);
                        defer tab_label.deinit();
                        // Allow the Tab.setting to override the Tabs.settings.
                        const tab_settings: Options = Options.reset(
                            self.settings,
                            Options{
                                .tabs_movable = tab.settings.movable,
                                .tabs_closable = tab.settings.closable,
                                .show_tab_close_icon = tab.settings.show_close_icon,
                                .show_tab_move_icons = tab.settings.show_move_icons,
                                .show_tab_context_menu = tab.settings.show_context_menu,
                            },
                        );
                        // State for the do context menu call-back function.
                        const do_context_state: *DoContextState = try arena.create(DoContextState);
                        do_context_state.arena = arena;
                        do_context_state.tabs = tabs;
                        do_context_state.tab_settings = tab_settings;
                        do_context_state.tab_index = i;
                        do_context_state.tab_label = tab_label;
                        const user_action: UserAction = try _tab_bar_item_widget_.verticalTabBarItemLabel(
                            tab_label,
                            .{
                                .selected = selected,
                                .id_extra = i,
                                .count_tabs = tabs.len,
                                .index = i,
                                .show_close_icon = tab_settings.show_tab_close_icon,
                                .show_move_icons = tab_settings.show_tab_move_icons,
                                .show_context_menu = tab_settings.show_tab_context_menu,
                            },
                            Tabs.doContextFn,
                            self,
                            do_context_state,
                        );
                        switch (user_action.user_selection) {
                            .close_tab => {
                                tab.close();
                            },
                            .select_tab => {
                                self.selected_tab = tab;
                            },
                            .move_tab_right_down => {
                                try self.moveTab(i + 1, i);
                            },
                            .move_tab_left_up => {
                                try self.moveTab(i - 1, i);
                            },
                            else => {},
                        }
                    }
                }
            } else {
                // User can hide/show the tab-bar.
                // User can toggle the direction.
                // Vertical tab-bar is hidden.

                // // vertical column of 2 icons above empty space.
                // const icon_column = try dvui.box(@src(), .vertical, .{ .gravity_x = 0.5, .gravity_y = 0.0 });
                // defer icon_column.deinit();

                // // Hide show tab-bar button.
                // // Icon to show the tab-bar.
                // if (try dvui.buttonIcon(@src(), "show_horizontal", dvui.entypo.eye, .{}, .{})) {
                //     self.vertical_bar_is_visible = true;
                // }

                // Switch to horizontal tab-bar button.
                if (try dvui.buttonIcon(@src(), "horizontal_switch", dvui.entypo.align_top, .{}, .{ .gravity_x = 0.5, .gravity_y = 0.0 })) {
                    self.settings.direction.? = .horizontal;
                }
            }
        }

        // The content area for a tab's content.
        // Display the selected tab's content.

        // KICKZIG TODO:
        // Display your selected tab's content if there is a selected tab.
        try self._frameSelectedTab(arena);
    }

    /// lock must be on.
    fn _frameHorizontalTabBar(self: *Tabs, arena: std.mem.Allocator) !void {
        var layout = try dvui.box(@src(), .vertical, .{ .expand = .both });
        defer layout.deinit();

        const tabs: []*Tab = try self._slice();
        {
            // The horizontal row.
            var row = try _tab_bar_widget_.horizontalTabBarRow(@src());
            defer row.deinit();

            if (self.settings.toggle_direction.?) {
                if (try dvui.buttonIcon(@src(), "vertical_switch", dvui.entypo.align_left, .{}, .{ .gravity_x = 0.0, .gravity_y = 0.5 })) {
                    self.settings.direction.? = .vertical;
                }
            }

            // // The horizontal scroller.
            var scroller = try _tab_bar_widget_.horizontalTabScroller(@src());
            defer scroller.deinit();

            // // The tab bar.
            var tabbar = try _tab_bar_widget_.horizontalTabBar(@src());
            defer tabbar.deinit();

            var previous_tab: ?*Tab = null;
            for (tabs, 0..) |tab, i| {
                if (!tab.content.willFrame()) {
                    // This tab will not frame.
                    if (self.selected_tab == tab) {
                        self.selected_tab = previous_tab;
                    }
                    continue;
                }
                defer previous_tab = tab;
                if (self.selected_tab == null) {
                    self.selected_tab = tab;
                }
                // Is this tab the curretnly selected tab?
                const selected: bool = self.selected_tab == tab;

                // Get the label information for this tab.
                const tab_label: *ContainerLabel = try tab.label(arena);
                defer tab_label.deinit();
                // State for the do context menu call-back function.
                const do_context_state: *DoContextState = try arena.create(DoContextState);
                defer arena.destroy(do_context_state);
                do_context_state.arena = arena;
                do_context_state.tabs = tabs;
                do_context_state.tab_settings = self.settings;
                do_context_state.tab_index = i;
                do_context_state.tab_label = tab_label;
                const user_action: UserAction = try _tab_bar_item_widget_.horizontalTabBarItemLabel(
                    tab_label,
                    .{
                        .selected = selected,
                        .id_extra = i,
                        .count_tabs = tabs.len,
                        .index = i,
                        .show_close_icon = tab.settings.show_close_icon,
                        .show_move_icons = tab.settings.show_move_icons,
                        .show_context_menu = tab.settings.show_context_menu,
                    },
                    Tabs.doContextFn,
                    self,
                    do_context_state,
                );

                switch (user_action.user_selection) {
                    .close_tab => {
                        tab.close();
                    },
                    .select_tab => {
                        self.selected_tab = tab;
                    },
                    .move_tab_right_down => {
                        try self.moveTab(i + 1, i);
                    },
                    .move_tab_left_up => {
                        try self.moveTab(i - 1, i);
                    },
                    else => {},
                }
            }
        }

        // KICKZIG TODO:
        // Display your selected tab's content if there is a selected tab.
        try self._frameSelectedTab(arena);
    }

    /// lock must be on.
    fn _frameSelectedTab(self: *Tabs, arena: std.mem.Allocator) !void {
        if (self.selected_tab) |selected_tab| {
            try selected_tab.frame(arena);
        }
    }

    fn doContextFn(implementor: *anyopaque, state: *anyopaque, point_of_context: dvui.Point) !void {
        var self: *Tabs = @alignCast(@ptrCast(implementor));
        const do_state: *DoContextState = @alignCast(@ptrCast(state));
        const tab: *Tab = do_state.tabs[do_state.tab_index];
        const tab_state: Tab.Options = tab.settings;

        var context_menu = try dvui.floatingMenu(@src(), dvui.Rect.fromPoint(point_of_context), .{ .tab_index = @as(u16, @truncate(do_state.tab_index)), .id_extra = @as(u16, @truncate(do_state.tab_index)) });
        defer self.refresh();
        defer {
            context_menu.deinit();
        }

        if (do_state.tab_label.icons) |icons| {
            for (icons, 0..) |icon, i| {
                if (icon.call_back) |call_back| {
                    if (try dvui.menuItemLabel(@src(), icon.label.?, .{ .submenu = true }, .{ .expand = .horizontal, .id_extra = @as(u16, @truncate(i)) })) |_| {
                        // user clicked.
                        try call_back(icon.implementor.?, icon.state.?);
                        // Close the context menu.
                        var closeE = dvui.Event{ .evt = .{ .close_popup = .{ .intentional = false } } };
                        context_menu.processEvent(&closeE, true);
                        return;
                    }
                }
            }
        }

        if (tab_state.movable.?) {
            if (do_state.tab_index > 0) {
                // Go left/up label.
                const move_label: []const u8 = switch (self.settings.direction.?) {
                    .horizontal => "Move Left Of",
                    .vertical => "Move Above",
                };
                if (try dvui.menuItemLabel(@src(), move_label, .{ .submenu = true }, .{ .expand = .horizontal, .id_extra = @as(u16, @truncate(do_state.tab_index)) })) |r| {
                    var move_left = try dvui.floatingMenu(@src(), dvui.Rect.fromPoint(dvui.Point{ .x = r.x, .y = r.y + r.h }), .{});
                    defer move_left.deinit();
                    var j: usize = do_state.tab_index - 1;
                    while (j >= 0) : (j -= 1) {
                        const left_tab: *Tab = do_state.tabs[j];
                        const left_tab_label: *ContainerLabel = try left_tab.label(do_state.arena);
                        defer left_tab_label.deinit();
                        if ((try dvui.menuItemLabel(@src(), left_tab_label.text.?, .{ .submenu = false }, .{ .expand = .vertical, .tab_index = @as(u16, @truncate(j)) })) != null) {
                            try self.moveTab(j, do_state.tab_index);
                            // Close the context menu.
                            var closeE = dvui.Event{ .evt = .{ .close_popup = .{ .intentional = false } } };
                            context_menu.processEvent(&closeE, true);
                            return;
                        }

                        if (j == 0) {
                            break;
                        }
                    }
                }
            }

            const last: usize = do_state.tabs.len - 1;
            if (do_state.tab_index < last) {
                // Go right label.
                // Go left/up label.
                const move_label: []const u8 = switch (self.settings.direction.?) {
                    .horizontal => "Move Right Of",
                    .vertical => "Move Below",
                };
                if (try dvui.menuItemLabel(@src(), move_label, .{ .submenu = true }, .{ .expand = .horizontal, .id_extra = @as(u16, @truncate(do_state.tab_index)) })) |r| {
                    var move_right = try dvui.floatingMenu(@src(), dvui.Rect.fromPoint(dvui.Point{ .x = r.x, .y = r.y + r.h }), .{});
                    defer move_right.deinit();
                    var j: usize = do_state.tab_index + 1;
                    while (j <= last) : (j += 1) {
                        const right_tab: *Tab = do_state.tabs[j];
                        const right_tab_label: *ContainerLabel = try right_tab.label(do_state.arena);
                        defer right_tab_label.deinit();
                        if ((try dvui.menuItemLabel(@src(), right_tab_label.text.?, .{ .submenu = false }, .{ .expand = .vertical, .tab_index = @as(u16, @truncate(j)) })) != null) {
                            try self.moveTab(j, do_state.tab_index);
                            // Close the context menu.
                            var closeE = dvui.Event{ .evt = .{ .close_popup = .{ .intentional = false } } };
                            context_menu.processEvent(&closeE, true);
                            return;
                        }
                    }
                }
            }

            if (tab_state.closable.?) {
                if (try dvui.menuItemIcon(@src(), "close", dvui.entypo.align_top, .{ .submenu = false }, .{ .expand = .horizontal, .id_extra = @as(u16, @truncate(do_state.tab_index)) }) != null) {
                    // Close the context menu.
                    var closeE = dvui.Event{ .evt = .{ .close_popup = .{ .intentional = false } } };
                    context_menu.processEvent(&closeE, true);
                    return;
                }
            }
        }
    }

    pub fn refresh(self: *Tabs) void {
        // The tab's label may have been changed.
        // Force refresh.
        self.container.refresh();
    }
};

fn setFocus(widget_id: u32) !void {
    var window: dvui.Window = dvui.currentWindow();
    var sub_window: dvui.Window.Subwindow = undefined;
    // focused_subwindowId
    // subwindows

    var i: usize = 0;
    while (i < window.subwindows.items.len) : (i += 1) {
        sub_window = &window.subwindows.items[i];
        if (sub_window.id == window.focused_subwindowId) {
            sub_window.focused_widgetId = widget_id;
        }
    }
}
