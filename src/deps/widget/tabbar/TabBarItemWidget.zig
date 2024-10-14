const std = @import("std");
const dvui = @import("dvui");

const ContainerLabel = @import("various").ContainerLabel;

const Direction = dvui.enums.Direction;
const Event = dvui.Event;
const Options = dvui.Options;
const Rect = dvui.Rect;
const RectScale = dvui.RectScale;
const Size = dvui.Size;
const Widget = dvui.Widget;
const WidgetData = dvui.WidgetData;

pub const UserSelection = enum {
    none,
    close_tab,
    move_tab_right_down,
    move_tab_left_up,
    select_tab,
    context,
};

pub const UserAction = struct {
    user_selection: UserSelection = .none,
    point_of_context: dvui.Point = undefined,
    context_widget: *dvui.ContextWidget = undefined,
    move_from_index: usize = 0,
    move_to_index: usize = 0,
};

pub const TabBarItemWidget = @This();

pub const Flow = enum {
    horizontal,
    vertical,
};

pub const InitOptions = struct {
    selected: ?bool = null,
    flow: ?Flow = null,
    id_extra: ?usize = null,
    show_close_icon: ?bool = null,
    show_move_icons: ?bool = null,
    show_context_menu: ?bool = null,
    index: ?usize = null,
    count_tabs: ?usize = null,
};

const horizontal_init_options: InitOptions = .{
    .id_extra = 0,
    .selected = false,
    .flow = .horizontal,
};

const vertical_init_options: InitOptions = .{
    .id_extra = 0,
    .selected = false,
    .flow = .vertical,
};

wd: WidgetData = undefined,
focused_last_frame: bool = undefined,
highlight: bool = false,
defaults: dvui.Options = undefined,
init_options: InitOptions = undefined,
activated: bool = false,
show_active: bool = false,
mouse_over: bool = false,

// Defaults.
// Defaults for tabs in a horizontal tabbar.
fn horizontalDefaultOptions() dvui.Options {
    var defaults: dvui.Options = .{
        .name = "HorizontalTabBarItem",
        .color_fill = .{ .name = .fill_hover },
        .corner_radius = .{ .x = 2, .y = 2, .w = 0, .h = 0 },
        .padding = .{ .x = 0, .y = 0, .w = 0, .h = 0 },
        .border = .{ .x = 1, .y = 1, .w = 1, .h = 0 },
        .margin = .{ .x = 4, .y = 0, .w = 0, .h = 8 },
        .expand = .none,
        .font_style = .body,
        // .debug = false,
    };
    const hover: dvui.Color = dvui.themeGet().color_fill_hover;
    const hover_hsl: dvui.Color.HSLuv = dvui.Color.HSLuv.fromColor(hover);
    const darken: dvui.Color = hover_hsl.lighten(-16).color();
    // const darken: dvui.Color = dvui.Color.darken(hover, 0.5);
    defaults.color_border = .{ .color = darken };
    return defaults;
}

fn horizontalDefaultSelectedOptions() dvui.Options {
    const bg: dvui.Color = dvui.themeGet().color_fill_window;
    var defaults = horizontalDefaultOptions();
    defaults.color_fill = .{ .color = bg };
    defaults.color_border = .{ .name = .accent };
    defaults.margin = .{ .x = 4, .y = 7, .w = 0, .h = 0 };

    return defaults;
}

fn verticalDefaultOptions() dvui.Options {
    var defaults: dvui.Options = .{
        .name = "VerticalTabBarItem",
        .color_fill = .{ .name = .fill_hover },
        .color_border = .{ .name = .fill_hover },
        .corner_radius = .{ .x = 2, .y = 0, .w = 0, .h = 2 },
        .padding = .{ .x = 0, .y = 0, .w = 1, .h = 0 },
        .border = .{ .x = 1, .y = 1, .w = 0, .h = 1 },
        .margin = .{ .x = 1, .y = 4, .w = 6, .h = 0 },
        .expand = .horizontal,
        .font_style = .body,
        .gravity_x = 1.0,
    };
    const hover: dvui.Color = dvui.themeGet().color_fill_hover;
    const hover_hsl: dvui.Color.HSLuv = dvui.Color.HSLuv.fromColor(hover);
    const darken: dvui.Color = hover_hsl.lighten(-16).color();
    // const darken: dvui.Color = dvui.Color.darken(hover, 0.5);
    defaults.color_border = .{ .color = darken };
    return defaults;
}

pub fn verticalContextOptions() dvui.Options {
    return .{
        .name = "VerticalContext",
        .corner_radius = .{ .x = 2, .y = 0, .w = 0, .h = 2 },
        .padding = .{ .x = 0, .y = 0, .w = 0, .h = 0 },
        .border = .{ .x = 0, .y = 0, .w = 0, .h = 0 },
        .margin = .{ .x = 0, .y = 0, .w = 0, .h = 0 },
        .expand = .horizontal,
        .gravity_x = 1.0,
        .background = false,
    };
}

fn verticalDefaultSelectedOptions() dvui.Options {
    const bg: dvui.Color = dvui.themeGet().color_fill_window;
    var defaults = verticalDefaultOptions();
    defaults.color_fill = .{ .color = bg };
    defaults.color_border = .{ .name = .accent };
    defaults.margin = .{ .x = 7, .y = 4, .w = 0, .h = 0 };
    return defaults;
}

pub fn verticalSelectedContextOptions() dvui.Options {
    return verticalContextOptions();
}

/// Param label is not owned by this fn.
pub fn verticalTabBarItemLabel(
    label: *ContainerLabel,
    init_opts: InitOptions,
    call_back: *const fn (implementor: *anyopaque, state: *anyopaque, point_of_context: dvui.Point) anyerror!void,
    call_back_implementor: *anyopaque,
    call_back_state: *anyopaque,
) !UserAction {
    var tab_init_opts: TabBarItemWidget.InitOptions = TabBarItemWidget.vertical_init_options;
    if (init_opts.id_extra) |id_extra| {
        tab_init_opts.id_extra = id_extra;
    }
    if (init_opts.selected) |value| {
        tab_init_opts.selected = value;
    }
    tab_init_opts.index = init_opts.index;
    tab_init_opts.id_extra = init_opts.index;
    tab_init_opts.count_tabs = init_opts.count_tabs;
    tab_init_opts.show_close_icon = init_opts.show_close_icon orelse true;
    tab_init_opts.show_move_icons = init_opts.show_move_icons orelse true;
    tab_init_opts.show_context_menu = init_opts.show_context_menu orelse true;

    return tabBarItemLabel(label, tab_init_opts, .vertical, call_back, call_back_implementor, call_back_state);
}

/// Param label is not owned by this fn.
pub fn horizontalTabBarItemLabel(
    label: *ContainerLabel,
    init_opts: InitOptions,
    call_back: *const fn (implementor: *anyopaque, state: *anyopaque, point_of_context: dvui.Point) anyerror!void,
    call_back_implementor: *anyopaque,
    call_back_state: *anyopaque,
) !UserAction {
    var tab_init_opts: TabBarItemWidget.InitOptions = TabBarItemWidget.horizontal_init_options;
    if (init_opts.id_extra) |id_extra| {
        tab_init_opts.id_extra = id_extra;
    }
    if (init_opts.selected) |value| {
        tab_init_opts.selected = value;
    }
    tab_init_opts.index = init_opts.index;
    tab_init_opts.id_extra = init_opts.index;
    tab_init_opts.count_tabs = init_opts.count_tabs;
    tab_init_opts.show_close_icon = init_opts.show_close_icon orelse true;
    tab_init_opts.show_move_icons = init_opts.show_move_icons orelse true;
    tab_init_opts.show_context_menu = init_opts.show_context_menu orelse true;

    return tabBarItemLabel(label, tab_init_opts, .horizontal, call_back, call_back_implementor, call_back_state);
}

// Param label is not owned by tabBarItemLabel.
// Display the button-label and return it's rect if clicked else null.
// Display each icon:
// * If icon is clicked and no cb then return button-label rect.
// * If icon is clicked and cp then run callback and return null.
// * CB icons only is init_opts.selected == true.
fn tabBarItemLabel(label: *ContainerLabel, init_opts: TabBarItemWidget.InitOptions, direction: Direction, call_back: *const fn (implementor: *anyopaque, state: *anyopaque, point_of_context: dvui.Point) anyerror!void, call_back_implementor: *anyopaque, call_back_state: *anyopaque) !UserAction {
    var user_action: UserAction = UserAction{};
    const tbi = try tabBarItem(init_opts);

    std.log.info("init_opts.show_context_menu:{}", .{init_opts.show_context_menu.?});
    const tab: *dvui.BoxWidget = try dvui.box(@src(), .horizontal, tbi.defaults);
    defer tab.deinit();

    if (init_opts.show_context_menu.?) {
        const context_widget = try dvui.context(@src(), .{ .expand = .horizontal, .id_extra = @as(u16, @truncate(init_opts.id_extra.?)) });
        defer context_widget.deinit();

        if (context_widget.activePoint()) |active_point| {
            // The user right mouse clicked.
            // Save this state and keep rendering this item.
            // Return the right mouse click after all is rendered.
            user_action.user_selection = .context;
            try call_back(call_back_implementor, call_back_state, active_point);
        }
    }

    var layout: *dvui.BoxWidget = try dvui.box(@src(), .horizontal, .{});
    defer layout.deinit();

    // If there is a badge then display it.
    if (label.badge) |badge| {
        const imgsize = try dvui.imageSize("tab badge", badge);
        try dvui.image(
            @src(),
            "tab badge",
            badge,
            .{
                .padding = dvui.Rect{
                    .x = 5, // left
                    .y = 0, // top
                    .w = 0, // right
                    .h = 0, // bottom
                },
                .tab_index = 0,
                .gravity_y = 0.5,
                .gravity_x = 0.5,
                .min_size_content = .{ .w = imgsize.w, .h = imgsize.h },
            },
        );
    }

    if (try dvui.button(@src(), label.text.?, .{}, .{ .id_extra = init_opts.id_extra, .background = false })) {
        if (user_action.user_selection == .none) {
            user_action.user_selection = .select_tab;
        }
        return user_action;
    }

    if (init_opts.show_move_icons) |show_move_icons| {
        if (show_move_icons and init_opts.index.? > 0) {
            // Move left/up icon.
            // This icon is a button.
            switch (direction) {
                .horizontal => {
                    if (try dvui.buttonIcon(
                        @src(),
                        "entypo.chevron_small_left",
                        dvui.entypo.chevron_small_left,
                        .{},
                        .{ .id_extra = init_opts.id_extra.? },
                    )) {
                        // clicked
                        if (user_action.user_selection == .none) {
                            user_action.user_selection = .move_tab_left_up;
                            user_action.move_from_index = init_opts.id_extra.?;
                            user_action.move_to_index = init_opts.id_extra.? - 1;
                        }
                        return user_action;
                    }
                },
                .vertical => {
                    if (try dvui.buttonIcon(
                        @src(),
                        "entypo.chevron_small_up",
                        dvui.entypo.chevron_small_up,
                        .{},
                        .{ .id_extra = init_opts.id_extra.? },
                    )) {
                        // clicked
                        if (user_action.user_selection == .none) {
                            user_action.user_selection = .move_tab_left_up;
                            user_action.move_from_index = init_opts.id_extra.?;
                            user_action.move_to_index = init_opts.id_extra.? - 1;
                        }
                        return user_action;
                    }
                },
            }
        }

        if (show_move_icons and init_opts.index.? < init_opts.count_tabs.? - 1) {
            // Move right/down icon.
            // This icon is a button.
            switch (direction) {
                .horizontal => {
                    if (try dvui.buttonIcon(
                        @src(),
                        "entypo.chevron_small_right",
                        dvui.entypo.chevron_small_right,
                        .{},
                        .{ .id_extra = init_opts.id_extra.? },
                    )) {
                        // clicked
                        if (user_action.user_selection == .none) {
                            user_action.user_selection = .move_tab_right_down;
                            user_action.move_from_index = init_opts.id_extra.?;
                            user_action.move_to_index = init_opts.id_extra.? + 1;
                        }
                        return user_action;
                    }
                },
                .vertical => {
                    if (try dvui.buttonIcon(
                        @src(),
                        "entypo.chevron_small_down",
                        dvui.entypo.chevron_small_down,
                        .{},
                        .{ .id_extra = init_opts.id_extra.? },
                    )) {
                        // clicked
                        if (user_action.user_selection == .none) {
                            user_action.user_selection = .move_tab_right_down;
                            user_action.move_from_index = init_opts.id_extra.?;
                            user_action.move_to_index = init_opts.id_extra.? + 1;
                        }
                        return user_action;
                    }
                },
            }
        }
    }

    // The custom icons.
    if (label.icons) |icons| {
        const icon_id_extra_base = init_opts.id_extra.? * icons.len;
        var icon_id: usize = 0;
        for (icons, 0..) |icon, i| {
            // display this icon as a button even if no callback.
            icon_id = icon_id_extra_base + i;
            const clicked: bool = try dvui.buttonIcon(
                @src(),
                icon.label.?,
                icon.tvg_bytes,
                .{},
                .{ .id_extra = icon_id },
            );
            if (clicked) {
                if (icon.call_back) |icon_call_back| {
                    // This icon has a call back so call it.
                    try icon_call_back(icon.implementor.?, icon.state);
                    return user_action;
                } else {
                    // This icon has no call back so select this tab.
                    if (user_action.user_selection == .none) {
                        user_action.user_selection = .select_tab;
                    }
                    return user_action;
                }
            }
        }
    }

    if (init_opts.show_close_icon) |show_close_icon| {
        if (show_close_icon) {
            if (try dvui.buttonIcon(
                @src(),
                "entypo.cross",
                dvui.entypo.cross,
                .{},
                .{},
            )) {
                // clicked
                if (user_action.user_selection == .none) {
                    user_action.user_selection = .close_tab;
                }
                return user_action;
            }
        }
    }

    // No user action.
    return user_action;
}

pub fn tabBarItem(init_opts: TabBarItemWidget.InitOptions) !TabBarItemWidget {
    return TabBarItemWidget.init(init_opts);
}

pub fn init(init_opts: InitOptions) TabBarItemWidget {
    var self = TabBarItemWidget{};
    self.init_options = init_opts;
    self.defaults = switch (init_opts.flow.?) {
        .horizontal => blk: {
            switch (init_opts.selected.?) {
                true => break :blk horizontalDefaultSelectedOptions(),
                false => break :blk horizontalDefaultOptions(), //horizontal_defaults,
            }
        },
        .vertical => blk: {
            switch (init_opts.selected.?) {
                true => break :blk verticalDefaultSelectedOptions(),
                false => break :blk verticalDefaultOptions(),
            }
        },
    };
    if (init_opts.id_extra) |id_extra| {
        self.defaults.id_extra = id_extra;
    }
    return self;
}

pub fn install(self: *TabBarItemWidget, opts: struct { process_events: bool = true, focus_as_outline: bool = false }) !void {
    try self.wd.register();

    if (self.wd.visible()) {
        try dvui.tabIndexSet(self.wd.id, self.wd.options.tab_index);
    }

    if (opts.process_events) {
        const evts = dvui.events();
        for (evts) |*e| {
            if (dvui.eventMatch(e, .{ .id = self.data().id, .r = self.data().borderRectScale().r })) {
                self.processEvent(e, false);
            }
        }
    }

    try self.wd.borderAndBackground(.{});

    if (self.show_active) {
        _ = dvui.parentSet(self.widget());
        return;
    }

    var focused: bool = false;
    if (self.wd.id == dvui.focusedWidgetId()) {
        focused = true;
    } else if (self.wd.id == dvui.focusedWidgetIdInCurrentSubwindow() and self.highlight) {
        focused = true;
    }
    if (focused) {
        if (self.mouse_over) {
            self.show_active = true;
            // try self.wd.focusBorder();
            _ = dvui.parentSet(self.widget());
            return;
        } else {
            focused = false;
            self.show_active = false;
            dvui.focusWidget(null, null, null);
        }
    }

    if ((self.wd.id == dvui.focusedWidgetIdInCurrentSubwindow()) or self.highlight) {
        const rs = self.wd.backgroundRectScale();
        try dvui.pathAddRect(rs.r, self.wd.options.corner_radiusGet().scale(rs.s));
        try dvui.pathFillConvex(self.wd.options.color(.fill_hover));
    } else if (self.wd.options.backgroundGet()) {
        const rs = self.wd.backgroundRectScale();
        try dvui.pathAddRect(rs.r, self.wd.options.corner_radiusGet().scale(rs.s));
        try dvui.pathFillConvex(self.wd.options.color(.fill));
    }
    _ = dvui.parentSet(self.widget());
}

pub fn activeRect(self: *const TabBarItemWidget) ?dvui.Rect {
    if (self.activated) {
        const rs = self.wd.backgroundRectScale();
        return rs.r.scale(1 / dvui.windowNaturalScale());
    } else {
        return null;
    }
}

pub fn widget(self: *TabBarItemWidget) dvui.Widget {
    return dvui.Widget.init(self, data, rectFor, screenRectScale, minSizeForChild, processEvent);
}

pub fn data(self: *TabBarItemWidget) *dvui.WidgetData {
    return &self.wd;
}

pub fn rectFor(self: *TabBarItemWidget, id: u32, min_size: dvui.Size, e: dvui.Options.Expand, g: dvui.Options.Gravity) dvui.Rect {
    return dvui.placeIn(self.wd.contentRect().justSize(), dvui.minSize(id, min_size), e, g);
}

pub fn screenRectScale(self: *TabBarItemWidget, rect: dvui.Rect) dvui.RectScale {
    return self.wd.contentRectScale().rectToRectScale(rect);
}

pub fn minSizeForChild(self: *TabBarItemWidget, s: dvui.Size) void {
    self.wd.minSizeMax(self.wd.padSize(s));
}

pub fn processEvent(self: *TabBarItemWidget, e: *dvui.Event, bubbling: bool) void {
    _ = bubbling;
    var focused: bool = false;
    var focused_id: u32 = 0;
    if (dvui.focusedWidgetIdInCurrentSubwindow()) |_focused_id| {
        focused = self.wd.id == _focused_id;
        focused_id = _focused_id;
    }
    switch (e.evt) {
        .mouse => |me| {
            switch (me.action) {
                .focus => {
                    e.handled = true;
                    // dvui.focusSubwindow(null, null); // focuses the window we are in
                    dvui.focusWidget(self.wd.id, null, e.num);
                },
                .press => {
                    if (me.button == dvui.enums.Button.left) {
                        e.handled = true;
                    }
                },
                .release => {
                    e.handled = true;
                    self.activated = true;
                    dvui.refresh(null, @src(), self.data().id);
                },
                .position => {
                    e.handled = true;
                    // We get a .position mouse event every frame.  If we
                    // focus the tabBar item under the mouse even if it's not
                    // moving then it breaks keyboard navigation.
                    if (dvui.mouseTotalMotion().nonZero()) {
                        // self.highlight = true;
                        self.mouse_over = true;
                    }
                },
                else => {},
            }
        },
        .key => |ke| {
            if (ke.code == .space and ke.action == .down) {
                e.handled = true;
                if (!self.activated) {
                    self.activated = true;
                    dvui.refresh(null, @src(), self.data().id);
                }
            } else if (ke.code == .right and ke.action == .down) {
                e.handled = true;
            }
        },
        else => {},
    }

    if (e.bubbleable()) {
        self.wd.parent.processEvent(e, true);
    }
}

pub fn deinit(self: *TabBarItemWidget) void {
    self.wd.minSizeSetAndRefresh();
    self.wd.minSizeReportToParent();
    _ = dvui.parentSet(self.wd.parent);
}
