const std = @import("std");

const _channel_ = @import("channel");
const _message_ = @import("message");

const ExitFn = @import("various").ExitFn;
const MainView = @import("framers").MainView;
//const OKModalParams = @import("modal_params").OK;
const Panels = @import("../panels.zig").Panels;
const ScreenOptions = @import("../screen.zig").Options;
const ScreenTags = @import("framers").ScreenTags;

pub const Messenger = struct {
    allocator: std.mem.Allocator,

    main_view: *MainView,
    all_panels: *Panels,
    send_channels: *_channel_.FrontendToBackend,
    receive_channels: *_channel_.BackendToFrontend,
    exit: ExitFn,
    screen_options: ScreenOptions,

    pub fn init(
        allocator: std.mem.Allocator,
        main_view: *MainView,
        send_channels: *_channel_.FrontendToBackend,
        receive_channels: *_channel_.BackendToFrontend,
        exit: ExitFn,
        screen_options: ScreenOptions,
    ) !*Messenger {
        var self: *Messenger = try allocator.create(Messenger);
        self.allocator = allocator;
        self.main_view = main_view;
        self.send_channels = send_channels;
        self.receive_channels = receive_channels;
        self.exit = exit;
        self.screen_options = screen_options;

        // For a messenger to receive a message, the messenger must:
        //
        // 1. Implement the behavior of the message's channel.
        // var fooBehavior = try receive_channels.Foo.initBehavior();
        // errdefer {
        //     allocator.destroy(self);
        // }
        // fooBehavior.implementor = self;
        // fooBehavior.receiveFn = Messenger.receiveFoo;
        //
        // 2. Subscribe to the Foo channel in order to receive the Foo messages.
        // try receive_channels.Foo.subscribe(fooBehavior);
        // errdefer {
        //     allocator.destroy(self);
        // }

        return self;
    }

    pub fn deinit(self: *Messenger) void {
        self.allocator.destroy(self);
    }

    // Below is an example to send a Fubar message.
    // For this example, the HelloWorld panel made this request.
    // // sendFubar is called by a tab's panel.
    // pub fn sendFubar(
    //     self: *Messenger,
    //     stuff: []const u8,
    //     other_stuff: usize,
    // ) !void {
    //     var msg: *_message_.Fubar = _message_.Fubar.init(
    //         self.allocator,
    //
    //         .HelloWorld, // This screen's _framers_.ScreenTag.
    //
    //         stuff, // Stuff to send.
    //         other_stuff, // more stuff to send.
    //     ) catch |err| {
    //         self.exit(@src(), err, "unable to init a Fubar message");
    //         return err;
    //     };
    //
    //     self.send_channels.Fubar.send(msg) catch |err| {
    //         self.exit(@src(), err, "HelloWorld unable to send a Fubar message");
    //         return err;
    //     };
    // }

    // Below is an example of a receive function.
    // // It receives the Foo message and handles a user error message.
    // // It implements a behavior required by receive_channels.Foo.
    // pub fn receiveFoo(implementor: *anyopaque, message: *_message_.Foo.Message) anyerror!void {
    //     var self: *Messenger = @alignCast(@ptrCast(implementor));
    //     defer message.deinit();
    //
    //     // message.backend_payload is the struct holding the message from the backend.
    //     if (message.backend_payload.user_error_message) |user_error_message| {
    //         // There was a user error so inform the user.
    //         const ok_args = OKModalParams.init(
    //            self.allocator,
    //            "Error",
    //            user_error_message,
    //         ) catch |err| {
    //             self.exit(@src(), err, "HelloWorld OKModalParams.init");
    //             return err;
    //         };
    //         // The ok modal screen owns the ok_args.
    //         // So do not deinit the ok_args.
    //         self.main_view.showOK(ok_args)
    //         // This was only a user error not a fatal error.
    //         return;
    //     }
    //     // No user error.
    //     // Pass on the information contained in the message to panels.
    //     // fn setState will handles the error correctly.
    //     try self.panels.FooBar.setState(
    //         {
    //             .something = message.BackendPayload.something,
    //         },
    //     );
    // }
};
