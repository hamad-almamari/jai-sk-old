[1mdiff --git a/modules/sk_Bitset/Bitset.jai b/modules/sk_Bitset/Bitset.jai[m
[1mnew file mode 100644[m
[1mindex 0000000..5124e5d[m
[1m--- /dev/null[m
[1m+++ b/modules/sk_Bitset/Bitset.jai[m
[36m@@ -0,0 +1,73 @@[m
[32m+[m[32m// Static Bit Set[m
[32m+[m[32m//[m
[32m+[m[32m// NOTE: Some of this Code taken from "Bit_Array" module.[m
[32m+[m[32m/*[m
[32m+[m[32mUsage:[m
[32m+[m
[32m+[m[32mBitset        :: #import "fw_Bitset";[m
[32m+[m[32moperator []   :: Bitset.get;[m
[32m+[m[32mfor_expansion :: Bitset.for_expansion;[m
[32m+[m[32m*/[m
[32m+[m
[32m+[m[32mBitset :: struct (count: int) {[m
[32m+[m[32m    TYPE :: #this;[m
[32m+[m[32m    N    :: (count + 63) >> 6;[m
[32m+[m[32m    buffer: [N] int;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mset :: (using bitset: *Bitset, i: int) {[m
[32m+[m[32m    assert(i < count);[m
[32m+[m[32m    buffer[i >> 6] |= (1 << (i & 63));[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mclear :: (using bitset: *Bitset, i: int) {[m
[32m+[m[32m    assert(i < count);[m
[32m+[m[32m    buffer[i >> 6] &= ~(1 << (i & 63));[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mtoggle :: (using bitset: *Bitset, i: int) {[m
[32m+[m[32m    assert(i < count);[m
[32m+[m[32m    buffer[i >> 6] ^= (1 << (i & 63));[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mget :: (using bitset: Bitset, i: int) -> bool {[m
[32m+[m[32m    assert(i < count);[m
[32m+[m[32m    return cast(bool) (buffer[i >> 6] & (1 << (i & 63)));[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m// for now you can do this since this module not written to be imported to global scope.[m
[32m+[m[32m// Bitset :: #import "fw_Bitset";[m
[32m+[m[32m// operator [] :: Bitset.get;[m
[32m+[m[32m/*[m
[32m+[m[32moperator [] :: (using bitset: Bitset, i: int) -> bool {[m
[32m+[m[32m    assert(i < count);[m
[32m+[m[32m    return cast(bool) (buffer[i >> 6] & (1 << (i & 63)));[m
[32m+[m[32m}[m
[32m+[m[32m*/[m
[32m+[m
[32m+[m[32mset_all :: (using bitset: *Bitset) {[m
[32m+[m[32m    memset(buffer.data, 0xFF, N * size_of(int));[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mclear_all :: (using bitset: *Bitset) {[m
[32m+[m[32m    memset(buffer.data, 0, N * size_of(int));[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mtoggle_all :: (using bitset: *Bitset) {[m
[32m+[m[32m    for * buffer { <<it ^= 0xFFFFFFFF_FFFFFFFF; }[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m// for now you can do this since this module not written to be imported to global scope.[m
[32m+[m[32m// Bitset :: #import "fw_Bitset";[m
[32m+[m[32m// for_expansion :: for_expansion;[m
[32m+[m[32mfor_expansion :: (bitset: *$T/Bitset, body: Code, flags: For_Flags) #expand {[m
[32m+[m[32m    #assert(!(flags & .POINTER));[m
[32m+[m[32m    DO_REVERSE :: cast(bool) (flags & .REVERSE);[m
[32m+[m[32m    for <=DO_REVERSE `it_index: 0..bitset.count-1 {[m
[32m+[m[32m        `it := inline get(<<bitset, it_index);[m
[32m+[m[32m        #insert (remove=#assert(false)) body;[m
[32m+[m[32m    }[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m#scope_file[m
[32m+[m[32m#import "Basic";[m
\ No newline at end of file[m
[1mdiff --git a/modules/sk_Bitset/examples/.build/.added_strings_w1.jai b/modules/sk_Bitset/examples/.build/.added_strings_w1.jai[m
[1mnew file mode 100644[m
[1mindex 0000000..4f00698[m
[1m--- /dev/null[m
[1m+++ b/modules/sk_Bitset/examples/.build/.added_strings_w1.jai[m
[36m@@ -0,0 +1,2 @@[m
[32m+[m[32m// Workspace: First Workspace[m
[32m+[m[32m#import "Default_Metaprogram";[m
[1mdiff --git a/modules/sk_Bitset/examples/.build/01_example.exp b/modules/sk_Bitset/examples/.build/01_example.exp[m
[1mnew file mode 100644[m
[1mindex 0000000..5ba809a[m
Binary files /dev/null and b/modules/sk_Bitset/examples/.build/01_example.exp differ
[1mdiff --git a/modules/sk_Bitset/examples/.build/01_example.lib b/modules/sk_Bitset/examples/.build/01_example.lib[m
[1mnew file mode 100644[m
[1mindex 0000000..6c82528[m
Binary files /dev/null and b/modules/sk_Bitset/examples/.build/01_example.lib differ
[1mdiff --git a/modules/sk_Bitset/examples/.build/01_overview.exp b/modules/sk_Bitset/examples/.build/01_overview.exp[m
[1mnew file mode 100644[m
[1mindex 0000000..6d7d9f4[m
Binary files /dev/null and b/modules/sk_Bitset/examples/.build/01_overview.exp differ
[1mdiff --git a/modules/sk_Bitset/examples/.build/01_overview.lib b/modules/sk_Bitset/examples/.build/01_overview.lib[m
[1mnew file mode 100644[m
[1mindex 0000000..65c40be[m
Binary files /dev/null and b/modules/sk_Bitset/examples/.build/01_overview.lib differ
[1mdiff --git a/modules/sk_Bitset/examples/01_overview.jai b/modules/sk_Bitset/examples/01_overview.jai[m
[1mnew file mode 100644[m
[1mindex 0000000..696445f[m
[1m--- /dev/null[m
[1m+++ b/modules/sk_Bitset/examples/01_overview.jai[m
[36m@@ -0,0 +1,59 @@[m
[32m+[m[32m// Static Bit set example[m
[32m+[m
[32m+[m[32m#import "Basic";[m
[32m+[m[32mBitset :: #import "sk_Bitset";[m
[32m+[m[32m// for now you can do this since Bitset module not written to be imported to global scope.[m
[32m+[m[32moperator []   :: Bitset.get;[m
[32m+[m[32mfor_expansion :: Bitset.for_expansion;[m
[32m+[m
[32m+[m[32mmain :: () {[m
[32m+[m[32m    bits: Bitset.Bitset(10);[m
[32m+[m
[32m+[m[32m    for 0..bits.count-1 {[m
[32m+[m[32m        print("index: %, value: % \n",  it, Bitset.get(bits, it) );[m
[32m+[m[32m    }[m
[32m+[m
[32m+[m[32m    print("---------set--------\n");[m
[32m+[m
[32m+[m[32m    for 0..bits.count-1 {[m
[32m+[m[32m        Bitset.set(*bits, it);[m
[32m+[m[32m        print("index: %, value: % \n",  it, bits[it] ); // you can use operator [][m
[32m+[m[32m    }[m
[32m+[m
[32m+[m[32m    print("---------clear--------\n");[m
[32m+[m
[32m+[m[32m    for bits {[m
[32m+[m[32m        Bitset.clear(*bits, it_index);[m
[32m+[m[32m        print("index: %, value: % \n",  it_index, it ); // Bitset also has it's own for expansion[m
[32m+[m[32m    }[m
[32m+[m
[32m+[m[32m    print("---------toggle--------\n");[m
[32m+[m
[32m+[m[32m    for 0..bits.count-1 {[m
[32m+[m[32m        Bitset.toggle(*bits, it);[m
[32m+[m[32m        print("index: %, value: % \n",  it, Bitset.get(bits, it) );[m
[32m+[m[32m    }[m
[32m+[m
[32m+[m[32m    print("---------clear_all--------\n");[m
[32m+[m[32m    Bitset.clear_all(*bits);[m
[32m+[m[32m    for 0..bits.count-1 {[m
[32m+[m[32m        print("index: %, value: % \n",  it, Bitset.get(bits, it) );[m
[32m+[m[32m    }[m
[32m+[m
[32m+[m[32m    print("---------set_all (but not 5)--------\n");[m
[32m+[m[32m    Bitset.set_all(*bits);[m
[32m+[m[32m    Bitset.clear(*bits, 5);[m
[32m+[m[32m    for 0..bits.count-1 {[m
[32m+[m[32m        print("index: %, value: % \n",  it, Bitset.get(bits, it) );[m
[32m+[m[32m    }[m
[32m+[m
[32m+[m[32m    print("---------toggle_all--------\n");[m
[32m+[m[32m    Bitset.toggle_all(*bits);[m
[32m+[m[32m    for 0..bits.count-1 {[m
[32m+[m[32m        print("index: %, value: % \n",  it, Bitset.get(bits, it) );[m
[32m+[m[32m    }[m
[32m+[m
[32m+[m[32m    print("---------Bitset.get using [] operator --------\n");[m
[32m+[m[32m    print("bit 5 = %\n", bits[5] );[m
[32m+[m[32m    print("bit 6 = %\n", bits[6] );[m[41m     [m
[32m+[m[32m}[m
\ No newline at end of file[m
[1mdiff --git a/modules/sk_Bitset/module.jai b/modules/sk_Bitset/module.jai[m
[1mnew file mode 100644[m
[1mindex 0000000..f0e15f8[m
[1m--- /dev/null[m
[1m+++ b/modules/sk_Bitset/module.jai[m
[36m@@ -0,0 +1 @@[m
[32m+[m[32m#load "./Bitset.jai";[m
\ No newline at end of file[m
[1mdiff --git a/modules/sk_Window/App.jai b/modules/sk_Window/App.jai[m
[1mnew file mode 100644[m
[1mindex 0000000..8267aac[m
[1m--- /dev/null[m
[1m+++ b/modules/sk_Window/App.jai[m
[36m@@ -0,0 +1,136 @@[m
[32m+[m[32m#module_parameters () ([m
[32m+[m[32m    WINDOW_CREATION_COLOR := float.[.2,.2,.2],[m
[32m+[m[32m    WINDOW_USER_DATA_T    : Type = void[m
[32m+[m[32m);[m
[32m+[m
[32m+[m[32mNUMBER_OF_INPUT_KEY_CODES :: #run enum_highest_value(Key_Code) + 1;[m
[32m+[m
[32m+[m[32mWindow :: struct {[m
[32m+[m[32m    name  : string;[m
[32m+[m[32m    valid : bool;[m
[32m+[m[32m    parent: *Window;[m
[32m+[m[32m    events: Events;[m
[32m+[m[32m    flags : Flags;[m
[32m+[m[32m    creation_thread_index: u32;[m
[32m+[m[32m    frame_index: u64;[m
[32m+[m
[32m+[m[32m    // input[m
[32m+[m[32m    input_events        : Input_Events;[m
[32m+[m[32m    keys_state          : Bitset.Bitset(NUMBER_OF_INPUT_KEY_CODES);[m
[32m+[m[32m    keys_state_lastframe: Bitset.Bitset(NUMBER_OF_INPUT_KEY_CODES);[m
[32m+[m[41m [m
[32m+[m[32m    #if WINDOW_USER_DATA_T != void {[m
[32m+[m[32m        userdata: WINDOW_USER_DATA_T;[m
[32m+[m[32m    }[m
[32m+[m
[32m+[m[32m    #if OS == .WINDOWS {[m
[32m+[m[32m        hinstance: HINSTANCE;[m
[32m+[m[32m        hwnd: HWND;[m
[32m+[m[32m    }[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mWindow_Style :: enum_flags u32 {[m
[32m+[m[32m    TOPBAR       :: 1;[m
[32m+[m[32m    MINIMIZEBTN  :: 2;[m
[32m+[m[32m    MAXIMIZEBTN  :: 4;[m
[32m+[m[32m    RESIZABLE    :: 8;[m
[32m+[m[32m    PRIMARY      :: TOPBAR | MINIMIZEBTN | MAXIMIZEBTN | RESIZABLE;[m
[32m+[m[32m    SECONDARY    :: TOPBAR | RESIZABLE;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mEvents :: enum_flags u32 {[m
[32m+[m[32m    NONE               :: 0;[m
[32m+[m[32m    JUST_INITIALIZED   :: 1;[m
[32m+[m[32m    QUIT_REQUEST       :: 1 << 2;[m
[32m+[m[32m    GAINFOUCS          :: 1 << 3;[m
[32m+[m[32m    LOSTFOUCS          :: 1 << 4;[m
[32m+[m[32m    MINIMIZED          :: 1 << 5;[m
[32m+[m[32m    DEMINIMIZED        :: 1 << 6;[m
[32m+[m[32m    MAXIMIZED          :: 1 << 7;[m
[32m+[m[32m    DEMAXIMIZED        :: 1 << 8;[m
[32m+[m[32m    ENTER_FULLSCREEN   :: 1 << 9;[m
[32m+[m[32m    EXIT_FULLSCREEN    :: 1 << 10;[m
[32m+[m[32m    RESIZED            :: 1 << 11;[m
[32m+[m[32m    MOVED              :: 1 << 12;[m
[32m+[m[32m    // mouse enter?[m
[32m+[m[32m    // mouse leave?[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mFlags :: enum_flags u32 {[m
[32m+[m[32m    NONE          :: 0;[m
[32m+[m[32m    HAS_FOUCS     :: 1;[m
[32m+[m[32m    IS_MINIMIZED  :: 2;[m
[32m+[m[32m    IS_MAXIMIZED  :: 4;[m
[32m+[m[32m    IS_FULLSCREEN :: 8;[m
[32m+[m[32m    // mouseover?[m[41m  [m
[32m+[m[32m}[m
[32m+[m
[32m+[m
[32m+[m[32mInput_State :: struct {[m
[32m+[m[32m    events              : Input_Events;[m
[32m+[m[32m    keys_state          : Bitset.Bitset(NUMBER_OF_INPUT_KEY_CODES);[m
[32m+[m[32m    keys_state_lastframe: Bitset.Bitset(NUMBER_OF_INPUT_KEY_CODES);[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mInput_Events :: enum_flags u32 {[m
[32m+[m[32m    NONE               :: 0;[m
[32m+[m[32m    MOUSE_WHEEL_SCROLL :: 1;[m
[32m+[m[32m    // Key is Down?[m
[32m+[m[32m    // on off key active? CAPS[m
[32m+[m[32m    // mouseclick?[m[41m  [m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mKey_State :: enum u16 {[m
[32m+[m[32m    UP       :: 0;[m
[32m+[m[32m    DOWN     :: 1;[m
[32m+[m[32m    PRESSED  :: 2;[m
[32m+[m[32m    RELEASED :: 3;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mCursor :: enum u16 {[m
[32m+[m[32m    ARROW :: 0;[m
[32m+[m[32m    HAND  :: 1;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m#load "key_code.jai";[m
[32m+[m[32m#if OS == .WINDOWS {[m
[32m+[m[32m    #load "windows.jai";[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mignore_quit_request :: (using window:*Window) #expand {[m
[32m+[m[32m    events &= ~.QUIT_REQUEST;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mis_key :: inline (using window:*Window, key: Key_Code, key_state: Key_State) -> bool {[m
[32m+[m[32m    i := cast(int) key;[m
[32m+[m[32m    if #complete key_state == {[m[41m [m
[32m+[m[32m        case .PRESSED;  return  keys_state[i] && !keys_state_lastframe[i];[m
[32m+[m[32m        case .RELEASED; return !keys_state[i] &&  keys_state_lastframe[i];[m
[32m+[m[32m        case .DOWN;     return  keys_state[i];[m
[32m+[m[32m        case .UP;       return !keys_state[i];[m
[32m+[m[32m    }[m
[32m+[m[32m    return false;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mget_key_state :: inline (using window:*Window, key: Key_Code) -> Key_State {[m[41m [m
[32m+[m[32m    // NOTE: if the key is .PRESSED that means it is .DOWN also[m
[32m+[m[32m    //       and if it .RELEASED it is .UP also[m
[32m+[m[32m    i := cast(int) key;[m
[32m+[m[32m    if  keys_state[i] && !keys_state_lastframe[i] return .PRESSED;[m
[32m+[m[32m    if !keys_state[i] &&  keys_state_lastframe[i] return .RELEASED;[m
[32m+[m[32m    if  keys_state[i] return .DOWN;[m
[32m+[m[32m    return .UP;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mis_this_mouse_key :: inline (key: Key_Code) -> bool #expand {[m
[32m+[m[32m    return key == .MOUSE_LEFT || key == .MOUSE_MIDDLE || key == .MOUSE_RIGHT;[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mis_this_keyboard_key :: inline (key: Key_Code) -> bool #expand {[m
[32m+[m[32m    return !is_this_mouse_key(key);[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32m#scope_module[m
[32m+[m[32mwindow_list : [..] *Window;[m
[32m+[m[32mBitset      :: #import "sk_Bitset";[m
[32m+[m[32moperator [] :: Bitset.get;[m
\ No newline at end of file[m
[1mdiff --git a/modules/sk_Window/examples/.build/01_minimal.exp b/modules/sk_Window/examples/.build/01_minimal.exp[m
[1mnew file mode 100644[m
[1mindex 0000000..fe7dd34[m
Binary files /dev/null and b/modules/sk_Window/examples/.build/01_minimal.exp differ
[1mdiff --git a/modules/sk_Window/examples/.build/01_minimal.lib b/modules/sk_Window/examples/.build/01_minimal.lib[m
[1mnew file mode 100644[m
[1mindex 0000000..76b6489[m
Binary files /dev/null and b/modules/sk_Window/examples/.build/01_minimal.lib differ
[1mdiff --git a/modules/sk_Window/examples/.build/02_d3d12.exp b/modules/sk_Window/examples/.build/02_d3d12.exp[m
[1mnew file mode 100644[m
[1mindex 0000000..f134972[m
Binary files /dev/null and b/modules/sk_Window/examples/.build/02_d3d12.exp differ
[1mdiff --git a/modules/sk_Window/examples/.build/02_d3d12.lib b/modules/sk_Window/examples/.build/02_d3d12.lib[m
[1mnew file mode 100644[m
[1mindex 0000000..ac96797[m
Binary files /dev/null and b/modules/sk_Window/examples/.build/02_d3d12.lib differ
[1mdiff --git a/modules/sk_Window/examples/.build/02_d3d12c.exp b/modules/sk_Window/examples/.build/02_d3d12c.exp[m
[1mnew file mode 100644[m
[1mindex 0000000..8861b51[m
Binary files /dev/null and b/modules/sk_Window/examples/.build/02_d3d12c.exp differ
[1mdiff --git a/modules/sk_Window/examples/.build/02_d3d12c.lib b/modules/sk_Window/examples/.build/02_d3d12c.lib[m
[1mnew file mode 100644[m
[1mindex 0000000..c057b00[m
Binary files /dev/null and b/modules/sk_Window/examples/.build/02_d3d12c.lib differ
[1mdiff --git a/modules/sk_Window/examples/.build/02_overview.exp b/modules/sk_Window/examples/.build/02_overview.exp[m
[1mnew file mode 100644[m
[1mindex 0000000..e513956[m
Binary files /dev/null and b/modules/sk_Window/examples/.build/02_overview.exp differ
[1mdiff --git a/modules/sk_Window/examples/.build/02_overview.lib b/modules/sk_Window/examples/.build/02_overview.lib[m
[1mnew file mode 100644[m
[1mindex 0000000..03ddfb4[m
Binary files /dev/null and b/modules/sk_Window/examples/.build/02_overview.lib differ
[1mdiff --git a/modules/sk_Window/examples/.build/03_multiwindows.exp b/modules/sk_Window/examples/.build/03_multiwindows.exp[m
[1mnew file mode 100644[m
[1mindex 0000000..66b944e[m
Binary files /dev/null and b/modules/sk_Window/examples/.build/03_multiwindows.exp differ
[1mdiff --git a/modules/sk_Window/examples/.build/03_multiwindows.lib b/modules/sk_Window/examples/.build/03_multiwindows.lib[m
[1mnew file mode 100644[m
[1mindex 0000000..aabe17e[m
Binary files /dev/null and b/modules/sk_Window/examples/.build/03_multiwindows.lib differ
[1mdiff --git a/modules/sk_Window/examples/.build/10_vulkan.exp b/modules/sk_Window/examples/.build/10_vulkan.exp[m
[1mnew file mode 100644[m
[1mindex 0000000..d41005b[m
Binary files /dev/null and b/modules/sk_Window/examples/.build/10_vulkan.exp differ
[1mdiff --git a/modules/sk_Window/examples/.build/10_vulkan.lib b/modules/sk_Window/examples/.build/10_vulkan.lib[m
[1mnew file mode 100644[m
[1mindex 0000000..54a6ea5[m
Binary files /dev/null and b/modules/sk_Window/examples/.build/10_vulkan.lib differ
[1mdiff --git a/modules/sk_Window/examples/.build/example.exp b/modules/sk_Window/examples/.build/example.exp[m
[1mnew file mode 100644[m
[1mindex 0000000..cf5eafb[m
Binary files /dev/null and b/modules/sk_Window/examples/.build/example.exp differ
[1mdiff --git a/modules/sk_Window/examples/.build/example.lib b/modules/sk_Window/examples/.build/example.lib[m
[1mnew file mode 100644[m
[1mindex 0000000..1b6fe35[m
Binary files /dev/null and b/modules/sk_Window/examples/.build/example.lib differ
[1mdiff --git a/modules/sk_Window/examples/.build/test.exp b/modules/sk_Window/examples/.build/test.exp[m
[1mnew file mode 100644[m
[1mindex 0000000..f343a0f[m
Binary files /dev/null and b/modules/sk_Window/examples/.build/test.exp differ
[1mdiff --git a/modules/sk_Window/examples/.build/test.lib b/modules/sk_Window/examples/.build/test.lib[m
[1mnew file mode 100644[m
[1mindex 0000000..bfb08c2[m
Binary files /dev/null and b/modules/sk_Window/examples/.build/test.lib differ
[1mdiff --git a/modules/sk_Window/examples/01_minimal.jai b/modules/sk_Window/examples/01_minimal.jai[m
[1mnew file mode 100644[m
[1mindex 0000000..14a7ea9[m
[1m--- /dev/null[m
[1m+++ b/modules/sk_Window/examples/01_minimal.jai[m
[36m@@ -0,0 +1,18 @@[m
[32m+[m[32m#import "Basic";[m
[32m+[m[32mWindow :: #import "sk_Window";[m
[32m+[m
[32m+[m[32mmain :: () {[m
[32m+[m[32m    window := Window.create(800, 500, "Hello Sailor");[m
[32m+[m[32m    defer {[m
[32m+[m[32m        Window.destroy(window);[m
[32m+[m[32m        window = null; // never use the window pointer after you destroy it.[m
[32m+[m[32m    }[m
[32m+[m
[32m+[m[32m    while true {[m[41m [m
[32m+[m[32m        Window.process_events(window);[m
[32m+[m[32m        // keep this here, if we do while window.valid {..} we will have an extra frame where the window is invalid.[m
[32m+[m[32m        if !window.valid break;[m
[32m+[m
[32m+[m[32m        //...[m
[32m+[m[32m    }[m
[32m+[m[32m}[m
\ No newline at end of file[m
[1mdiff --git a/modules/sk_Window/examples/02_overview.jai b/modules/sk_Window/examples/02_overview.jai[m
[1mnew file mode 100644[m
[1mindex 0000000..df96af4[m
[1m--- /dev/null[m
[1m+++ b/modules/sk_Window/examples/02_overview.jai[m
[36m@@ -0,0 +1,65 @@[m
[32m+[m[32m#import "Basic";[m
[32m+[m[32mWindow :: #import "sk_Window";[m
[32m+[m
[32m+[m[32mmain :: () {[m
[32m+[m[32m    window := Window.create(800, 500, "Hello Sailor");[m
[32m+[m[32m    defer {[m
[32m+[m[32m        Window.destroy(window);[m
[32m+[m[32m        window = null; // never use the window pointer after you destroy it.[m
[32m+[m[32m    }[m
[32m+[m
[32m+[m[32m    print(#string DONE[m
[32m+[m[32m    Hello Sailor:[m
[32m+[m[32m        ESCAPE - Quit/close.[m
[32m+[m[32m        M      - Maximize.[m
[32m+[m[32m        N      - Minimize.[m
[32m+[m[32m        R      - Restore.[m
[32m+[m[32m    DONE);[m
[32m+[m
[32m+[m[32m    while true {[m
[32m+[m[32m        // process/update window events.[m
[32m+[m[32m        Window.process_events(window);[m
[32m+[m[32m        if !window.valid break;[m
[32m+[m
[32m+[m[32m        // if "ESCAPE" key pressed quit/close the window next frame.[m
[32m+[m[32m        if Window.is_key(window, .ESCAPE, .PRESSED) then Window.quit(window);[m
[32m+[m
[32m+[m[32m        // close & quit request.[m
[32m+[m[32m        if window.events & .QUIT_REQUEST {[m
[32m+[m[32m            print("%