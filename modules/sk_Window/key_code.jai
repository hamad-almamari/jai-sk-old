// Based on ASCII table 
Key_Code :: enum u16 {
    UNKNOWN     :: 0;
    BACKSPACE   :: 8;
    TAB         :: 9;
    ENTER       :: 13;
    ESCAPE      :: 27;
    SPACEBAR    :: 32;
    APOSTROPHE  :: 39;  // ' 
    COMMA       :: 44;  // , 
    MINUS       :: 45;  // - 
    PERIOD      :: 46;  // . 
    SLASH       :: 47;  // /

    NUM_0       :: 48;
    NUM_1       :: 49;
    NUM_2       :: 50;
    NUM_3       :: 51;
    NUM_4       :: 52;
    NUM_5       :: 53;
    NUM_6       :: 54;
    NUM_7       :: 55;
    NUM_8       :: 56;
    NUM_9       :: 57;

    SEMICOLON   :: 59;  // ; 
    EQUAL       :: 61;  // = 

    A       :: 65;
    B       :: 66;
    C       :: 67;
    D       :: 68;
    E       :: 69;
    F       :: 70;
    G       :: 71;
    H       :: 72;
    I       :: 73;
    J       :: 74;
    K       :: 75;
    L       :: 76;
    M       :: 77;
    N       :: 78;
    O       :: 79; 
    P       :: 80;
    Q       :: 81;
    R       :: 82;
    S       :: 83;
    T       :: 84;
    U       :: 85;
    V       :: 86;
    W       :: 87;
    X       :: 88;
    Y       :: 89;
    Z       :: 90;

    LEFT_BRACKET :: 91;  // [ 
    BACKSLASH    :: 92;  // \'
    RIGHT_BRACKET:: 93;  // ] 
    GRAVE_ACCENT :: 96;  // ` 

    DELETE       :: 127;

    // Non-ASCII table
    // arrows
    ARROW_UP     :: 128;
    ARROW_DOWN   :: 129;
    ARROW_LEFT   :: 130;
    ARROW_RIGHT  :: 131;
    // mods
    CONTROL      :: 132;
    ALT          :: 133;
    SHIFT        :: 134;
    CAPS_LOCK    :: 135;
    // other
    INSERT       :: 136;
    HOME         :: 137;
    END          :: 138;
    PAGE_UP      :: 139;
    PAGE_DOWN    :: 140;
    PRINT_SCREEN :: 141;
    PAUSE        :: 142;
    // F1 to F12
    F1           :: 145;         
    F2           :: 146;
    F3           :: 147;
    F4           :: 148;
    F5           :: 149;
    F6           :: 150;
    F7           :: 151;
    F8           :: 152;
    F9           :: 153;
    F10          :: 154;
    F11          :: 155;
    F12          :: 156;

    // Not ASCII (other)
    MOUSE_LEFT;
    MOUSE_MIDDLE;
    MOUSE_RIGHT;
}