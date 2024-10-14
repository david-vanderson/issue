const std = @import("std");
const dvui = @import("dvui");

const _modal_params_ = @import("modal_params");
const _startup_ = @import("startup");
const sorted_main_menu_screen_tags = @import("main_menu").sorted_main_menu_screen_tags;
const startup_screen_tag = @import("main_menu").startup_screen_tag;

const Container = @import("various").Container;
const ExitFn = @import("various").ExitFn;

pub const ScreenTags = @import("screen_tags.zig").ScreenTags;

/// MainView is each and every screen.
pub const MainView = struct {
    allocator: std.mem.Allocator,
    lock: std.Thread.Mutex,
    window: *dvui.Window,
    exit: ExitFn,
    current: ?ScreenTags,
    current_modal_is_new: bool,
    current_is_modal: bool,
    previous: ?ScreenTags,
    modal_args: ?*anyopaque,

    pub fn init(startup: _startup_.Frontend) !*MainView {
        var self: *MainView = try startup.allocator.create(MainView);
        self.lock = std.Thread.Mutex{};

        self.allocator = startup.allocator;
        self.exit = startup.exit;
        self.window = startup.window;

        self.current = null;
        self.previous = null;
        self.current_is_modal = false;
        self.modal_args = null;
        self.current_modal_is_new = false;

        return self;
    }

    pub fn deinit(self: *MainView) void {
        self.allocator.destroy(self);
    }

    pub fn isModal(self: *MainView) bool {
        self.lock.lock();
        defer self.lock.unlock();

        return self.current_is_modal;
    }

    pub fn isNewModal(self: *MainView) bool {
        self.lock.lock();
        defer self.lock.unlock();

        const is_new: bool = self.current_modal_is_new;
        self.current_modal_is_new = false;
        return is_new;
    }

    pub fn currentTag(self: *MainView) ?ScreenTags {
        self.lock.lock();
        defer self.lock.unlock();

        return self.current;
    }

    pub fn modalArgs(self: *MainView) ?*anyopaque {
        self.lock.lock();
        defer self.lock.unlock();

        const modal_args = self.modal_args;
        self.modal_args = null;
        return modal_args;
    }


    pub fn show(self: *MainView, screen: ScreenTags) !void {
        self.lock.lock();
        defer self.lock.unlock();

        if (!MainView.isMainMenuTag(screen)) {
            return error.NotAMainMenuTag;
        }

        // Only show if not a modal screen.
        return switch (screen) {
            .HelloWorld => self._showHelloWorld(),
            .Icons => self._showIcons(),
            else => error.CantShowModalScreen,
        };
    }

    pub fn refresh(self: *MainView, screen: ScreenTags) void {
        self.lock.lock();
        defer self.lock.unlock();

        switch (screen) {
            .HelloWorld => self._refreshHelloWorld(),
            .Icons => self._refreshIcons(),
            .YesNo => self._refreshYesNo(),
            .OK => self._refreshOK(),
            else => {}, // EOJ.
        }
    }

    fn isMainMenuTag(screen: ScreenTags) bool {
        if (screen == startup_screen_tag) {
            return true;
        }
        for (sorted_main_menu_screen_tags) |tag| {
            if (tag == screen) {
                return true;
            }
        }
        return false;
    }


    // The HelloWorld screen.

    /// showHelloWorld makes the HelloWorld screen to the current one.
    pub fn showHelloWorld(self: *MainView) void {
        self.lock.lock();
        defer self.lock.unlock();

        self._showHelloWorld();
    }

    /// _showHelloWorld makes the HelloWorld screen to the current one.
    fn _showHelloWorld(self: *MainView) void {
        if (!isMainMenuTag(.HelloWorld)) {
            // The .HelloWorld tag is not in the main menu.
            return;
        }

        if (!self.current_is_modal) {
            // The current screen is not modal so replace it.
            self.current = .HelloWorld;
            self.current_is_modal = false;
        }
    }

    /// refreshHelloWorld refreshes the window if the HelloWorld screen is the current one.
    pub fn refreshHelloWorld(self: *MainView) void {
        self.lock.lock();
        defer self.lock.unlock();

        self._refreshHelloWorld();
    }

    /// _refreshHelloWorld refreshes the window if the HelloWorld screen is the current one.
    pub fn _refreshHelloWorld(self: *MainView) void {
        if (self.current) |current| {
            if (current == .HelloWorld) {
                // HelloWorld is the current screen.
                dvui.refresh(self.window, @src(), null);
            }
        }
    }

    /// refreshHelloWorldContainerFn refreshes the window if the HelloWorld screen is the current one.
    pub fn refreshHelloWorldContainerFn(implementor: *anyopaque) void {
        var self: *MainView = @alignCast(@ptrCast(implementor));
        self.refreshHelloWorld();
    }

    /// Convert MainView to a Container interface for the HelloWorld screen.
    pub fn asHelloWorldContainer(self: *MainView) anyerror!*Container {
        return Container.init(
            self.allocator,
            self,
            null,
            MainView.refreshHelloWorldContainerFn,
        );
    }
    // The Icons screen.

    /// showIcons makes the Icons screen to the current one.
    pub fn showIcons(self: *MainView) void {
        self.lock.lock();
        defer self.lock.unlock();

        self._showIcons();
    }

    /// _showIcons makes the Icons screen to the current one.
    fn _showIcons(self: *MainView) void {
        if (!isMainMenuTag(.Icons)) {
            // The .Icons tag is not in the main menu.
            return;
        }

        if (!self.current_is_modal) {
            // The current screen is not modal so replace it.
            self.current = .Icons;
            self.current_is_modal = false;
        }
    }

    /// refreshIcons refreshes the window if the Icons screen is the current one.
    pub fn refreshIcons(self: *MainView) void {
        self.lock.lock();
        defer self.lock.unlock();

        self._refreshIcons();
    }

    /// _refreshIcons refreshes the window if the Icons screen is the current one.
    pub fn _refreshIcons(self: *MainView) void {
        if (self.current) |current| {
            if (current == .Icons) {
                // Icons is the current screen.
                dvui.refresh(self.window, @src(), null);
            }
        }
    }

    /// refreshIconsContainerFn refreshes the window if the Icons screen is the current one.
    pub fn refreshIconsContainerFn(implementor: *anyopaque) void {
        var self: *MainView = @alignCast(@ptrCast(implementor));
        self.refreshIcons();
    }

    /// Convert MainView to a Container interface for the Icons screen.
    pub fn asIconsContainer(self: *MainView) anyerror!*Container {
        return Container.init(
            self.allocator,
            self,
            null,
            MainView.refreshIconsContainerFn,
        );
    }    // The YesNo modal screen.

    /// showYesNo starts the YesNo modal screen.
    /// Param args is the YesNo modal args.
    /// showYesNo owns modal_args_ptr.
    pub fn showYesNo(self: *MainView, modal_args_ptr: *anyopaque) void {
        self.lock.lock();
        defer self.lock.unlock();
        defer dvui.refresh(self.window, @src(), null);

        if (self.current_is_modal) {
            // The current modal is still showing.
            return;
        }
        // Save the current screen.
        self.previous = self.current;
        self.current_modal_is_new = true;
        self.current_is_modal = true;
        self.modal_args = modal_args_ptr;
        self.current = .YesNo;
    }

    /// hideYesNo hides the modal screen YesNo.
    pub fn hideYesNo(self: *MainView) void {
        self.lock.lock();
        defer self.lock.unlock();

        if (self.current) |current| {
            if (current == .YesNo) {
                // YesNo is the current screen so hide it.
                self.current = self.previous;
                self.current_is_modal = false;
                self.modal_args = null;
                self.previous = null;
            }
        }
    }

    /// refreshYesNo refreshes the window if the YesNo screen is the current one.
    pub fn refreshYesNo(self: *MainView) void {
        self.lock.lock();
        defer self.lock.unlock();

        if (self.current) |current| {
            if (current == .YesNo) {
                // YesNo is the current screen.
                dvui.refresh(self.window, @src(), null);
            }
        }
    }

    /// refreshYesNoContainerFn refreshes the window if the YesNo screen is the current one.
    pub fn refreshYesNoContainerFn(implementor: *anyopaque) void {
        var self: *MainView = @alignCast(@ptrCast(implementor));
        self.refreshYesNo();
    }

    /// Convert MainView to a Container interface for the YesNo screen.
    pub fn asYesNoContainer(self: *MainView) anyerror!*Container {
        return Container.init(
            self.allocator,
            self,
            null,
            MainView.refreshYesNoContainerFn,
        );
    }
    // The OK modal screen.

    /// showOK starts the OK modal screen.
    /// Param args is the OK modal args.
    /// showOK owns modal_args_ptr.
    pub fn showOK(self: *MainView, modal_args_ptr: *anyopaque) void {
        self.lock.lock();
        defer self.lock.unlock();
        defer dvui.refresh(self.window, @src(), null);

        if (self.current_is_modal) {
            // The current modal is still showing.
            return;
        }
        // Save the current screen.
        self.previous = self.current;
        self.current_modal_is_new = true;
        self.current_is_modal = true;
        self.modal_args = modal_args_ptr;
        self.current = .OK;
    }

    /// hideOK hides the modal screen OK.
    pub fn hideOK(self: *MainView) void {
        self.lock.lock();
        defer self.lock.unlock();

        if (self.current) |current| {
            if (current == .OK) {
                // OK is the current screen so hide it.
                self.current = self.previous;
                self.current_is_modal = false;
                self.modal_args = null;
                self.previous = null;
            }
        }
    }

    /// refreshOK refreshes the window if the OK screen is the current one.
    pub fn refreshOK(self: *MainView) void {
        self.lock.lock();
        defer self.lock.unlock();

        if (self.current) |current| {
            if (current == .OK) {
                // OK is the current screen.
                dvui.refresh(self.window, @src(), null);
            }
        }
    }

    /// refreshOKContainerFn refreshes the window if the OK screen is the current one.
    pub fn refreshOKContainerFn(implementor: *anyopaque) void {
        var self: *MainView = @alignCast(@ptrCast(implementor));
        self.refreshOK();
    }

    /// Convert MainView to a Container interface for the OK screen.
    pub fn asOKContainer(self: *MainView) anyerror!*Container {
        return Container.init(
            self.allocator,
            self,
            null,
            MainView.refreshOKContainerFn,
        );
    }

    // The EOJ modal screen.

    /// forceEOJ starts the EOJ modal screen even if another modal is shown.
    /// Param args is the EOJ modal args.
    /// forceEOJ owns modal_args_ptr.
    pub fn forceEOJ(self: *MainView, modal_args_ptr: *anyopaque) void {
        self.lock.lock();
        defer self.lock.unlock();

        // Don't save the current screen.
        self.current_modal_is_new = true;
        self.current_is_modal = true;
        self.modal_args = modal_args_ptr;
        self.current = .EOJ;
    }

    /// showEOJ starts the EOJ modal screen.
    /// Param args is the EOJ modal args.
    /// showEOJ owns modal_args_ptr.
    pub fn showEOJ(self: *MainView, modal_args_ptr: *anyopaque) void {
        self.lock.lock();
        defer self.lock.unlock();

        if (self.current_is_modal) {
            // The current modal is not hidden yet.
            return;
        }
        // Don't save the current screen.
        self.current_modal_is_new = true;
        self.current_is_modal = true;
        self.modal_args = modal_args_ptr;
        self.current = .EOJ;
    }

    /// hideEOJ hides the modal screen EOJ.
    pub fn hideEOJ(self: *MainView) void {
        self.lock.lock();
        defer self.lock.unlock();

        if (self.current) |current| {
            if (current == .EOJ) {
                // EOJ is the current screen so hide it.
                self.current = self.previous;
                self.current_is_modal = false;
                self.modal_args = null;
                self.previous = null;
            }
        }
    }

    /// refreshEOJ refreshes the window if the EOJ screen is the current one.
    pub fn refreshEOJ(self: *MainView) void {
        self.lock.lock();
        defer self.lock.unlock();

        if (self.current) |current| {
            if (current == .EOJ) {
                // EOJ is the current screen.
                dvui.refresh(self.window, @src(), null);
            }
        }
    }

};
