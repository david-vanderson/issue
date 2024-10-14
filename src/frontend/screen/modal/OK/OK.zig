const std = @import("std");
const dvui = @import("dvui");

const Panels = @import("panels.zig").Panels;
const ExitFn = @import("various").ExitFn;
const MainView = @import("framers").MainView;
const ModalParams = @import("modal_params").OK;
const View = @import("view/OK.zig").View;

pub const Panel = struct {
    allocator: std.mem.Allocator,
    window: *dvui.Window,
    main_view: *MainView,
    all_panels: *Panels,
    exit: ExitFn,
    view: ?*View,

    modal_params: ?*ModalParams,
    border_color: dvui.Options.ColorOrName,

    // This panels owns the modal params.
    pub fn presetModal(self: *Panel, setup_args: *ModalParams) !void {
        if (self.modal_params) |modal_params| {
            modal_params.deinit();
        }
        self.modal_params = setup_args;
    }

    pub fn init(allocator: std.mem.Allocator, main_view: *MainView, all_panels: *Panels, exit: ExitFn, window: *dvui.Window, theme: *dvui.Theme) !*Panel {
        var self: *Panel = try allocator.create(Panel);
        self.allocator = allocator;
        self.window = window;
        self.main_view = main_view;
        self.all_panels = all_panels;
        self.exit = exit;
        self.modal_params = null;
        self.view = try View.init(
            allocator,
            window,
            main_view,
            all_panels,
            exit,
            theme,
        );
        errdefer {
            self.view = null;
            self.deinit();
        }
        return self;
    }

    pub fn deinit(self: *Panel) void {
        if (self.view) |member| {
            member.deinit();
        }
        if (self.modal_params) |member| {
            member.deinit();
        }
        self.allocator.destroy(self);
    }

    /// frame this panel.
    /// Layout, Draw, Handle user events.
    pub fn frame(self: *Panel, arena: std.mem.Allocator) !void {
        return self.view.?.frame(arena, self.modal_params.?);
    }
};