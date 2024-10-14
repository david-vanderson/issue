const std = @import("std");
const dvui = @import("dvui");

const Container = @import("various").Container;
const ExitFn = @import("various").ExitFn;
const MainView = @import("framers").MainView;
const Messenger = @import("messenger.zig").Messenger;
const OKModalParams = @import("modal_params").OK;
const Panels = @import("../panels.zig").Panels;
const ScreenOptions = @import("../screen.zig").Options;
const YesNoModalParams = @import("modal_params").YesNo;

pub const Options = struct {
    allocator: ?std.mem.Allocator = null,
    opened_ok_modal: ?bool = null,
    opened_yesno_modal: ?bool = null,

    fn init(allocator: std.mem.Allocator, defaults: Options) !*Options {
        var self: *Options = try allocator.create(Options);
        self.allocator = allocator;
        self.opened_ok_modal = null;
        self.opened_yesno_modal = null;
        try self.reset(defaults);
        errdefer self.deinit();
        return self;
    }

    pub fn deinit(self: *Options) void {
        // Screen name.
        self.allocator.?.destroy(self);
    }

    fn reset(
        self: *Options,
        settings: Options,
    ) !void {
        return self._reset(
            settings.opened_ok_modal,
            settings.opened_yesno_modal,
        );
    }

    fn _reset(
        self: *Options,
        opened_ok_modal: ?bool,
        opened_yesno_modal: ?bool,
    ) !void {
        if (opened_ok_modal) |value| {
            self.opened_ok_modal = value;
        }
        if (opened_yesno_modal) |value| {
            self.opened_yesno_modal = value;
        }
    }
};

pub const View = struct {
    allocator: std.mem.Allocator,
    window: *dvui.Window,
    main_view: *MainView,
    container: ?*Container,
    all_panels: *Panels,
    messenger: *Messenger,
    yes_no: ?bool,
    exit: ExitFn,
    lock: std.Thread.Mutex,
    state: ?*Options,
    screen_options: ScreenOptions,

    const default_settings = Options{
        .opened_ok_modal = false,
        .opened_yesno_modal = false,
    };

    /// KICKZIG TODO:
    /// fn frame is the View's true purpose.
    /// Layout, Draw, Handle user events.
    /// The arena allocator is for building this frame. Not for state.
    pub fn frame(
        self: *View,
        arena: std.mem.Allocator,
    ) !void {
        _ = arena;

        self.lock.lock();
        defer self.lock.unlock();

        // Begin with the view's master layout.
        // A vertical stack.
        // So that the scroll area is always under the heading.
        // Row 1 is the heading.
        // Row 2 is the scroller with it's own vertically stacked content.
        var master_layout: *dvui.BoxWidget = dvui.box(
            @src(),
            .vertical,
            .{
                .expand = .both,
                .background = true,
                .name = "master_layout",
            },
        ) catch |err| {
            self.exit(@src(), err, "dvui.box");
            return err;
        };
        defer master_layout.deinit();

        {
            // Vertical Stack Row 1: The screen's name.
            // Use the same background as the scroller.
            var row1: *dvui.BoxWidget = dvui.box(
                @src(),
                .horizontal,
                .{
                    .expand = .horizontal,
                    .background = true,
                },
            ) catch |err| {
                self.exit(@src(), err, "row1");
                return err;
            };
            defer row1.deinit();

            dvui.labelNoFmt(@src(), "HelloWorld", .{ .font_style = .title }) catch |err| {
                self.exit(@src(), err, "row1 label");
                return err;
            };
        }

        {
            // Vertical Stack Row 2: The vertical scroller.
            // The vertical scroller has it's contents vertically stacked.
            var scroller = dvui.scrollArea(@src(), .{}, .{ .expand = .both }) catch |err| {
                self.exit(@src(), err, "scroller");
                return err;
            };
            defer scroller.deinit();

            // Vertically stack the scroller's contents.
            var scroller_layout: *dvui.BoxWidget = dvui.box(@src(), .vertical, .{ .expand = .horizontal }) catch |err| {
                self.exit(@src(), err, "scroller_layout");
                return err;
            };
            defer scroller_layout.deinit();

            {
                // Scroller's Content Row 1. The panel's name.
                // Row 1 has 2 columns.
                var scroller_row1: *dvui.BoxWidget = dvui.box(@src(), .horizontal, .{}) catch |err| {
                    self.exit(@src(), err, "scroller_row1");
                    return err;
                };
                defer scroller_row1.deinit();
                // Row 1 Column 1: The label.
                dvui.labelNoFmt(@src(), "Panel Name: ", .{ .font_style = .heading }) catch |err| {
                    self.exit(@src(), err, "scroller_row1 heading");
                    return err;
                };
                // Row 1 Column 2: The panel's name.
                dvui.labelNoFmt(@src(), "HelloWorld", .{}) catch |err| {
                    self.exit(@src(), err, "scroller_row1 text");
                    return err;
                };
            }
            {
                // Scroller's Content Row 2.
                // Instructions using a text layout widget.
                var scroller_row2 = dvui.TextLayoutWidget.init(
                    @src(),
                    .{},
                    .{
                        .expand = .horizontal,
                    },
                );
                defer scroller_row2.deinit();
                scroller_row2.install(.{}) catch |err| {
                    self.exit(@src(), err, "scroller_row2 instructions");
                    return err;
                };

                const intructions: []const u8 =
                    \\The HelloWorld screen is a panel screen.
                    \\Panel screens function by showing only one panel at a time.
                    \\
                    \\Using this screen:
                    \\ 1. In the main menu:
                    \\    * Add .HelloWorld to pub const sorted_main_menu_screen_tags in src/deps/main_menu/api.zig.
                    \\ 2. As content for a tab.
                    \\    * kickzig add-tab «new-screen-name» *HelloWorld «[*]other-tab-names ...»
                    \\
                ;
                try scroller_row2.addText(intructions, .{});
            }
            {
                // Scroller's Content Row 3.
                // A button which closes the container.
                if (self.container.?.isCloseable()) {
                    // This screens container can be closed.
                    // Allow the user to close the container.
                    const pressed: bool = dvui.button(@src(), "Close Container.", .{}, .{}) catch |err| {
                        self.exit(@src(), err, "row3 close container button");
                        return err;
                    };
                    if (pressed) {
                        self.container.?.close();
                    }
                }
            }
            {
                // Scroller's Content Row 3.
                // A button which opens the OK modal screen using 1 column.
                const pressed: bool = dvui.button(@src(), "OK Modal Screen.", .{}, .{}) catch |err| {
                    self.exit(@src(), err, "row3 OK Modal button");
                    return err;
                };
                if (pressed) {
                    // Modal params a part of the modal state.
                    // There fore using the gpa not the arena.
                    const ok_args = OKModalParams.init(self.allocator, "Using the OK Modal Screen!", "This is the OK modal activated from the HelloWorld panel in the HelloWorld screen.") catch |err| {
                        self.exit(@src(), err, "row3 ok_args");
                        return err;
                    };
                    self.main_view.showOK(ok_args);
                    if (!self.state.?.opened_ok_modal.?) {
                        self._setState(.{ .opened_ok_modal = true }) catch |err| {
                            self.exit(@src(), err, "self._setState");
                            return err;
                        };
                    }
                }
            }

            {
                // Row 3: A button which opens the YesNo modal screen.
                if (try dvui.button(@src(), "YesNo Modal Screen.", .{}, .{})) {
                    var heading: []const u8 = undefined;
                    const yes_label: []const u8 = "Yes.";
                    const no_label: []const u8 = "No.";
                    if (self.yes_no) |yes_no| {
                        if (yes_no) {
                            heading = "You clicked Yes last time.";
                        } else {
                            heading = "You cliced No last time.";
                        }
                    } else {
                        heading = "You haven't clicked any buttons yet so click one!";
                    }
                    // Modal params a part of the modal state.
                    // There fore using the gpa not the arena.
                    const yesno_args = try YesNoModalParams.init(
                        self.allocator,
                        heading,
                        "Click any button.",
                        yes_label,
                        no_label,
                        self,
                        View.modalYesCB,
                        View.modalNoCB,
                    );
                    self.main_view.showYesNo(yesno_args);
                    self._setState(.{ .opened_yesno_modal = true }) catch |err| {
                        self.exit(@src(), err, "self._setState");
                        return err;
                    };
                }
            }
        }
    }

    pub fn init(
        allocator: std.mem.Allocator,
        window: *dvui.Window,
        main_view: *MainView,
        container: ?*Container,
        all_panels: *Panels,
        messenger: *Messenger,
        exit: ExitFn,
        screen_options: ScreenOptions,
    ) !*View {
        var self: *View = try allocator.create(View);
        self.allocator = allocator;

        // Initialize state.
        self.state = try Options.init(allocator, default_settings);
        errdefer {
            self.state = null;
            self.deinit();
        }

        self.window = window;
        self.main_view = main_view;
        self.container = container;
        self.all_panels = all_panels;
        self.messenger = messenger;
        self.yes_no = null;
        self.exit = exit;
        self.lock = std.Thread.Mutex{};
        self.screen_options = screen_options;
        return self;
    }

    pub fn deinit(self: *View) void {
        if (self.state) |state| {
            state.deinit();
        }
        self.allocator.destroy(self);
    }

    /// setState uses the not null members of param settings to modify self.state.
    /// param settings is owned by the caller.
    pub fn setState(self: *View, settings: Options) !void {
        self.lock.lock();
        defer self.lock.unlock();

        return self._setState(settings);
    }

    /// _setState uses the not null members of param settings to modify self.state.
    /// Use _setState during framing or whenever View is locked.
    /// self.lock must be locked.
    /// param settings is owned by the caller.
    /// Refreshes this view after updating the state.
    fn _setState(self: *View, settings: Options) !void {
        self.state.?.reset(settings) catch |err| {
            self.exit(@src(), err, "HelloWorld.HelloWorld unable to set state");
            return err;
        };
        self.container.?.refresh();
    }

    /// The caller owns the returned value.
    pub fn getState(self: *View) !*Options {
        self.lock.lock();
        defer self.lock.unlock();

        return Options.init(self.allocator, self.state.?.*);
    }

    /// refresh only if this view's panel is showing.
    pub fn refresh(self: *View) void {
        if (self.all_panels.current_panel_tag == .HelloWorld) {
            // This is the current panel.
            self.container.?.refresh();
        }
    }

    pub fn setContainer(self: *View, container: *Container) !void {
        if (self.container != null) {
            return error.ContainerAlreadySet;
        }
        self.container = container;
    }

    fn modalNoCB(implementor: *anyopaque) void {
        var self: *View = @alignCast(@ptrCast(implementor));
        self.lock.lock();
        self.yes_no = false;
        self.lock.unlock();
    }

    fn modalYesCB(implementor: *anyopaque) void {
        var self: *View = @alignCast(@ptrCast(implementor));
        self.lock.lock();
        self.yes_no = true;
        self.lock.unlock();
    }
};
