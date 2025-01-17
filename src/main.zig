/// This is where the application starts.
/// This file was generated by kickzig when you created the framework.
/// This file will be never be touched by kickzig.
/// You are free to edit this file.
const std = @import("std");
const dvui = @import("dvui");
const SDLBackend = dvui.backend;
const _backend_ = @import("backend/api.zig");
const _channel_ = @import("channel");
const _closer_ = @import("closer");
const _closedownjobs_ = @import("closedownjobs");
const _embed_ = @import("embed");
const _frontend_ = @import("frontend/api.zig");
const _modal_params_ = @import("modal_params");
const _startup_ = @import("startup");

const ExitFn = @import("various").ExitFn;
const MainView = @import("framers").MainView;

// KICKZIG TODO:
// When the user clicks the window's X:
// - If a modal screen is not shown:
//   * then the app will just close.
// - If a modal screen is shown:
//   * If force_close == true: then the app will just close.
//   * If force_close == false: then the app will not close until after the modal screen is hidden (closes).
const force_close: bool = true;

// General Purpose Allocator for frontend-state, backend and channels.
var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = gpa_instance.allocator();

const vsync = true;
var show_dialog_outside_frame: bool = false;

/// This example shows how to use the dvui for a normal application:
/// - dvui renders the whole application
/// - render frames only when needed
pub fn main() !void {
    // init SDL sdl_backend (creates OS window)
    var sdl_backend = try SDLBackend.initWindow(.{
        .allocator = gpa,
        .size = .{ .w = 500.0, .h = 400.0 },
        // .min_size = .{ .w = 500.0, .h = 400.0 },
        .vsync = vsync,
        .title = "icons",
        .icon = _embed_.window_icon_png,
    });
    defer sdl_backend.deinit();

    // init dvui Window (maps onto a single OS window)
    var win = try dvui.Window.init(@src(), gpa, sdl_backend.backend(), .{});
    // win.content_scale = sdl_backend.initial_scale * 1.5;
    defer win.deinit();

    var main_view: *MainView = undefined;
    var close_down_jobs: *_closedownjobs_.Jobs = try _closedownjobs_.Jobs.init(gpa);
    defer close_down_jobs.deinit();
    const exit: ExitFn = try _closer_.init(gpa, close_down_jobs, &win);
    defer _closer_.deinit();

    // The channels between the front and back ends.
    const back_to_front_channels: *_channel_.BackendToFrontend = try _channel_.BackendToFrontend.init(gpa, exit);
    defer back_to_front_channels.deinit();
    const front_to_back_channels: *_channel_.FrontendToBackend = try _channel_.FrontendToBackend.init(gpa, exit);
    defer front_to_back_channels.deinit();
    const triggers: *_channel_.Trigger = try _channel_.Trigger.init(gpa, exit);
    defer triggers.deinit();

    // Initialize the front end.
    // See src/deps/startup/api.zig
    const dark_theme = win.themes.getPtr("Adwaita Dark").?;
    var startup_frontend: _startup_.Frontend = _startup_.Frontend{
        .allocator = gpa,
        .window = &win,
        .theme = dark_theme,
        .send_channels = front_to_back_channels,
        .receive_channels = back_to_front_channels,
        .main_view = undefined,
        .close_down_jobs = close_down_jobs,
        .exit = exit,
        .screen_pointers = undefined,
    };
    main_view = try MainView.init(startup_frontend);
    defer main_view.deinit();
    startup_frontend.setMainView(main_view);
    try _frontend_.init(&startup_frontend);
    defer _frontend_.deinit();
    _closer_.set_screens(main_view);

    // Initialize and kick-start the back end.
    try _backend_.init(
        .{
            .allocator = gpa,
            .send_channels = back_to_front_channels,
            .receive_channels = front_to_back_channels,
            .close_down_jobs = close_down_jobs,
            .triggers = triggers,
            .exit = exit,
        },
    );
    defer _backend_.deinit();

    // KICKZIG TODO: See backend.kickStart();
    try _backend_.kickStart();

    var theme_set: bool = false;
    main_loop: while (true) {

        // beginWait coordinates with waitTime below to run frames only when needed
        const nstime = win.beginWait(sdl_backend.hasEvent());

        // marks the beginning of a frame for dvui, can call dvui functions after this
        try win.begin(nstime);

        // set the theme.
        if (!theme_set) {
            theme_set = true;
            dvui.themeSet(dark_theme);
        }

        // send all SDL events to dvui for processing
        const quit = try sdl_backend.addAllEvents(&win);

        for (dvui.events()) |*e| {
            if (e.evt == .key and e.evt.key.code == .f10 and e.evt.key.action == .down) {
                e.handled = true;
                _frontend_.main_menu_key_pressed = true;
                break;
            }
        }

        // The state of the app's closer.
        switch (_closer_.context()) {
            .none => {
                if (quit) {
                    // User clicked window's X to close the window.
                    // Start the closing process.
                    _closer_.close("Bye-bye.", force_close);
                } else {
                    // Not closing.
                    // Continue running the app.
                }
            },
            .forced => {
                // The previous frame set closer_state to .forced.
                // So on this frame, force the close.
                // Start the closing process.
                _closer_.forced();
            },
            .started => {
                // The close process has already started.
                // The close process is now running.
            },
            .completed => {
                // The close process has completed.
                // Stop framing.
                break :main_loop;
            },
            .waiting => {
                // The close process is now waiting for the current modal screen to close.
                // When that modal screen closes, the closing state will switch to .started.
                _closer_.waiting();
            },
        }

        // if dvui widgets might not cover the whole window, then need to clear
        // the previous frame's render
        //sdl_backend.clear();
        _ = SDLBackend.c.SDL_SetRenderDrawColor(sdl_backend.renderer, 0, 0, 0, 255);
        _ = SDLBackend.c.SDL_RenderClear(sdl_backend.renderer);

        {
            // Frame the front-end.
            var arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena_allocator.deinit();
            try _frontend_.frame(arena_allocator.allocator());
        }

        // marks end of dvui frame, don't call dvui functions after this
        // - sends all dvui stuff to backend for rendering, must be called before renderPresent()
        const end_micros = try win.end(.{});

        // cursor management
        sdl_backend.setCursor(win.cursorRequested());

        // render frame to OS
        sdl_backend.renderPresent();

        // waitTime and beginWait combine to achieve variable framerates
        const wait_event_micros = win.waitTime(end_micros, null);
        sdl_backend.waitEventTimeout(wait_event_micros);

        // Example of how to show a dialog from another thread (outside of win.begin/win.end)
        if (show_dialog_outside_frame) {
            show_dialog_outside_frame = false;
            try dvui.dialog(@src(), .{ .window = &win, .modal = false, .title = "Dialog from Outside", .message = "This is a non modal dialog that was created outside win.begin()/win.end(), usually from another thread." });
        }
    }
}
