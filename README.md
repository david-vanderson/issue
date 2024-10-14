# Notes

1. The build.zig.zon file expects that you have already fetched the current dvui release. If not run `zig fetch https://github.com/david-vanderson/dvui/archive/refs/tags/v0.1.0.tar.gz`.
1. I'm using ubuntu 22 and wayland.

## Running the app

1. The app begins with the horizontal tab-bar displayed above tab content.
1. Click the `Align Left` icon at the left side of the tab-bar to convert the horizontal tab-bar to a vertical tab-bar.
1. On my computer, as soon as the tab-bar switches to vertical, the content area renders an unwanted vibration.
1. Click on the `Eye With Line` icon to hide the vertical tab-bar and the unwanted vibration is gone.
1. Click on the `Eye` icon to show the hidden vertical tab-bar and the unwanted vibration is still gone.

## What I learned. 2 more ways to stop the unwanted vibration

1. If start the app and make the window less tall before switching to the vertical tab-bar, I do not get the effect. I only get the effect if I keep the window at the same size.
1. The file src/deps/widgets/tabbar/TabBarItemWidget.zig contains the code that seems to cause the issue. It is shown below. Lines 231 - 250 can be commented out to stop the effect.

```zig
  1 ⎥ const std = @import("std");
  2 ⎥ const dvui = @import("dvui");
  3 ⎥ 
  4 ⎥ const ContainerLabel = @import("various").ContainerLabel;
  5 ⎥ 
  6 ⎥ const Direction = dvui.enums.Direction;
  7 ⎥ const Event = dvui.Event;
  8 ⎥ const Options = dvui.Options;
  9 ⎥ const Rect = dvui.Rect;
 10 ⎥ const RectScale = dvui.RectScale;
 11 ⎥ const Size = dvui.Size;
 12 ⎥ const Widget = dvui.Widget;
 13 ⎥ const WidgetData = dvui.WidgetData;
 14 ⎥ 
 15 ⎥ pub const UserSelection = enum {
 16 ⎥     none,
 17 ⎥     close_tab,
 18 ⎥     move_tab_right_down,
 19 ⎥     move_tab_left_up,
 20 ⎥     select_tab,
 21 ⎥     context,
 22 ⎥ };
 23 ⎥ 
 24 ⎥ pub const UserAction = struct {
 25 ⎥     user_selection: UserSelection = .none,
 26 ⎥     point_of_context: dvui.Point = undefined,
 27 ⎥     context_widget: *dvui.ContextWidget = undefined,
 28 ⎥     move_from_index: usize = 0,
 29 ⎥     move_to_index: usize = 0,
 30 ⎥ };
 31 ⎥ 
 32 ⎥ pub const TabBarItemWidget = @This();
 33 ⎥ 
 34 ⎥ pub const Flow = enum {
 35 ⎥     horizontal,
 36 ⎥     vertical,
 37 ⎥ };
 38 ⎥ 
 39 ⎥ pub const InitOptions = struct {
 40 ⎥     selected: ?bool = null,
 41 ⎥     flow: ?Flow = null,
 42 ⎥     id_extra: ?usize = null,
 43 ⎥     show_close_icon: ?bool = null,
 44 ⎥     show_move_icons: ?bool = null,
 45 ⎥     show_context_menu: ?bool = null,
 46 ⎥     index: ?usize = null,
 47 ⎥     count_tabs: ?usize = null,
 48 ⎥ };
 49 ⎥ 
 50 ⎥ const horizontal_init_options: InitOptions = .{
 51 ⎥     .id_extra = 0,
 52 ⎥     .selected = false,
 53 ⎥     .flow = .horizontal,
 54 ⎥ };
 55 ⎥ 
 56 ⎥ const vertical_init_options: InitOptions = .{
 57 ⎥     .id_extra = 0,
 58 ⎥     .selected = false,
 59 ⎥     .flow = .vertical,
 60 ⎥ };
 61 ⎥ 
 62 ⎥ wd: WidgetData = undefined,
 63 ⎥ focused_last_frame: bool = undefined,
 64 ⎥ highlight: bool = false,
 65 ⎥ defaults: dvui.Options = undefined,
 66 ⎥ init_options: InitOptions = undefined,
 67 ⎥ activated: bool = false,
 68 ⎥ show_active: bool = false,
 69 ⎥ mouse_over: bool = false,
 70 ⎥ 
 71 ⎥ // Defaults.
 72 ⎥ // Defaults for tabs in a horizontal tabbar.
 73 ⎥ fn horizontalDefaultOptions() dvui.Options {
 74 ⎥     var defaults: dvui.Options = .{
 75 ⎥         .name = "HorizontalTabBarItem",
 76 ⎥         .color_fill = .{ .name = .fill_hover },
 77 ⎥         .corner_radius = .{ .x = 2, .y = 2, .w = 0, .h = 0 },
 78 ⎥         .padding = .{ .x = 0, .y = 0, .w = 0, .h = 0 },
 79 ⎥         .border = .{ .x = 1, .y = 1, .w = 1, .h = 0 },
 80 ⎥         .margin = .{ .x = 4, .y = 0, .w = 0, .h = 8 },
 81 ⎥         .expand = .none,
 82 ⎥         .font_style = .body,
 83 ⎥         // .debug = false,
 84 ⎥     };
 85 ⎥     const hover: dvui.Color = dvui.themeGet().color_fill_hover;
 86 ⎥     const hover_hsl: dvui.Color.HSLuv = dvui.Color.HSLuv.fromColor(hover);
 87 ⎥     const darken: dvui.Color = hover_hsl.lighten(-16).color();
 88 ⎥     // const darken: dvui.Color = dvui.Color.darken(hover, 0.5);
 89 ⎥     defaults.color_border = .{ .color = darken };
 90 ⎥     return defaults;
 91 ⎥ }
 92 ⎥ 
 93 ⎥ fn horizontalDefaultSelectedOptions() dvui.Options {
 94 ⎥     const bg: dvui.Color = dvui.themeGet().color_fill_window;
 95 ⎥     var defaults = horizontalDefaultOptions();
 96 ⎥     defaults.color_fill = .{ .color = bg };
 97 ⎥     defaults.color_border = .{ .name = .accent };
 98 ⎥     defaults.margin = .{ .x = 4, .y = 7, .w = 0, .h = 0 };
 99 ⎥ 
100 ⎥     return defaults;
101 ⎥ }
102 ⎥ 
103 ⎥ fn verticalDefaultOptions() dvui.Options {
104 ⎥     var defaults: dvui.Options = .{
105 ⎥         .name = "VerticalTabBarItem",
106 ⎥         .color_fill = .{ .name = .fill_hover },
107 ⎥         .color_border = .{ .name = .fill_hover },
108 ⎥         .corner_radius = .{ .x = 2, .y = 0, .w = 0, .h = 2 },
109 ⎥         .padding = .{ .x = 0, .y = 0, .w = 1, .h = 0 },
110 ⎥         .border = .{ .x = 1, .y = 1, .w = 0, .h = 1 },
111 ⎥         .margin = .{ .x = 1, .y = 4, .w = 6, .h = 0 },
112 ⎥         .expand = .horizontal,
113 ⎥         .font_style = .body,
114 ⎥         .gravity_x = 1.0,
115 ⎥     };
116 ⎥     const hover: dvui.Color = dvui.themeGet().color_fill_hover;
117 ⎥     const hover_hsl: dvui.Color.HSLuv = dvui.Color.HSLuv.fromColor(hover);
118 ⎥     const darken: dvui.Color = hover_hsl.lighten(-16).color();
119 ⎥     // const darken: dvui.Color = dvui.Color.darken(hover, 0.5);
120 ⎥     defaults.color_border = .{ .color = darken };
121 ⎥     return defaults;
122 ⎥ }
123 ⎥ 
124 ⎥ pub fn verticalContextOptions() dvui.Options {
125 ⎥     return .{
126 ⎥         .name = "VerticalContext",
127 ⎥         .corner_radius = .{ .x = 2, .y = 0, .w = 0, .h = 2 },
128 ⎥         .padding = .{ .x = 0, .y = 0, .w = 0, .h = 0 },
129 ⎥         .border = .{ .x = 0, .y = 0, .w = 0, .h = 0 },
130 ⎥         .margin = .{ .x = 0, .y = 0, .w = 0, .h = 0 },
131 ⎥         .expand = .horizontal,
132 ⎥         .gravity_x = 1.0,
133 ⎥         .background = false,
134 ⎥     };
135 ⎥ }
136 ⎥ 
137 ⎥ fn verticalDefaultSelectedOptions() dvui.Options {
138 ⎥     const bg: dvui.Color = dvui.themeGet().color_fill_window;
139 ⎥     var defaults = verticalDefaultOptions();
140 ⎥     defaults.color_fill = .{ .color = bg };
141 ⎥     defaults.color_border = .{ .name = .accent };
142 ⎥     defaults.margin = .{ .x = 7, .y = 4, .w = 0, .h = 0 };
143 ⎥     return defaults;
144 ⎥ }
145 ⎥ 
146 ⎥ pub fn verticalSelectedContextOptions() dvui.Options {
147 ⎥     return verticalContextOptions();
148 ⎥ }
149 ⎥ 
150 ⎥ /// Param label is not owned by this fn.
151 ⎥ pub fn verticalTabBarItemLabel(
152 ⎥     label: *ContainerLabel,
153 ⎥     init_opts: InitOptions,
154 ⎥     call_back: *const fn (implementor: *anyopaque, state: *anyopaque, point_of_context: dvui.Point) anyerror!void,
155 ⎥     call_back_implementor: *anyopaque,
156 ⎥     call_back_state: *anyopaque,
157 ⎥ ) !UserAction {
158 ⎥     var tab_init_opts: TabBarItemWidget.InitOptions = TabBarItemWidget.vertical_init_options;
159 ⎥     if (init_opts.id_extra) |id_extra| {
160 ⎥         tab_init_opts.id_extra = id_extra;
161 ⎥     }
162 ⎥     if (init_opts.selected) |value| {
163 ⎥         tab_init_opts.selected = value;
164 ⎥     }
165 ⎥     tab_init_opts.index = init_opts.index;
166 ⎥     tab_init_opts.id_extra = init_opts.index;
167 ⎥     tab_init_opts.count_tabs = init_opts.count_tabs;
168 ⎥     tab_init_opts.show_close_icon = init_opts.show_close_icon orelse true;
169 ⎥     tab_init_opts.show_move_icons = init_opts.show_move_icons orelse true;
170 ⎥     tab_init_opts.show_context_menu = init_opts.show_context_menu orelse true;
171 ⎥ 
172 ⎥     return tabBarItemLabel(label, tab_init_opts, .vertical, call_back, call_back_implementor, call_back_state);
173 ⎥ }
174 ⎥ 
175 ⎥ /// Param label is not owned by this fn.
176 ⎥ pub fn horizontalTabBarItemLabel(
177 ⎥     label: *ContainerLabel,
178 ⎥     init_opts: InitOptions,
179 ⎥     call_back: *const fn (implementor: *anyopaque, state: *anyopaque, point_of_context: dvui.Point) anyerror!void,
180 ⎥     call_back_implementor: *anyopaque,
181 ⎥     call_back_state: *anyopaque,
182 ⎥ ) !UserAction {
183 ⎥     var tab_init_opts: TabBarItemWidget.InitOptions = TabBarItemWidget.horizontal_init_options;
184 ⎥     if (init_opts.id_extra) |id_extra| {
185 ⎥         tab_init_opts.id_extra = id_extra;
186 ⎥     }
187 ⎥     if (init_opts.selected) |value| {
188 ⎥         tab_init_opts.selected = value;
189 ⎥     }
190 ⎥     tab_init_opts.index = init_opts.index;
191 ⎥     tab_init_opts.id_extra = init_opts.index;
192 ⎥     tab_init_opts.count_tabs = init_opts.count_tabs;
193 ⎥     tab_init_opts.show_close_icon = init_opts.show_close_icon orelse true;
194 ⎥     tab_init_opts.show_move_icons = init_opts.show_move_icons orelse true;
195 ⎥     tab_init_opts.show_context_menu = init_opts.show_context_menu orelse true;
196 ⎥ 
197 ⎥     return tabBarItemLabel(label, tab_init_opts, .horizontal, call_back, call_back_implementor, call_back_state);
198 ⎥ }
199 ⎥ 
200 ⎥ // Param label is not owned by tabBarItemLabel.
201 ⎥ // Display the button-label and return it's rect if clicked else null.
202 ⎥ // Display each icon:
203 ⎥ // * If icon is clicked and no cb then return button-label rect.
204 ⎥ // * If icon is clicked and cp then run callback and return null.
205 ⎥ // * CB icons only is init_opts.selected == true.
206 ⎥ fn tabBarItemLabel(label: *ContainerLabel, init_opts: TabBarItemWidget.InitOptions, direction: Direction, call_back: *const fn (implementor: *anyopaque, state: *anyopaque, point_of_context: dvui.Point) anyerror!void, call_back_implementor: *anyopaque, call_back_state: *anyopaque) !UserAction {
207 ⎥     var user_action: UserAction = UserAction{};
208 ⎥     const tbi = try tabBarItem(init_opts);
209 ⎥ 
210 ⎥     std.log.info("init_opts.show_context_menu:{}", .{init_opts.show_context_menu.?});
211 ⎥     const tab: *dvui.BoxWidget = try dvui.box(@src(), .horizontal, tbi.defaults);
212 ⎥     defer tab.deinit();
213 ⎥ 
214 ⎥     if (init_opts.show_context_menu.?) {
215 ⎥         const context_widget = try dvui.context(@src(), .{ .expand = .horizontal, .id_extra = @as(u16, @truncate(init_opts.id_extra.?)) });
216 ⎥         defer context_widget.deinit();
217 ⎥ 
218 ⎥         if (context_widget.activePoint()) |active_point| {
219 ⎥             // The user right mouse clicked.
220 ⎥             // Save this state and keep rendering this item.
221 ⎥             // Return the right mouse click after all is rendered.
222 ⎥             user_action.user_selection = .context;
223 ⎥             try call_back(call_back_implementor, call_back_state, active_point);
224 ⎥         }
225 ⎥     }
226 ⎥ 
227 ⎥     var layout: *dvui.BoxWidget = try dvui.box(@src(), .horizontal, .{});
228 ⎥     defer layout.deinit();
229 ⎥ 
230 ⎥     // If there is a badge then display it.
231 ⎥     if (label.badge) |badge| {
232 ⎥         const imgsize = try dvui.imageSize("tab badge", badge);
233 ⎥         try dvui.image(
234 ⎥             @src(),
235 ⎥             "tab badge",
236 ⎥             badge,
237 ⎥             .{
238 ⎥                 .padding = dvui.Rect{
239 ⎥                     .x = 5, // left
240 ⎥                     .y = 0, // top
241 ⎥                     .w = 0, // right
242 ⎥                     .h = 0, // bottom
243 ⎥                 },
244 ⎥                 .tab_index = 0,
245 ⎥                 .gravity_y = 0.5,
246 ⎥                 .gravity_x = 0.5,
247 ⎥                 .min_size_content = .{ .w = imgsize.w, .h = imgsize.h },
248 ⎥             },
249 ⎥         );
250 ⎥     }
251 ⎥ 
252 ⎥     if (try dvui.button(@src(), label.text.?, .{}, .{ .id_extra = init_opts.id_extra, .background = false })) {
253 ⎥         if (user_action.user_selection == .none) {
254 ⎥             user_action.user_selection = .select_tab;
255 ⎥         }
256 ⎥         return user_action;
257 ⎥     }
258 ⎥ 
259 ⎥     if (init_opts.show_move_icons) |show_move_icons| {
260 ⎥         if (show_move_icons and init_opts.index.? > 0) {
261 ⎥             // Move left/up icon.
262 ⎥             // This icon is a button.
263 ⎥             switch (direction) {
264 ⎥                 .horizontal => {
265 ⎥                     if (try dvui.buttonIcon(
266 ⎥                         @src(),
267 ⎥                         "entypo.chevron_small_left",
268 ⎥                         dvui.entypo.chevron_small_left,
269 ⎥                         .{},
270 ⎥                         .{ .id_extra = init_opts.id_extra.? },
271 ⎥                     )) {
272 ⎥                         // clicked
273 ⎥                         if (user_action.user_selection == .none) {
274 ⎥                             user_action.user_selection = .move_tab_left_up;
275 ⎥                             user_action.move_from_index = init_opts.id_extra.?;
276 ⎥                             user_action.move_to_index = init_opts.id_extra.? - 1;
277 ⎥                         }
278 ⎥                         return user_action;
279 ⎥                     }
280 ⎥                 },
281 ⎥                 .vertical => {
282 ⎥                     if (try dvui.buttonIcon(
283 ⎥                         @src(),
284 ⎥                         "entypo.chevron_small_up",
285 ⎥                         dvui.entypo.chevron_small_up,
286 ⎥                         .{},
287 ⎥                         .{ .id_extra = init_opts.id_extra.? },
288 ⎥                     )) {
289 ⎥                         // clicked
290 ⎥                         if (user_action.user_selection == .none) {
291 ⎥                             user_action.user_selection = .move_tab_left_up;
292 ⎥                             user_action.move_from_index = init_opts.id_extra.?;
293 ⎥                             user_action.move_to_index = init_opts.id_extra.? - 1;
294 ⎥                         }
295 ⎥                         return user_action;
296 ⎥                     }
297 ⎥                 },
298 ⎥             }
299 ⎥         }
300 ⎥ 
301 ⎥         if (show_move_icons and init_opts.index.? < init_opts.count_tabs.? - 1) {
302 ⎥             // Move right/down icon.
303 ⎥             // This icon is a button.
304 ⎥             switch (direction) {
305 ⎥                 .horizontal => {
306 ⎥                     if (try dvui.buttonIcon(
307 ⎥                         @src(),
308 ⎥                         "entypo.chevron_small_right",
309 ⎥                         dvui.entypo.chevron_small_right,
310 ⎥                         .{},
311 ⎥                         .{ .id_extra = init_opts.id_extra.? },
312 ⎥                     )) {
313 ⎥                         // clicked
314 ⎥                         if (user_action.user_selection == .none) {
315 ⎥                             user_action.user_selection = .move_tab_right_down;
316 ⎥                             user_action.move_from_index = init_opts.id_extra.?;
317 ⎥                             user_action.move_to_index = init_opts.id_extra.? + 1;
318 ⎥                         }
319 ⎥                         return user_action;
320 ⎥                     }
321 ⎥                 },
322 ⎥                 .vertical => {
323 ⎥                     if (try dvui.buttonIcon(
324 ⎥                         @src(),
325 ⎥                         "entypo.chevron_small_down",
326 ⎥                         dvui.entypo.chevron_small_down,
327 ⎥                         .{},
328 ⎥                         .{ .id_extra = init_opts.id_extra.? },
329 ⎥                     )) {
330 ⎥                         // clicked
331 ⎥                         if (user_action.user_selection == .none) {
332 ⎥                             user_action.user_selection = .move_tab_right_down;
333 ⎥                             user_action.move_from_index = init_opts.id_extra.?;
334 ⎥                             user_action.move_to_index = init_opts.id_extra.? + 1;
335 ⎥                         }
336 ⎥                         return user_action;
337 ⎥                     }
338 ⎥                 },
339 ⎥             }
340 ⎥         }
341 ⎥     }
342 ⎥ 
343 ⎥     // The custom icons.
344 ⎥     if (label.icons) |icons| {
345 ⎥         const icon_id_extra_base = init_opts.id_extra.? * icons.len;
346 ⎥         var icon_id: usize = 0;
347 ⎥         for (icons, 0..) |icon, i| {
348 ⎥             // display this icon as a button even if no callback.
349 ⎥             icon_id = icon_id_extra_base + i;
350 ⎥             const clicked: bool = try dvui.buttonIcon(
351 ⎥                 @src(),
352 ⎥                 icon.label.?,
353 ⎥                 icon.tvg_bytes,
354 ⎥                 .{},
355 ⎥                 .{ .id_extra = icon_id },
356 ⎥             );
357 ⎥             if (clicked) {
358 ⎥                 if (icon.call_back) |icon_call_back| {
359 ⎥                     // This icon has a call back so call it.
360 ⎥                     try icon_call_back(icon.implementor.?, icon.state);
361 ⎥                     return user_action;
362 ⎥                 } else {
363 ⎥                     // This icon has no call back so select this tab.
364 ⎥                     if (user_action.user_selection == .none) {
365 ⎥                         user_action.user_selection = .select_tab;
366 ⎥                     }
367 ⎥                     return user_action;
368 ⎥                 }
369 ⎥             }
370 ⎥         }
371 ⎥     }
372 ⎥ 
373 ⎥     if (init_opts.show_close_icon) |show_close_icon| {
374 ⎥         if (show_close_icon) {
375 ⎥             if (try dvui.buttonIcon(
376 ⎥                 @src(),
377 ⎥                 "entypo.cross",
378 ⎥                 dvui.entypo.cross,
379 ⎥                 .{},
380 ⎥                 .{},
381 ⎥             )) {
382 ⎥                 // clicked
383 ⎥                 if (user_action.user_selection == .none) {
384 ⎥                     user_action.user_selection = .close_tab;
385 ⎥                 }
386 ⎥                 return user_action;
387 ⎥             }
388 ⎥         }
389 ⎥     }
390 ⎥ 
391 ⎥     // No user action.
392 ⎥     return user_action;
393 ⎥ }
394 ⎥ 
395 ⎥ pub fn tabBarItem(init_opts: TabBarItemWidget.InitOptions) !TabBarItemWidget {
396 ⎥     return TabBarItemWidget.init(init_opts);
397 ⎥ }
398 ⎥ 
399 ⎥ pub fn init(init_opts: InitOptions) TabBarItemWidget {
400 ⎥     var self = TabBarItemWidget{};
401 ⎥     self.init_options = init_opts;
402 ⎥     self.defaults = switch (init_opts.flow.?) {
403 ⎥         .horizontal => blk: {
404 ⎥             switch (init_opts.selected.?) {
405 ⎥                 true => break :blk horizontalDefaultSelectedOptions(),
406 ⎥                 false => break :blk horizontalDefaultOptions(), //horizontal_defaults,
407 ⎥             }
408 ⎥         },
409 ⎥         .vertical => blk: {
410 ⎥             switch (init_opts.selected.?) {
411 ⎥                 true => break :blk verticalDefaultSelectedOptions(),
412 ⎥                 false => break :blk verticalDefaultOptions(),
413 ⎥             }
414 ⎥         },
415 ⎥     };
416 ⎥     if (init_opts.id_extra) |id_extra| {
417 ⎥         self.defaults.id_extra = id_extra;
418 ⎥     }
419 ⎥     return self;
420 ⎥ }
421 ⎥ 
422 ⎥ pub fn install(self: *TabBarItemWidget, opts: struct { process_events: bool = true, focus_as_outline: bool = false }) !void {
423 ⎥     try self.wd.register();
424 ⎥ 
425 ⎥     if (self.wd.visible()) {
426 ⎥         try dvui.tabIndexSet(self.wd.id, self.wd.options.tab_index);
427 ⎥     }
428 ⎥ 
429 ⎥     if (opts.process_events) {
430 ⎥         const evts = dvui.events();
431 ⎥         for (evts) |*e| {
432 ⎥             if (dvui.eventMatch(e, .{ .id = self.data().id, .r = self.data().borderRectScale().r })) {
433 ⎥                 self.processEvent(e, false);
434 ⎥             }
435 ⎥         }
436 ⎥     }
437 ⎥ 
438 ⎥     try self.wd.borderAndBackground(.{});
439 ⎥ 
440 ⎥     if (self.show_active) {
441 ⎥         _ = dvui.parentSet(self.widget());
442 ⎥         return;
443 ⎥     }
444 ⎥ 
445 ⎥     var focused: bool = false;
446 ⎥     if (self.wd.id == dvui.focusedWidgetId()) {
447 ⎥         focused = true;
448 ⎥     } else if (self.wd.id == dvui.focusedWidgetIdInCurrentSubwindow() and self.highlight) {
449 ⎥         focused = true;
450 ⎥     }
451 ⎥     if (focused) {
452 ⎥         if (self.mouse_over) {
453 ⎥             self.show_active = true;
454 ⎥             // try self.wd.focusBorder();
455 ⎥             _ = dvui.parentSet(self.widget());
456 ⎥             return;
457 ⎥         } else {
458 ⎥             focused = false;
459 ⎥             self.show_active = false;
460 ⎥             dvui.focusWidget(null, null, null);
461 ⎥         }
462 ⎥     }
463 ⎥ 
464 ⎥     if ((self.wd.id == dvui.focusedWidgetIdInCurrentSubwindow()) or self.highlight) {
465 ⎥         const rs = self.wd.backgroundRectScale();
466 ⎥         try dvui.pathAddRect(rs.r, self.wd.options.corner_radiusGet().scale(rs.s));
467 ⎥         try dvui.pathFillConvex(self.wd.options.color(.fill_hover));
468 ⎥     } else if (self.wd.options.backgroundGet()) {
469 ⎥         const rs = self.wd.backgroundRectScale();
470 ⎥         try dvui.pathAddRect(rs.r, self.wd.options.corner_radiusGet().scale(rs.s));
471 ⎥         try dvui.pathFillConvex(self.wd.options.color(.fill));
472 ⎥     }
473 ⎥     _ = dvui.parentSet(self.widget());
474 ⎥ }
475 ⎥ 
476 ⎥ pub fn activeRect(self: *const TabBarItemWidget) ?dvui.Rect {
477 ⎥     if (self.activated) {
478 ⎥         const rs = self.wd.backgroundRectScale();
479 ⎥         return rs.r.scale(1 / dvui.windowNaturalScale());
480 ⎥     } else {
481 ⎥         return null;
482 ⎥     }
483 ⎥ }
484 ⎥ 
485 ⎥ pub fn widget(self: *TabBarItemWidget) dvui.Widget {
486 ⎥     return dvui.Widget.init(self, data, rectFor, screenRectScale, minSizeForChild, processEvent);
487 ⎥ }
488 ⎥ 
489 ⎥ pub fn data(self: *TabBarItemWidget) *dvui.WidgetData {
490 ⎥     return &self.wd;
491 ⎥ }
492 ⎥ 
493 ⎥ pub fn rectFor(self: *TabBarItemWidget, id: u32, min_size: dvui.Size, e: dvui.Options.Expand, g: dvui.Options.Gravity) dvui.Rect {
494 ⎥     return dvui.placeIn(self.wd.contentRect().justSize(), dvui.minSize(id, min_size), e, g);
495 ⎥ }
496 ⎥ 
497 ⎥ pub fn screenRectScale(self: *TabBarItemWidget, rect: dvui.Rect) dvui.RectScale {
498 ⎥     return self.wd.contentRectScale().rectToRectScale(rect);
499 ⎥ }
500 ⎥ 
501 ⎥ pub fn minSizeForChild(self: *TabBarItemWidget, s: dvui.Size) void {
502 ⎥     self.wd.minSizeMax(self.wd.padSize(s));
503 ⎥ }
504 ⎥ 
505 ⎥ pub fn processEvent(self: *TabBarItemWidget, e: *dvui.Event, bubbling: bool) void {
506 ⎥     _ = bubbling;
507 ⎥     var focused: bool = false;
508 ⎥     var focused_id: u32 = 0;
509 ⎥     if (dvui.focusedWidgetIdInCurrentSubwindow()) |_focused_id| {
510 ⎥         focused = self.wd.id == _focused_id;
511 ⎥         focused_id = _focused_id;
512 ⎥     }
513 ⎥     switch (e.evt) {
514 ⎥         .mouse => |me| {
515 ⎥             switch (me.action) {
516 ⎥                 .focus => {
517 ⎥                     e.handled = true;
518 ⎥                     // dvui.focusSubwindow(null, null); // focuses the window we are in
519 ⎥                     dvui.focusWidget(self.wd.id, null, e.num);
520 ⎥                 },
521 ⎥                 .press => {
522 ⎥                     if (me.button == dvui.enums.Button.left) {
523 ⎥                         e.handled = true;
524 ⎥                     }
525 ⎥                 },
526 ⎥                 .release => {
527 ⎥                     e.handled = true;
528 ⎥                     self.activated = true;
529 ⎥                     dvui.refresh(null, @src(), self.data().id);
530 ⎥                 },
531 ⎥                 .position => {
532 ⎥                     e.handled = true;
533 ⎥                     // We get a .position mouse event every frame.  If we
534 ⎥                     // focus the tabBar item under the mouse even if it's not
535 ⎥                     // moving then it breaks keyboard navigation.
536 ⎥                     if (dvui.mouseTotalMotion().nonZero()) {
537 ⎥                         // self.highlight = true;
538 ⎥                         self.mouse_over = true;
539 ⎥                     }
540 ⎥                 },
541 ⎥                 else => {},
542 ⎥             }
543 ⎥         },
544 ⎥         .key => |ke| {
545 ⎥             if (ke.code == .space and ke.action == .down) {
546 ⎥                 e.handled = true;
547 ⎥                 if (!self.activated) {
548 ⎥                     self.activated = true;
549 ⎥                     dvui.refresh(null, @src(), self.data().id);
550 ⎥                 }
551 ⎥             } else if (ke.code == .right and ke.action == .down) {
552 ⎥                 e.handled = true;
553 ⎥             }
554 ⎥         },
555 ⎥         else => {},
556 ⎥     }
557 ⎥ 
558 ⎥     if (e.bubbleable()) {
559 ⎥         self.wd.parent.processEvent(e, true);
560 ⎥     }
561 ⎥ }
562 ⎥ 
563 ⎥ pub fn deinit(self: *TabBarItemWidget) void {
564 ⎥     self.wd.minSizeSetAndRefresh();
565 ⎥     self.wd.minSizeReportToParent();
566 ⎥     _ = dvui.parentSet(self.wd.parent);
567 ⎥ }
568 ⎥ 
```