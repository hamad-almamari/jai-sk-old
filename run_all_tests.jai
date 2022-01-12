/* 

  Simple Tests

*/

TESTS :: string.[
  "modules/sk_Bitset/examples/01_overview.jai",

  "modules/sk_Window/examples/01_minimal.jai",
  "modules/sk_Window/examples/02_overview.jai",
  "modules/sk_Window/examples/03_multiwindows.jai",
  "modules/sk_Window/run_tests.jai",

  "modules/sk_d3d12/examples/01_hello_d3d12.jai",
  "modules/sk_vulkan/examples/01_hello_vulkan.jai",
];

build :: () {
    //
    // The goal of this program is actually to compile another program;
    // none of the code in this file is intended to end up in an executable
    // of any kind. So, we tell the compiler not to make an executable for us:
    //
    options : Build_Options_During_Compile;
    options.do_output = false;  // No executable for the primary workspace.
    set_build_options_dc(options);

    // 
    // Create a second workspace to contain the program we want to compile.
    // We can pass a name to compiler_create_workspace that gets reported
    // back to us in error messages:
    //
    err := false;
    for test: TESTS {
      print("Compiling: %...", test);
      w := compiler_create_workspace("Test");
      if !w {
          print("Workspace creation failed.\n");
          return;
      }

      // Let's set some build options on the target program.
      // For now, just the executable name!
      // We must set the build options before adding any source.
      // The compiler disallows this afterward, because it would result
      // in inconsistent compilation.
      target_options := get_build_options(w);
      target_options.output_type = .NO_OUTPUT;
      target_options.dead_code_elimination = .NONE;
      
      our_import_path := tprint("%/%", #filepath, "modules");
      import_path: [..] string;
      for target_options.import_path array_add(*import_path, it);
      array_add_if_unique(*import_path, our_import_path);
      target_options.import_path = import_path;

      set_build_options(target_options, w);

      // As the compiler builds the target program, we can listen in on messages
      // that report the status of the program. In later examples we can use
      // these messages to do sophisticated things, but for now, we'll just
      // use them to report on the status of compilation.
      
      // To tell the compiler to give us messages, we need to call compiler_begin_intercept
      // before we add any code to the target workspace.
      compiler_begin_intercept(w);

      // Now let's add the code.
      add_build_file(tprint("%/%", #filepath, test), w);  

      while true {
        message := compiler_wait_for_message();
        if !message break;
        if message.kind == { 
          case .ERROR;
            print("  Fail.\n");
            err = true;
          case .COMPLETE;
            if !err print("  OK.\n");
            break;
        }
      }

      // When we're done, message_loop will return.
      // We call compiler_end_intercept to tell the compiler we are done.
      compiler_end_intercept(w);
      array_free(import_path);
      if err break;
    }

    if !err {
      print("\nDone All OK!\n\n");
    } else {
      print("\nDone with Error!\n\n");
    }
}

#run build();

#import "Basic";
#import "Compiler";