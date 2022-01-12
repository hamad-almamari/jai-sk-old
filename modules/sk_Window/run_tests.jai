Compiler :: #import "Compiler";
#import "Basic"()(MEMORY_DEBUGGER=true, ENABLE_ASSERT=true);
Window :: #import "sk_Window";

WIDTH  :: 400;
HEIGHT :: 200;

#run {
    // The goal of this program is to run test code for this module;
    // none of the code in this file is intended to end up in an executable
    // So, we tell the compiler not to make an executable for us:
    options : Compiler.Build_Options_During_Compile;
    options.do_output = false;
    Compiler.set_build_options_dc(options);
    // TESTS
    test_commands();
    // MEM LEAKS
    report_memory_leaks();
}

test_commands :: () {
    window := Window.create(WIDTH, HEIGHT, "Main App");
    defer Window.destroy(window);

    { // TEST: after creation flags
        check := Window.Events.JUST_INITIALIZED | .GAINFOUCS | .RESIZED | .MOVED;
        //debug_print(window);
        assert(window.events & check != 0);
        assert(window.flags  & .HAS_FOUCS != 0);
    }

    while true {
        // process/update window events.
        Window.process_events(window);
        if !window.valid break;

        assert(window.frame_index == 0); // we only need to run one frame for testing.

        { // TEST: .JUST_INITIALIZED must be removed after first process_events call
            assert(window.events & .JUST_INITIALIZED == 0);
        }

        { // TEST: window width and height
            w, h := Window.get_size(window);
            assert(w == WIDTH && h == HEIGHT);
        }

        { // TEST: window maximize command
            Window.maximize(window);
            //debug_print(window);
            assert(window.events & .MAXIMIZED && window.flags & .IS_MAXIMIZED);
        }

        { // TEST: window restore command
            Window.restore(window);
            //debug_print(window);
            assert(window.events & .DEMAXIMIZED && !(window.flags & .IS_MAXIMIZED));
            // last .MAXIMIZED event must be removed
            assert(!(window.events & .MAXIMIZED));
        }

        { // TEST: window minimize command
            Window.minimize(window);
            //debug_print(window);
            assert(window.events & .MINIMIZED && window.flags & .IS_MINIMIZED);
        }

        { // TEST: window restore command
            Window.restore(window);
            //debug_print(window);
            assert(window.events & .DEMINIMIZED && !(window.flags & .IS_MINIMIZED));
            // last .MAXIMIZED event must be removed
            assert(!(window.events & .MINIMIZED));
        }

        { // TEST: window quit command (the window will became invalid next frame)
            Window.quit(window);
            assert(window.events & .QUIT_REQUEST != 0);
            assert(window.valid); // not yet, the window shall be valid.
        }
    }
}

debug_print :: (window: *Window.Window) {
    print("frame:%, window.events: %, window.flags: %\n", window.frame_index, window.events, window.flags);
}