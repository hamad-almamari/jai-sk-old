#assert(OS == .WINDOWS);

// Multi window: @InComplete yet.
// FullScreen: @InComplete.

create :: (width:u32, height:u32, name:string, position_x:s32 = -1 , position_y:s32 = -1, style:Window_Style = 0, parent:*Window = null) -> *Window {
    if !window_class_initted init_window_class();
    parent_hwnd := null;
    ws_style: u32;
    if parent {
        assert(parent.hwnd != null && parent.valid);
        parent_hwnd = parent.hwnd;
        if style == 0 then ws_style = to_ws_style(Window_Style.SECONDARY);
    } else {
        if style == 0 then ws_style = to_ws_style(Window_Style.PRIMARY);
    }

    // adjust window width and height.
    rect : RECT;
    rect.right  = xx width;
    rect.bottom = xx height;
    AdjustWindowRect(*rect, ws_style, .FALSE);
    r_width  := rect.right-rect.left;
    r_height := rect.bottom-rect.top;
    //log("A: % -- %", width, height);
    //log("B: % -- %", r_width, r_height);
    // window default postion
    SPI_GETWORKAREA :: 0x30;
    SystemParametersInfoW :: (uiAction: u32, uiParam: u32, pvParam: *void, fWinIni: u32) -> BOOL #foreign user32;
    if position_x == -1 || position_y == -1 {
        work_area: RECT;
        work_area_success := SystemParametersInfoW(SPI_GETWORKAREA, 0, *work_area, 0);
        if work_area_success {
            position_x = work_area.left;
            position_y = work_area.top;
        }
    }
    // Create the window
    hwnd := CreateWindowExW(0, 
        utf8_to_wide(WINDOW_CLASS_NAME),
        utf8_to_wide(name),
        ws_style,
        xx position_x, xx position_y,
        xx r_width, xx r_height,
        parent_hwnd,
        null,
        class_hinstance,
        null); 
    assert(hwnd != null, "create_window: CreateWindowExW failed.");
    {
        // **This code taken from the default "Window_Creation" module.**
        // Resize the window with respect to the DPI-awareness. If the process is not DPI-aware, then the returned values are unscaled.
        scaled_x, scaled_y, scaled_width, scaled_height := DPI.os_dpi_get_backing_coordinates(hwnd, xx position_x, xx position_y, xx width, xx height);
        //log("%, %, %, %",scaled_x, scaled_y, scaled_width, scaled_height);
        d_rect: RECT;
        d_rect.right  = xx scaled_width;
        d_rect.bottom = xx scaled_height;
        AdjustWindowRect(*d_rect, ws_style, .FALSE);

        new_width  := (d_rect.right-d_rect.left);
        new_height := (d_rect.bottom-d_rect.top);

        //log("DPI: befor: %x% , after: %x%", width, height, new_width, new_height);

        SetWindowPos(hwnd, HWND_TOPMOST, xx scaled_x, xx scaled_y, new_width, new_height, SWP_NOACTIVATE|SWP_NOZORDER);
    }

    //log("create_window: CREATED %", name);
    window := New(Window);
    window.name   = copy_string(name);
    window.hinstance = class_hinstance;
    window.hwnd   = hwnd;
    window.valid  = true;
    window.events = .JUST_INITIALIZED;
    window.parent = parent;
    window.creation_thread_index = context.thread_index;
    
    array_add(*window_list, window);

    // Update and Display the window
    // we call this after we add the window to window_list to add 
    // JUST_INITIALIZED | GAINFOUCS | RESIZED | MOVED events.
    UpdateWindow(hwnd);
    ShowWindow(hwnd, SW_SHOW);

    return window;
}

destroy :: (using window: *Window) {
    if !window return;
    if hwnd != null DestroyWindow(hwnd);
    valid = false;
    array_unordered_remove_by_value(*window_list, window);
    free(window.name);
    free(window);

    // @HACK to avoid leaks.
    if window_list.count == 0 array_free(window_list);
}

// process/update window events
//
// Do not call this more than once per frame.
process_events :: (using window: *Window) {
    assert(window.valid && window.hwnd);
    assert(creation_thread_index == context.thread_index, "You can call process_events from the window creation thread only");

    { // handle last frame events
        // release all keys, as soon the window minimized the events of key release not signalled to win proc.
        if events & .MINIMIZED then Bitset.clear_all(*keys_state);

        if events & .QUIT_REQUEST {
            ok := DestroyWindow(hwnd);
            assert(ok != .FALSE); // If the function succeeds, the return value is nonzero.
            // NOTE: window events and flags will be updated by win_proc immediately.
            return;
        }
    }

    if !(events & .JUST_INITIALIZED) {
        window.events = 0;
        frame_index  += 1;
    } else {
        window.events &= ~.JUST_INITIALIZED;
    }

    window.input_events = 0;
    window.keys_state_lastframe = window.keys_state;
    while true {
        msg: MSG;
        result := PeekMessageW(*msg, window.hwnd, 0, 0, PM_REMOVE);
        if !result break;
        // if msg.message != WM_MOUSEFIRST && msg.message != WM_NCMOUSEMOVE {
        //     print("% : %:% - %:%  :%\n", msg.hwnd, window_list[0].name, window_list[0].hwnd, window_list[1].name, window_list[1].hwnd, cast(Debug_Enum) msg.message);
        // }
        TranslateMessage(*msg);
        DispatchMessageW(*msg);
    }
}

// quit/close window and its childs next frame.
quit :: (using window: *Window) {
    assert(window && valid && hwnd != null);
    events |= .QUIT_REQUEST;
}

minimize :: (using window: *Window) {
    assert(window && valid && hwnd != null);
    if flags & .IS_MINIMIZED return;
    ShowWindow(hwnd, SW_MINIMIZE);
    // NOTE: window events and flags will be updated by win_proc immediately.
}

maximize :: (using window: *Window) {
    assert(window && valid && hwnd != null);
    if window.flags & .IS_FULLSCREEN || window.flags & .IS_MINIMIZED return;
    ShowWindow(hwnd, SW_MAXIMIZE);
    UpdateWindow(hwnd);
    // NOTE: window events and flags will be updated by win_proc immediately.
} 

restore :: (using window: *Window) {
    assert(window && valid && hwnd != null);
    if (window.flags & .IS_FULLSCREEN) ||
       (window.flags & .IS_MAXIMIZED)  ||
       (window.flags & .IS_MINIMIZED) {
        ShowWindow(hwnd, SW_RESTORE);
        UpdateWindow(hwnd);
        // NOTE: window events and flags will be updated by win_proc immediately.
    }
}

get_size :: (using window: *Window, including_borders := false) -> (width: u32, height: u32) {
    assert(window && valid && hwnd != null);
    r: RECT;
    if including_borders { 
        GetWindowRect(hwnd, *r);
    } else {
        GetClientRect(hwnd, *r);
    }
    return cast(u32)(r.right - r.left), cast(u32)(r.bottom - r.top);
}

get_size_as_float :: (window: *Window, including_borders := false) -> (width: float, height: float) {
    assert(window && valid && hwnd != null);
    w, h := inline get_window_size(window, including_borders);
    return cast(float) w, cast(float) h;
}

get_position :: (using window: *Window) -> (x: s32, y: s32) {
    assert(window && valid && hwnd != null);
    r: RECT;
    GetWindowRect(hwnd, *r);
    return r.left, r.top;
}

get_display_size :: (using window: *Window) -> (width: s32, height: s32) {
    assert(window && valid && hwnd != null);
    m_info: MONITORINFO;
    m_info.cbSize = size_of(type_of(m_info));
    success := GetMonitorInfoW(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST), *m_info);
    if success {
        m_width  : s32 = (m_info.rcMonitor.right  - m_info.rcMonitor.left);
        m_height : s32 = (m_info.rcMonitor.bottom - m_info.rcMonitor.top);
        return m_width, m_height;
    } else {
        log_error("GetMonitorInfoW failed!!");
        return 0, 0;
    }
}

// Input

// return x, y
//
//   0,0_____________
//   |               |
//   |               |
//   |               |
//   |_______________|w,h
//
get_relative_mouse_position :: (using window: *Window) -> (x: s32, y: s32) {
    assert(window && valid && hwnd != null);
    p: POINT;
    win_success := GetCursorPos(*p);
    if !win_success return -1, -1;
    ScreenToClient :: (hwnd: HWND, p: *POINT) -> s32 #foreign user32;
    win_success = ScreenToClient(hwnd, *p);
    return p.x, p.y;
}

get_relative_mouse_position_as_float :: (window: *Window) -> (x: float, y: float) {
    assert(window && valid && hwnd != null);
    x, y := inline get_relative_mouse_position(window);
    return cast(float) x, cast(float) y;
}

// return x, y    where w >= x >= 0 and h >= y >= 0
//
//   0,0_____________
//   |               |
//   |               |
//   |               |
//   |_______________|w,h

get_mouse_position :: (using window: *Window) -> (x: s32, y: s32) {
    assert(window && valid && hwnd != null);
    p: POINT;
    win_success := GetCursorPos(*p);
    if !win_success return -1, -1;
    ScreenToClient :: (hwnd: HWND, p: *POINT) -> s32 #foreign user32;
    win_success = ScreenToClient(hwnd, *p);
    _w, _h := get_size(window);
    w := cast(s32) _w;
    h := cast(s32) _h;
    x := ifx p.x > w then w else p.x;
    y := ifx p.y > h then h else p.y;
    if x < 0 then x = 0;
    if y < 0 then y = 0;
    return x, y;
}

get_mouse_position_as_float :: (window: *Window) -> (x: float, y: float) {
    assert(window && valid && hwnd != null);
    x, y := inline get_mouse_position(window);
    return cast(float) x, cast(float) y;
}

// by default windows reset the cursor to AROW
set_cursor :: (cursor: Cursor) {
    c: *u8;
    if #complete cursor == {
        case .ARROW;
            if !win_cursors.arrow then win_cursors.arrow = LoadCursorW(xx null, IDC_ARROW);
            c = win_cursors.arrow;
        case .HAND;
            if !win_cursors.hand then win_cursors.hand = LoadCursorW(xx null, IDC_HAND);
            c = win_cursors.hand;
    }
    SetCursor :: (hCursor: HCURSOR) -> HCURSOR #foreign user32;
    SetCursor(c);
}

#scope_file
#import "Basic";
#import "Windows";
#import "Windows_Utf8";
DPI     :: #import "DPI";
user32  :: #foreign_system_library "user32";
win_cursors: struct {
    arrow: *u8;
    hand : *u8;
};

find_window_by_hwnd :: (hwnd:HWND) -> *Window #no_context {
    if hwnd == null return null;
    for window_list {
        if it && it.hwnd == hwnd { 
            return it;
        }
    }
    return null;
}

window_proc :: (hwnd: HWND, msg: u32, wParam: WPARAM, lParam: LPARAM) -> s64 #c_call {
    // new_context: Context;
    // new_context.allocator = Context.default_allocator;
    // new_context.logger    = Context.default_logger;
    // push_context new_context {

    window: *Window;
    if msg == {
        case WM_CREATE; 
            // not added to window_list yet.  
        case WM_QUIT; #through;
        case WM_CLOSE;
            window = find_window_by_hwnd(hwnd);
            if window then window.events |= .QUIT_REQUEST;
            return 0; // we will post WM_DESTROY at the end of this frame by calling DestroyWindow.

        case WM_DESTROY;
            window = find_window_by_hwnd(hwnd);
            if window {
                window.valid  = false;
                window.flags  = 0;
                window.events = 0;
                window.hwnd   = null;
            }

        case WM_PAINT;
		    ValidateRect(hwnd, null);
	        return DefWindowProcW(hwnd, msg, wParam, lParam);

        case WM_SIZE;
            window = find_window_by_hwnd(hwnd);
            if window {
                window.events |= .RESIZED;
                if wParam == SIZE_MINIMIZED {
                    window.events |= .MINIMIZED;
                    window.events &= ~.DEMINIMIZED;
                    window.flags  |= .IS_MINIMIZED;
                    window.flags  &= ~.IS_MAXIMIZED;
                }

                if wParam == SIZE_MAXIMIZED {
                    window.events |= .MAXIMIZED;
                    window.events &= ~.DEMAXIMIZED;
                    window.flags |= .IS_MAXIMIZED; 
                    window.flags &= ~.IS_MINIMIZED;
                }

                if wParam == SIZE_RESTORED && (window.flags & .IS_MAXIMIZED || window.flags & .IS_MINIMIZED) {
                    if window.flags & .IS_MINIMIZED {
                        window.events |= .DEMINIMIZED;
                        window.events &= ~.MINIMIZED;
                    }
                    if window.flags & .IS_MAXIMIZED {
                        window.events |= .DEMAXIMIZED;
                        window.events &= ~.MAXIMIZED;
                    }
                    window.flags &= ~.IS_MINIMIZED;
                    window.flags &= ~.IS_MAXIMIZED;
                }
                
                return 0;      
            }
        
//             case WM_EXITSIZEMOVE;
//                 // NOTE: if a child window is has been resized/moved this event goes to its parent. +_+ 
//                 // the hwnd value is not child window it is its parent.
//                 // win32_windows_events[index] |= .RESIZED;
//                 return 0;

            case WM_MOVE;
                window = find_window_by_hwnd(hwnd);
                // win events order FOCUS -> MOVE -> SIZE
                // we do not want to fire moved if the window just minimized
                // so we add this check to do not add .MOVED event if the window is minimized or un-minimized (restored)
                if window {
                    check : bool = (window.flags & .HAS_FOUCS) && !(window.events & .LOSTFOUCS);
                    if check then window.events |= .MOVED;
                    return 0;
                }

            case WM_SETFOCUS;
                window = find_window_by_hwnd(hwnd);
                if window {
                    window.events |= .GAINFOUCS;
                    window.events &= ~.LOSTFOUCS;
                    window.flags |= .HAS_FOUCS;
                }
            case WM_KILLFOCUS;
                window = find_window_by_hwnd(hwnd);
                if window {
                    window.events |= .LOSTFOUCS;
                    window.events &= ~.GAINFOUCS;
                    window.flags  &= ~.HAS_FOUCS;
                }

//             // case WM_INPUT;
//             //     log("INPUT");
//             //     extra := GetMessageExtraInfo();
//             //     if (extra & 0x82) == 0x82 {
//             //         // Ignore touch input!
//             //     } else {
//             //         process_raw_input(cast(HRAWINPUT)lParam);
//             //     }
//             //     DefWindowProcW(hwnd, msg, wParam, lParam);

            case WM_SYSKEYDOWN; #through;
            case WM_KEYDOWN;
                window = find_window_by_hwnd(hwnd);
                if window {
                    // we do not care about repeat just we want the key press event
                    repeat := ((cast (s32) lParam) & 0x40000000); 
                    if !repeat {
                        key_code := vk_to_key_code(wParam);
                        // since window_proc is #c_call and we do not want to push new context
                        // we just we will use the source code of Bitset.Set to avoid calling it.
                        // Bitset.set(*window.keys_state, xx key);
                        i := cast(int) key_code;
                        window.keys_state.buffer[i >> 6] |= (1 << (i & 63));
                    }
                }
            case WM_SYSKEYUP; #through;
            case WM_KEYUP;
                window = find_window_by_hwnd(hwnd);
                if window {
                    key_code := vk_to_key_code(wParam);
                    i := cast(int) key_code;
                    window.keys_state.buffer[i >> 6] &= ~(1 << (i & 63));
                }
            case WM_LBUTTONDOWN;
                window = find_window_by_hwnd(hwnd);
                if window {
                    SetCapture(hwnd);
                    i := cast(int) Key_Code.MOUSE_LEFT;
                    window.keys_state.buffer[i >> 6] |= (1 << (i & 63));
                } 
            case WM_LBUTTONUP;
                ReleaseCapture();
                window = find_window_by_hwnd(hwnd);
                if window {
                    i := cast(int) Key_Code.MOUSE_LEFT;   
                    window.keys_state.buffer[i >> 6] &= ~(1 << (i & 63));
                }
            case WM_RBUTTONDOWN;
                window = find_window_by_hwnd(hwnd);
                if window { 
                    i := cast(int) Key_Code.MOUSE_RIGHT;
                    window.keys_state.buffer[i >> 6] |= (1 << (i & 63));
                }
            case WM_RBUTTONUP;
                window = find_window_by_hwnd(hwnd);
                if window {   
                    i := cast(int) Key_Code.MOUSE_RIGHT;   
                    window.keys_state.buffer[i >> 6] &= ~(1 << (i & 63));
                }
            case WM_MBUTTONDOWN;
                window = find_window_by_hwnd(hwnd);
                if window { 
                    i := cast(int) Key_Code.MOUSE_MIDDLE;
                    window.keys_state.buffer[i >> 6] |= (1 << (i & 63));
                }
            case WM_MBUTTONUP;
                window = find_window_by_hwnd(hwnd);
                if window { 
                    i := cast(int) Key_Code.MOUSE_MIDDLE;   
                    window.keys_state.buffer[i >> 6] &= ~(1 << (i & 63));
                }

//             case WM_MOUSEMOVE;
//             // we use diff way now
//                 // x := (lParam & 0xffff);
//                 // y := (lParam >> 16) & 0xffff;
//                 // // update our mouse positions
//                 // state.mouse_x_position = xx x;
//                 // state.mouse_y_position = xx y;

            // Mouse wheel
            case WM_MOUSEWHEEL;
                window = find_window_by_hwnd(hwnd);
                if window {
                    window.input_events |= .MOUSE_WHEEL_SCROLL;
                    //state.mouse_wheel_delta = xx cast,trunc(s16)(wParam >> 16);
                }

        } // if msg ==
    return DefWindowProcW(hwnd, msg, wParam, lParam);
    //}
}


to_ws_style :: (style: Window_Style) -> u32 {
    if style == 0 return 0;
    ws_style := WS_OVERLAPPED;
    if style & .TOPBAR      then ws_style |= (WS_CAPTION | WS_SYSMENU);
    if style & .MINIMIZEBTN then ws_style |= WS_MINIMIZEBOX;
    if style & .MAXIMIZEBTN then ws_style |= WS_MAXIMIZEBOX;
    if style & .RESIZABLE   then ws_style |= WS_THICKFRAME;
    return cast(u32) ws_style;
}

// Map Windows Virtual-Key Codes to our codes
// https://docs.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
vk_to_key_code :: (wParam: WPARAM) -> Key_Code #no_context {
    // for Numbers windows use same as ours
    if (wParam >= 48) && (wParam <= 57) return cast(Key_Code) wParam;
    // A-Z windows use same as ours
    if (wParam >= 65) && (wParam <= 90) return cast(Key_Code) wParam;

    using Key_Code;

    // common keys first
    if wParam == {
        // arows
        case VK_UP;     return ARROW_UP;
        case VK_DOWN;   return ARROW_DOWN;
        case VK_LEFT;   return ARROW_LEFT;
        case VK_RIGHT;  return ARROW_RIGHT;
        // mods
        case VK_CONTROL;  return CONTROL;
        case VK_MENU;     return ALT;
        case VK_SHIFT;    return SHIFT;
        case VK_CAPITAL;  return CAPS_LOCK;
        // other
        case VK_INSERT;   return INSERT;
        case VK_HOME;     return HOME;
        case VK_END;      return END;
        case VK_NEXT;     return PAGE_UP;
        case VK_PRIOR;    return PAGE_DOWN;
        case VK_SNAPSHOT; return PRINT_SCREEN;
        case VK_PAUSE;    return PAUSE;
    }

    // Other Keys
    if wParam == {
        case VK_BACK;       return BACKSPACE;
        case VK_TAB;        return TAB;
        case VK_RETURN;     return ENTER;
        case VK_ESCAPE;     return ESCAPE;
        case VK_SPACE;      return SPACEBAR;
        case VK_OEM_7;      return APOSTROPHE; // '
        case VK_OEM_COMMA;  return COMMA;  // ,
        case VK_OEM_MINUS;  return MINUS;  // -
        case VK_OEM_PERIOD; return PERIOD; // .
        case VK_OEM_2;      return SLASH;  // /
        // numbers above ...
        case VK_OEM_1;      return SEMICOLON;  // ; 
        case VK_OEM_PLUS;   return EQUAL;      // = 
        // a-z above ...
        case VK_OEM_4;      return LEFT_BRACKET;   // [ 
        case VK_OEM_5;      return BACKSLASH;      // '\'
        case VK_OEM_6;      return RIGHT_BRACKET;  // ] 
        case VK_OEM_3;      return GRAVE_ACCENT;   // ` 
        case VK_DELETE;     return DELETE;
        // Non-ASCII table above ...
        // F1 - F12
        case VK_F1; return F1;
        case VK_F2; return F2;
        case VK_F3; return F3;
        case VK_F4; return F4;
        case VK_F5; return F5;
        case VK_F6; return F6;
        case VK_F7; return F7;
        case VK_F8; return F8;
        case VK_F9; return F9;
        case VK_F10; return F10;
        case VK_F11; return F11;
        case VK_F12; return F12;
    }

    return UNKNOWN;
}

window_class_initted := false;
class_hinstance      : HINSTANCE;
WINDOW_CLASS_NAME    :: "WINDOWS_APP_DEFAULT_CLASS_NAME";
init_window_class :: (background_color_rgb: [3] float = WINDOW_CREATION_COLOR) {
    if window_class_initted return;

    DPI.os_dpi_init();
    class_hinstance := cast(HINSTANCE) GetModuleHandleW(null);

    // Load the first icon resource (RESOURCE_ID_FIRST_ICON).
    icon := LoadIconW(class_hinstance, cast(*u16)2 );
    err := GetLastError();

    // If the icon is null, then use the first one found in the exe.
    if icon == null {
        exe_path : [MAX_PATH]u16;
        GetModuleFileNameW(null, exe_path.data, MAX_PATH);
        icon = ExtractIconW(class_hinstance, exe_path.data, 0); // 0 means first icon.
    }

    to_u8_inside_u32 :: (f: float) -> u32 {
        u := cast(s16)(f * 255);
        if u < 0    u = 0;
        if u > 255  u = 255;

        return cast(u32) u;
    }
    
    // CreateSolidBrush takes a BGR color
    r := to_u8_inside_u32(background_color_rgb[0]);
    g := to_u8_inside_u32(background_color_rgb[1]);
    b := to_u8_inside_u32(background_color_rgb[2]);
    brush := CreateSolidBrush((b << 16) | (g << 8) | r);
    
    wc: WNDCLASSEXW;
    wc.cbSize               = size_of(WNDCLASSEXW);
    wc.style                = CS_HREDRAW | CS_VREDRAW | CS_OWNDC;
    wc.lpfnWndProc          = xx window_proc;
    wc.cbClsExtra           = 0;
    wc.cbWndExtra           = 0;
    wc.hInstance            = class_hinstance;
    wc.hIcon                = icon;
    wc.hCursor              = LoadCursorW(null, IDC_ARROW);
    wc.hbrBackground        = brush;  // cast(HBRUSH) GetStockObject(WHITE_BRUSH);
    wc.lpszMenuName         = null;
    wc.lpszClassName        = utf8_to_wide(WINDOW_CLASS_NAME);

    // Register the window class
    if RegisterClassExW(*wc) == 0 {
        assert(false, "init_window_class: RegisterClassExW faild.");
    }

    window_class_initted = true;
}


/*
TODO:

Fullscreen_Cmd :: enum u16 {
    TOGGLE :: 0;
    ON     :: 1;
    OFF    :: 2;
}

Cursor :: enum u16 {
    ARROW :: 0;
    HAND  :: 1;
}

fullscreen_backup: Win32_Fullscreen_Backup;
win_cursors: struct {
    arrow: *u8;
    hand : *u8;
};

Win32_Fullscreen_Backup :: struct {
    using rect : struct {
        left  : s32;
        top   : s32;
        right : s32;
        bottom: s32;
    };
    win_style: s32;
    win_ex_style: s32;
}

_toggle_fullscreen :: (cmd: Fullscreen_Cmd = .TOGGLE) {
    if cmd == .TOGGLE {
        if window.flags & .IS_FULLSCREEN {
            cmd = .OFF;
        } else {
            cmd = .ON;
        }
    }
    if cmd == .ON {
        if window.flags & .IS_FULLSCREEN return; // already fullscreen
        // Do fullscreen on
        old_style       : s32 = GetWindowLongW(state.window, GWL_STYLE);
        old_ex_style    : s32 = GetWindowLongW(state.window, GWL_EXSTYLE);
        fullscreen_backup.win_style    = old_style;
        fullscreen_backup.win_ex_style = old_ex_style;
        fullscreen_backup.left, fullscreen_backup.top     = get_window_position();
        fullscreen_backup.right, fullscreen_backup.bottom = get_window_size(true);
        // update style
        SetWindowLongW(state.window, GWL_STYLE,   old_style    & ~cast(s32)(WS_CAPTION | WS_THICKFRAME));
        SetWindowLongW(state.window, GWL_EXSTYLE, old_ex_style & ~cast(s32)(WS_EX_DLGMODALFRAME | WS_EX_WINDOWEDGE | WS_EX_CLIENTEDGE | WS_EX_STATICEDGE));
        // update width and height
        m_width, m_height := get_display_size();
        SetWindowPos(state.window, HWND_TOPMOST, 0, 0, xx m_width, xx m_height, SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
        // app events
        window.events      |= .ENTER_FULLSCREEN;
        window.flags |= .IS_FULLSCREEN;
    } else if cmd == .OFF {
        if !(window.flags & .IS_FULLSCREEN) return; // if the window not in fullscreen mod
        backup := fullscreen_backup;
        SetWindowLongW(state.window, GWL_STYLE, backup.win_style);
        SetWindowLongW(state.window, GWL_EXSTYLE, backup.win_ex_style);
        // restore window rect
        SetWindowPos(state.window, HWND_TOP, backup.left, backup.top, (backup.right - backup.left), (backup.bottom - backup.top), SWP_FRAMECHANGED);
        // app events
        window.events      |= .EXIT_FULLSCREEN;
        window.flags &= ~.IS_FULLSCREEN;
    }
    window.events |= .RESIZED;
    state.window_width, state.window_height = get_window_size();
}

// by default windows reset the cursor to AROW
_set_cursor :: (cursor: Cursor) {
    c: *u8;
    if #complete cursor == {
        case .ARROW;
            if !win_cursors.arrow then win_cursors.arrow = LoadCursorW(xx null, cast(*u8) IDC_ARROW);
            c = win_cursors.arrow;
        case .HAND;
            if !win_cursors.hand then win_cursors.hand = LoadCursorW(xx null, cast(*u8) IDC_HAND);
            c = win_cursors.hand;
    }
    SetCursor :: (hCursor: HCURSOR) -> HCURSOR #foreign user32;
    SetCursor(c);
}

*/