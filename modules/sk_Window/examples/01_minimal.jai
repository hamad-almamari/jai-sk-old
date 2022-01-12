#import "Basic";
Window :: #import "sk_Window";

main :: () {
    window := Window.create(800, 500, "Hello Sailor");
    defer {
        Window.destroy(window);
        window = null; // never use the window pointer after you destroy it.
    }

    while true { 
        Window.process_events(window);
        // keep this here, if we do while window.valid {..} we will have an extra frame where the window is invalid.
        if !window.valid break;

        //...
    }
}