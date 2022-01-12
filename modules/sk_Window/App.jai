#module_parameters () (
    WINDOW_CREATION_COLOR := float.[.2,.2,.2],
    WINDOW_USER_DATA_T    : Type = void
);

NUMBER_OF_INPUT_KEY_CODES :: #run enum_highest_value(Key_Code) + 1;

Window :: struct {
    name  : string;
    valid : bool;
    parent: *Window;
    events: Events;
    flags : Flags;
    creation_thread_index: u32;
    frame_index: u64;

    // input
    input_events        : Input_Events;
    keys_state          : Bitset.Bitset(NUMBER_OF_INPUT_KEY_CODES);
    keys_state_lastframe: Bitset.Bitset(NUMBER_OF_INPUT_KEY_CODES);
 
    #if WINDOW_USER_DATA_T != void {
        userdata: WINDOW_USER_DATA_T;
    }

    #if OS == .WINDOWS {
        hinstance: HINSTANCE;
        hwnd: HWND;
    }
}

Window_Style :: enum_flags u32 {
    TOPBAR       :: 1;
    MINIMIZEBTN  :: 2;
    MAXIMIZEBTN  :: 4;
    RESIZABLE    :: 8;
    PRIMARY      :: TOPBAR | MINIMIZEBTN | MAXIMIZEBTN | RESIZABLE;
    SECONDARY    :: TOPBAR | RESIZABLE;
}

Events :: enum_flags u32 {
    NONE               :: 0;
    JUST_INITIALIZED   :: 1;
    QUIT_REQUEST       :: 1 << 2;
    GAINFOUCS          :: 1 << 3;
    LOSTFOUCS          :: 1 << 4;
    MINIMIZED          :: 1 << 5;
    DEMINIMIZED        :: 1 << 6;
    MAXIMIZED          :: 1 << 7;
    DEMAXIMIZED        :: 1 << 8;
    ENTER_FULLSCREEN   :: 1 << 9;
    EXIT_FULLSCREEN    :: 1 << 10;
    RESIZED            :: 1 << 11;
    MOVED              :: 1 << 12;
    // mouse enter?
    // mouse leave?
}

Flags :: enum_flags u32 {
    NONE          :: 0;
    HAS_FOUCS     :: 1;
    IS_MINIMIZED  :: 2;
    IS_MAXIMIZED  :: 4;
    IS_FULLSCREEN :: 8;
    // mouseover?  
}


Input_State :: struct {
    events              : Input_Events;
    keys_state          : Bitset.Bitset(NUMBER_OF_INPUT_KEY_CODES);
    keys_state_lastframe: Bitset.Bitset(NUMBER_OF_INPUT_KEY_CODES);
}

Input_Events :: enum_flags u32 {
    NONE               :: 0;
    MOUSE_WHEEL_SCROLL :: 1;
    // Key is Down?
    // on off key active? CAPS
    // mouseclick?  
}

Key_State :: enum u16 {
    UP       :: 0;
    DOWN     :: 1;
    PRESSED  :: 2;
    RELEASED :: 3;
}

Cursor :: enum u16 {
    ARROW :: 0;
    HAND  :: 1;
}

#load "key_code.jai";
#if OS == .WINDOWS {
    #load "windows.jai";
}

ignore_quit_request :: (using window:*Window) #expand {
    events &= ~.QUIT_REQUEST;
}

is_key :: inline (using window:*Window, key: Key_Code, key_state: Key_State) -> bool {
    i := cast(int) key;
    if #complete key_state == { 
        case .PRESSED;  return  keys_state[i] && !keys_state_lastframe[i];
        case .RELEASED; return !keys_state[i] &&  keys_state_lastframe[i];
        case .DOWN;     return  keys_state[i];
        case .UP;       return !keys_state[i];
    }
    return false;
}

get_key_state :: inline (using window:*Window, key: Key_Code) -> Key_State { 
    // NOTE: if the key is .PRESSED that means it is .DOWN also
    //       and if it .RELEASED it is .UP also
    i := cast(int) key;
    if  keys_state[i] && !keys_state_lastframe[i] return .PRESSED;
    if !keys_state[i] &&  keys_state_lastframe[i] return .RELEASED;
    if  keys_state[i] return .DOWN;
    return .UP;
}

is_this_mouse_key :: inline (key: Key_Code) -> bool #expand {
    return key == .MOUSE_LEFT || key == .MOUSE_MIDDLE || key == .MOUSE_RIGHT;
}

is_this_keyboard_key :: inline (key: Key_Code) -> bool #expand {
    return !is_this_mouse_key(key);
}

#scope_module
window_list : [..] *Window;
Bitset      :: #import "sk_Bitset";
operator [] :: Bitset.get;