#import "Basic";
Window :: #import "sk_Window";

main :: () {
    window := Window.create(800, 500, "Hello Sailor");
    defer {
        Window.destroy(window);
        window = null; // never use the window pointer after you destroy it.
    }

    print(#string DONE
    Hello Sailor:
        ESCAPE - Quit/close.
        M      - Maximize.
        N      - Minimize.
        R      - Restore.
    DONE);

    while true {
        // process/update window events.
        Window.process_events(window);
        if !window.valid break;

        // if "ESCAPE" key pressed quit/close the window next frame.
        if Window.is_key(window, .ESCAPE, .PRESSED) then Window.quit(window);

        // close & quit request.
        if window.events & .QUIT_REQUEST {
            print("%:This the last frame. \n", window.frame_index);
            // Here you can do things before quit or even ignore the request.
            // Window.ignore_quit_request(window); // you can cancel the quit request.
            // do not break here this event intended to notify the user that the window
            // will quit next frame (naxt "process_events" call).
        }

        // other commands.
        if Window.is_key(window, .N, .PRESSED) then Window.minimize(window);
        if Window.is_key(window, .M, .PRESSED) then Window.maximize(window);
        if Window.is_key(window, .R, .PRESSED) then Window.restore(window);

        // print window frame events
        if window.events {
            ww, wh := Window.get_size(window);
            dw, dh := Window.get_display_size(window);
            print("%:window size: %x%, display size: %x%\n", window.frame_index, ww, wh, dw, dh);
            print("%:window.events: %\n", window.frame_index, window.events); // window.events -> did window xxxx?
            print("%:window.flags : %\n", window.frame_index, window.flags);  // window.flags  -> is window xxxx?
        }

        // print msg if the main window MINIMIZED.
        if window.events & .MINIMIZED   print("%:THE GAME WINDOW IS MINIMIZED WE WILL NOT DRAW OR UPDATE.\n", window.frame_index);
        // print msg if the main window DEMINIMIZED.
        if window.events & .DEMINIMIZED print("%:YAY THE GAME WINDOW IS DEMINIMIZED WE WILL DRAW AND UPDATE NOW.\n", window.frame_index);
    
        // do not update/draw the game if the main window is MINIMIZED.
        if window.flags  & .IS_MINIMIZED continue;

        // draw and update...

        if Window.is_key(window, .MOUSE_LEFT, .PRESSED) {
            x, y := Window.get_mouse_position(window);
            print("%: MOUSE_LEFT:PRESSED at %,%\n", window.frame_index, x, y);
        }
    }
}