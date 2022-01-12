//
// Hello Vulkan example
//
// by Hamad Almamari - last update 07/01/2022

// https://sopyer.github.io/b/post/minimal-vulkan-sample/
// https://sopyer.github.io/b/post/static-dynamic-geometry-vulkan/
// https://alain.xyz/blog/raw-vulkan
// https://stackoverflow.com/questions/54103399/how-to-repeatedly-update-a-uniform-data-for-number-of-objects-inside-a-single-vu
// http://kylehalladay.com/blog/tutorial/vulkan/2017/08/13/Vulkan-Uniform-Buffers.html
// https://www.khronos.org/registry/vulkan/specs/1.2-extensions/html/chap45.html
// https://www.lunarg.com/wp-content/uploads/2018/05/Vulkan-Debug-Utils_05_18_v1.pdf
// https://github.com/SaschaWillems/Vulkan/blob/master/base/VulkanDebug.cpp
// https://arm-software.github.io/vulkan_best_practice_for_mobile_developers/samples/performance/swapchain_images/swapchain_images_tutorial.html
// https://www.intel.com/content/www/us/en/developer/articles/training/api-without-secrets-introduction-to-vulkan-part-2.html#_Toc445674479

#import "Basic";
File    :: #import "File";
System  :: #import "System"; // get_path_of_running_executable
String  :: #import "String"; // path_strip_filename

// You can use any window module all what we need is the "hwnd", in this example we will use "sk_Window"
Window :: #import "sk_Window";
#import "sk_vulkan";

// Constants
DEBUG          :: true;
VERBOSE        :: false;
ASSERT_ON_FAIL :: true;
USE_VALIDATION_KHRONOS_LAYER :: DEBUG; // Vulkan SDK required to use validation layers.

FRAME_COUNT :u32: 2;
FOREVER     :u64: 0xffff_ffff_ffff_ffff; // U64_MAX
WIDTH       :u32: 800;
HEIGHT      :u32: 500;
VSYNC       :: true;

main :: () {
    path := String.path_strip_filename(System.get_path_of_running_executable());
    set_working_directory(path);

    window := Window.create(WIDTH, HEIGHT, "Hello Vulkan");
    defer Window.destroy(window);

    init_vulkan();

    init_render_context(window.hwnd, window.hinstance);

    init_pipeline();

    init_command_buffers();

    while true { 
        Window.process_events(window);
        if !window.valid break;

        draw_one_frame();
    }

    // wait
    vkQueueWaitIdle(vk_queue);
    deinit_command_buffers();
    deinit_pipeline();
    deinit_render_context();
    deinit_vulkan();
}

// those values "frame" and "submission_counter" will be used for commands submission/execution synchronization.
frame: u32;               // current frame (acquired/active frame) which is (active command buffer index)
submission_counter: u64;  // submission/execution counter/frame index

draw_one_frame :: () {
    { // wait
        // here we do not want the wait value for last submited frame, we want
        // to wait for the current frame (which in use/acquired frame) last submission.
        wait_value: u64;
        if submission_counter < FRAME_COUNT {
            wait_value = 0;
        } else {
            wait_value = (submission_counter - FRAME_COUNT) + 1;
        }
        // print("frame:% submission_counter:% checking:% next-check:% \n", frame, submission_counter, wait_value, submission_counter+1);
    
        // wait on the host for the GPU
        // make sure the GPU is done with the current acquired frame before recording new commands.
        info: VkSemaphoreWaitInfo;
        info.flags = 0;
        info.semaphoreCount = 1;
        info.pSemaphores    = *vk_timeline_semaphore;
        info.pValues        = *wait_value;
        vkWaitSemaphores(vk_logical_device, *info, FOREVER);
    }
    
    begin_info: VkCommandBufferBeginInfo;
    begin_info.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    vkBeginCommandBuffer(vk_command_buffers[frame], *begin_info);

    vkCmdBindPipeline(vk_command_buffers[frame], VK_PIPELINE_BIND_POINT_GRAPHICS, vk_pipeline);

    viewport: VkViewport;
    viewport.x = 0;
    viewport.y = 0;
    viewport.width    = xx WIDTH;
    viewport.height   = xx HEIGHT;
    viewport.minDepth = 0;
    viewport.maxDepth = 1;
    vkCmdSetViewport(vk_command_buffers[frame], 0, 1, *viewport);

    scissor_rect: VkRect2D;
    scissor_rect.offset.x = 0;
    scissor_rect.offset.y = 0;
    scissor_rect.extent.width = WIDTH;
    scissor_rect.extent.height = HEIGHT;
    vkCmdSetScissor(vk_command_buffers[frame], 0, 1, *scissor_rect);

    clear_value : VkClearValue;
    clear_value.color._float32 = float.[0.1, 0.2, 0.4, 1.0];
    fbi := swapchain_active_buffer_index;
    renderpass_info: VkRenderPassBeginInfo;
    renderpass_info.renderPass        = vk_render_pass;
    renderpass_info.framebuffer       = vk_swapchain_framebuffers[fbi];
    renderpass_info.clearValueCount   = 1;
    renderpass_info.pClearValues      = *clear_value;
    renderpass_info.renderArea.offset = .{0, 0};
    renderpass_info.renderArea.extent = vk_swapchain_extent;
    vkCmdBeginRenderPass(vk_command_buffers[frame], *renderpass_info, VK_SUBPASS_CONTENTS_INLINE);
    {
        vkCmdDraw(vk_command_buffers[frame], 3, 1, 0, 0);
    }
    vkCmdEndRenderPass(vk_command_buffers[frame]);

    vkEndCommandBuffer(vk_command_buffers[frame]);

    { // submit
        submission_counter += 1; // increment submission counter
        timeline_info: VkTimelineSemaphoreSubmitInfo;
        timeline_info.signalSemaphoreValueCount = 1;
        timeline_info.pSignalSemaphoreValues    = *submission_counter;

        submit_info: VkSubmitInfo;
        submit_info.pNext                = *timeline_info;
        submit_info.signalSemaphoreCount = 1;
        submit_info.pSignalSemaphores    = *vk_timeline_semaphore;
        submit_info.commandBufferCount   = 1;
        submit_info.pCommandBuffers      = *vk_command_buffers[frame];
        
        vkQueueSubmit(vk_queue, 1, *submit_info, null);
        frame = (frame+1) % FRAME_COUNT; // move to next frame
    }
    
    // now present
    // print("present: swapchain_active_buffer_index:% \n", swapchain_active_buffer_index);
    present_render_context();
}

//---------------------------------------------------------------------------
// NOTE:
// we do not set "sType" member for all vulkan calls, it is not needed since
// "sk_vulkan" module do not require that. 

//
// Init (call once) -----------------------
//

vk_instance              : VkInstance;
vk_physical_device       : VkPhysicalDevice;
vk_logical_device        : VkDevice;
vk_queue_family_index    : u32;
vk_queue                 : VkQueue; 
// vk_mem_properties        : VkPhysicalDeviceMemoryProperties;

// debuging
vk_debug_utils_messenger: VkDebugUtilsMessengerEXT;
// vulkan commands which will be loading using vkGetInstanceProcAddr.
vkCreateDebugUtilsMessengerEXT : PFN_vkCreateDebugUtilsMessengerEXT;
vkDestroyDebugUtilsMessengerEXT: PFN_vkDestroyDebugUtilsMessengerEXT;

init_vulkan :: () -> bool {
    result : VkResult = VK_ERROR_INITIALIZATION_FAILED;
    
    print_available_vulkan_extensions();
    print_available_vulkan_layers();

    // Application Info
    app_info: VkApplicationInfo;
    app_info.pApplicationName   = "Vulkan Application";
    app_info.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
    app_info.pEngineName        = "No Engine";
    app_info.engineVersion      = VK_MAKE_VERSION(1, 0, 0);
    app_info.apiVersion         = VK_MAKE_VERSION(1, 2, 0);

    // Create Vulkan Instance
    create_info : VkInstanceCreateInfo;
    create_info.pApplicationInfo = *app_info;
    #if !DEBUG {
        extensions : [2] *u8;
        extensions[0] = "VK_KHR_surface".data;
        extensions[1] = "VK_KHR_win32_surface".data;
    } else {
        extensions : [3] *u8;
        extensions[0] = "VK_KHR_surface".data;
        extensions[1] = "VK_KHR_win32_surface".data;
        extensions[2] = "VK_EXT_debug_utils".data; // Vulkan 1.1-capable loader
        // Note that VK_EXT_debug_report is Deprecated by VK_EXT_debug_utils extension
        //extensions[3] = "VK_EXT_debug_report".data;
    }
    create_info.enabledExtensionCount   = extensions.count;
    create_info.ppEnabledExtensionNames = extensions.data;

    #if DEBUG {
        debug_create_info := create_info;
        #if USE_VALIDATION_KHRONOS_LAYER {
            layers : [1] *u8;
            layers[0] = "VK_LAYER_KHRONOS_validation".data;
            // layers[1] = "VK_LAYER_LUNARG_api_dump".data;
            debug_create_info.enabledLayerCount   = layers.count;
            debug_create_info.ppEnabledLayerNames = layers.data;
        } else {
            debug_create_info.enabledLayerCount   = 0;
            debug_create_info.ppEnabledLayerNames = null;
        } 

        result = vkCreateInstance(*debug_create_info, null, *vk_instance);
        if result == VK_SUCCESS {
            vkCreateDebugUtilsMessengerEXT  = xx vkGetInstanceProcAddr(vk_instance, "vkCreateDebugUtilsMessengerEXT");
			vkDestroyDebugUtilsMessengerEXT = xx vkGetInstanceProcAddr(vk_instance, "vkDestroyDebugUtilsMessengerEXT");

            if vkCreateDebugUtilsMessengerEXT {
                dum_info: VkDebugUtilsMessengerCreateInfoEXT;
                // all
			    #if VERBOSE then dum_info.messageSeverity |= VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT;
                dum_info.messageSeverity |= VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT;
                dum_info.messageSeverity |= VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT;
                dum_info.messageSeverity |= VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
			    // all types
                dum_info.messageType     |= VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT;
                dum_info.messageType     |= VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT;
                dum_info.messageType     |= VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
			    dum_info.pfnUserCallback = debug_utils_messenger_proc;
			    _result := vkCreateDebugUtilsMessengerEXT(vk_instance, *dum_info, null, *vk_debug_utils_messenger);
			    if _result != VK_SUCCESS {
                    #if ASSERT_ON_FAIL assert(false, "vkCreateDebugUtilsMessengerEXT failed.");
                    deinit_vulkan();
                    return false;
                }
            }
        }
    }

    if result != VK_SUCCESS {
        result = vkCreateInstance(*create_info, null, *vk_instance);
    }
    
    if result != VK_SUCCESS {
        #if ASSERT_ON_FAIL assert(false, "vkCreateInstance failed.");
        deinit_vulkan();
        return false;
    }

    // Picking physical device
    MAX_DEVICE_COUNT :: 8;
    MAX_QUEUE_COUNT  :: 4; // ATM there should be at most transfer, graphics, compute, graphics+compute families

    device_handles         : [MAX_DEVICE_COUNT] VkPhysicalDevice;
    queue_family_properties: [MAX_QUEUE_COUNT]  VkQueueFamilyProperties;
    physical_device_count  : u32;

    vkEnumeratePhysicalDevices(vk_instance, *physical_device_count, null);
    physical_device_count = min(physical_device_count, MAX_DEVICE_COUNT);
    vkEnumeratePhysicalDevices(vk_instance, *physical_device_count, device_handles.data);

    print("Physical device count: %\n", physical_device_count);

    for i: 0..physical_device_count-1 {
        queue_family_count: u32 = 0;
        vkGetPhysicalDeviceQueueFamilyProperties(device_handles[i], *queue_family_count, null);
        queue_family_count = min(queue_family_count, MAX_QUEUE_COUNT);
        vkGetPhysicalDeviceQueueFamilyProperties(device_handles[i], *queue_family_count, queue_family_properties.data);

        print("Physical device % supports % queues families.\n", i, queue_family_count);

        for j: 0..queue_family_count-1 {
            supports_present := VK_FALSE;
            supports_present = vkGetPhysicalDeviceWin32PresentationSupportKHR(device_handles[i], j);

            print("Queue family properites: %.\n", queue_family_properties[j]);

            if supports_present && (queue_family_properties[j].queueFlags & VK_QUEUE_GRAPHICS_BIT) {
                vk_queue_family_index = j;
                vk_physical_device = device_handles[i];
                print("Queue family % supports present and graphics.\n", j);
                break;
            }
        }

        if (vk_physical_device) {
            break;
        }
    }

    print_available_physical_device_extensions(vk_physical_device);

    // Create Logical device and Queue
    queue_create_info: VkDeviceQueueCreateInfo;
    queue_create_info.queueFamilyIndex = vk_queue_family_index;
    queue_create_info.queueCount       = 1;
    queue_create_info.pQueuePriorities = float.[1.0].data;

    device_create_info: VkDeviceCreateInfo;
    device_create_info.queueCreateInfoCount = 1;
    device_create_info.pQueueCreateInfos = *queue_create_info;
    device_create_info.enabledLayerCount = 0;
    device_create_info.ppEnabledLayerNames = null;
    exexe: [2] *u8;
    exexe[0] = "VK_KHR_swapchain".data;
    exexe[1] = "VK_KHR_timeline_semaphore".data;
    device_create_info.enabledExtensionCount   = exexe.count;
    device_create_info.ppEnabledExtensionNames = exexe.data;

    device_features12: VkPhysicalDeviceVulkan12Features;
    device_features12.timelineSemaphore = VK_TRUE;
    device_create_info.pNext            = *device_features12;

    result = vkCreateDevice(vk_physical_device, *device_create_info, null, *vk_logical_device);
    if result != VK_SUCCESS {
        #if ASSERT_ON_FAIL assert(false, "vkCreateDevice failed.");
        deinit_vulkan();
        return false;
    }
    vkGetDeviceQueue(vk_logical_device, vk_queue_family_index, queueIndex=0, *vk_queue);

    return true;
}

deinit_vulkan :: () {
    if vk_logical_device {
        vkDeviceWaitIdle(vk_logical_device);
        vkDestroyDevice(vk_logical_device, null);
    }
    #if DEBUG {
        if vkDestroyDebugUtilsMessengerEXT && vk_debug_utils_messenger && vk_instance {
            vkDestroyDebugUtilsMessengerEXT(vk_instance, vk_debug_utils_messenger, null);
        }
    }
    if vk_instance vkDestroyInstance(vk_instance, null);
}

//
// Render Context  -------------------------
//

// surface
vk_surface            : VkSurfaceKHR;
vk_surface_format     : VkSurfaceFormatKHR; // no need to be global

// swapchain
MAX_SWAPCHAIN_BUFFER_COUNT   :: 3; //  max swapchain images
swapchain_buffer_count       : u32; // used backbuffer/framebuffer/image count
swapchain_active_buffer_index: u32; // active backbuffer/framebuffer related to "swapchain_buffer_count" (will be used for next present)

vk_swapchain          : VkSwapchainKHR;
vk_swapchain_images   : [MAX_SWAPCHAIN_BUFFER_COUNT] VkImage; // no need to be global
vk_swapchain_extent   : VkExtent2D; // ? is this need to be global?

// frame buffers
vk_render_pass: VkRenderPass; // render pass (to be used in Framebuffer Creation)
vk_swapchain_image_views     : [MAX_SWAPCHAIN_BUFFER_COUNT] VkImageView;
vk_swapchain_framebuffers    : [MAX_SWAPCHAIN_BUFFER_COUNT] VkFramebuffer;

// sync
vk_image_available_semaphores: [MAX_SWAPCHAIN_BUFFER_COUNT] VkSemaphore;
vk_render_finished_semaphores: [MAX_SWAPCHAIN_BUFFER_COUNT] VkSemaphore;

init_render_context :: (hwnd: *void, hinstance: *void) -> bool {
    result : VkResult = VK_ERROR_INITIALIZATION_FAILED;

    // Create Surface
    surface_create_info: VkWin32SurfaceCreateInfoKHR; 
    surface_create_info.sType     = VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR;
    surface_create_info.hinstance = hinstance;
    surface_create_info.hwnd      = hwnd;
    result = vkCreateWin32SurfaceKHR(vk_instance, *surface_create_info, null, *vk_surface);
    if result != VK_SUCCESS {
        #if ASSERT_ON_FAIL assert(false, "vkCreateWin32SurfaceKHR failed.");
        deinit_render_context();
        return false;
    }
    
    { // suppress validation layer, since we are using vkGetPhysicalDeviceWin32PresentationSupportKHR.
        supports_present := VK_FALSE; 
        vkGetPhysicalDeviceSurfaceSupportKHR(vk_physical_device, vk_queue_family_index, vk_surface, *supports_present);
        assert(supports_present == VK_TRUE);
    }

    // Use first available format
    format_count : u32 = 1;
    vkGetPhysicalDeviceSurfaceFormatsKHR(vk_physical_device, vk_surface, *format_count, null); // suppress validation layer
    vkGetPhysicalDeviceSurfaceFormatsKHR(vk_physical_device, vk_surface, *format_count, *vk_surface_format);
    vk_surface_format.format = ifx vk_surface_format.format == VK_FORMAT_UNDEFINED then VK_FORMAT_B8G8R8A8_UNORM else vk_surface_format.format;

    // Select present mode
    // SEE: https://arm-software.github.io/vulkan_best_practice_for_mobile_developers/samples/performance/swapchain_images/swapchain_images_tutorial.html
    // SEE: https://www.khronos.org/registry/vulkan/specs/1.2-extensions/man/html/VkPresentModeKHR.html
    MAX_PRESENT_MODE_COUNT :: 6; // At the moment in spec
    PRESENT_MODE_MAILBOX_IMAGE_COUNT :u32: 3;
    PRESENT_MODE_DEFAULT_IMAGE_COUNT :u32: 2;

    present_mode_count : u32 = 0;
    vkGetPhysicalDeviceSurfacePresentModesKHR(vk_physical_device, vk_surface, *present_mode_count, null);
    present_modes: [MAX_PRESENT_MODE_COUNT] VkPresentModeKHR;
    present_mode_count = min(present_mode_count, MAX_PRESENT_MODE_COUNT);
    vkGetPhysicalDeviceSurfacePresentModesKHR(vk_physical_device, vk_surface, *present_mode_count, present_modes.data);

    present_mode : VkPresentModeKHR = VK_PRESENT_MODE_FIFO_KHR;   // always supported.
    #if !VSYNC {
        for 0..present_mode_count-1 {
            if present_modes[it] == VK_PRESENT_MODE_MAILBOX_KHR {
                present_mode = VK_PRESENT_MODE_MAILBOX_KHR;
                break;
            }
        }
    }
    
    // Set swapchain image count (Buffer Count)
    swapchain_buffer_count = ifx present_mode == VK_PRESENT_MODE_MAILBOX_KHR  then PRESENT_MODE_MAILBOX_IMAGE_COUNT else  PRESENT_MODE_DEFAULT_IMAGE_COUNT;

    // Get surface Caps
    surface_capabilities: VkSurfaceCapabilitiesKHR;
    vkGetPhysicalDeviceSurfaceCapabilitiesKHR(vk_physical_device, vk_surface, *surface_capabilities);

    // print("minImageCount:% maxImageCount:% used:%\n", surface_capabilities.minImageCount, surface_capabilities.maxImageCount, swapchain_buffer_count);
    // Set swapchain extent
    vk_swapchain_extent = surface_capabilities.currentExtent;

    u32_low, u32_high := get_integer_range(u32);

    if vk_swapchain_extent.width == u32_high {
        vk_swapchain_extent.width  = clamp(WIDTH, surface_capabilities.minImageExtent.width, surface_capabilities.maxImageExtent.width);
        vk_swapchain_extent.height = clamp(HEIGHT, surface_capabilities.minImageExtent.height, surface_capabilities.maxImageExtent.height);
    }

    // Create swapchain
    swapchain_create_info: VkSwapchainCreateInfoKHR;
    swapchain_create_info.surface          = vk_surface;
    swapchain_create_info.minImageCount    = swapchain_buffer_count;
    swapchain_create_info.imageFormat      = vk_surface_format.format;
    swapchain_create_info.imageColorSpace  = vk_surface_format.colorSpace;
    swapchain_create_info.imageExtent      = vk_swapchain_extent;
    swapchain_create_info.imageArrayLayers = 1; // 2 for stereo
    swapchain_create_info.imageUsage       = (VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT);
    swapchain_create_info.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
    swapchain_create_info.preTransform     = surface_capabilities.currentTransform;
    swapchain_create_info.compositeAlpha   = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
    swapchain_create_info.presentMode      = present_mode;
    swapchain_create_info.clipped          = VK_TRUE;

    result = vkCreateSwapchainKHR(vk_logical_device, *swapchain_create_info, null, *vk_swapchain);
    if result != VK_SUCCESS {
        #if ASSERT_ON_FAIL assert(false, "vkCreateSwapchainKHR failed.");
        deinit_render_context();
        return false;
    }

    // Get swapchain images
    vkGetSwapchainImagesKHR(vk_logical_device, vk_swapchain, *swapchain_buffer_count, null);
    vkGetSwapchainImagesKHR(vk_logical_device, vk_swapchain, *swapchain_buffer_count, vk_swapchain_images.data);

    // Create Renderpass 
    {
    attachment_desc: VkAttachmentDescription;
    attachment_desc.format         = vk_surface_format.format;
    attachment_desc.samples        = VK_SAMPLE_COUNT_1_BIT;
    attachment_desc.loadOp         = VK_ATTACHMENT_LOAD_OP_CLEAR;
    attachment_desc.storeOp        = VK_ATTACHMENT_STORE_OP_STORE;
    attachment_desc.stencilLoadOp  = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    attachment_desc.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
    attachment_desc.initialLayout  = VK_IMAGE_LAYOUT_UNDEFINED;
    attachment_desc.finalLayout    = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

    attachment_ref: VkAttachmentReference;
    attachment_ref.attachment = 0;
    attachment_ref.layout     = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

    subpass_desc: VkSubpassDescription;
    subpass_desc.pipelineBindPoint    = VK_PIPELINE_BIND_POINT_GRAPHICS;
    subpass_desc.colorAttachmentCount = 1;
    subpass_desc.pColorAttachments    = *attachment_ref;

    // Initialize sub-pass dependency
    subpass_dep: VkSubpassDependency;
    {
        subpass_dep.srcSubpass               = VK_SUBPASS_EXTERNAL;
        subpass_dep.dstSubpass               = 0;
        subpass_dep.srcStageMask             = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT; //VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT
        subpass_dep.dstStageMask             = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        subpass_dep.srcAccessMask            = 0;
        subpass_dep.dstAccessMask            = (VK_ACCESS_COLOR_ATTACHMENT_READ_BIT | VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT);
        subpass_dep.dependencyFlags          = 0;
    }

    rp_info: VkRenderPassCreateInfo;
    rp_info.sType           = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
    rp_info.attachmentCount = 1;
    rp_info.pAttachments    = *attachment_desc;
    rp_info.subpassCount    = 1;
    rp_info.pSubpasses      = *subpass_desc;
    rp_info.dependencyCount = 1;
    rp_info.pDependencies   = *subpass_dep;

    result = vkCreateRenderPass(vk_logical_device, *rp_info, null, *vk_render_pass);
    if result != VK_SUCCESS {
        #if ASSERT_ON_FAIL assert(false, "vkCreateRenderPass failed.");
        deinit_render_context();
        return false;
    }
    } // render pass end

    // Frame Buffers
    {
    for i: 0..swapchain_buffer_count-1 {
        createInfo: VkImageViewCreateInfo; 
        createInfo.image    = vk_swapchain_images[i];
        createInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
        createInfo.format   = vk_surface_format.format;
        createInfo.subresourceRange = .{
                aspectMask = VK_IMAGE_ASPECT_COLOR_BIT,
                baseMipLevel = 0,
                levelCount = 1,
                baseArrayLayer = 0,
                layerCount = 1,
            };
        result := vkCreateImageView(vk_logical_device, *createInfo, null, *vk_swapchain_image_views[i]);
        if result != VK_SUCCESS {
            #if ASSERT_ON_FAIL assert(false, "vkCreateImageView failed.");
            deinit_render_context();
            return false;
        }

        framebuffer_info: VkFramebufferCreateInfo;
        framebuffer_info.sType           = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
        framebuffer_info.renderPass      = vk_render_pass;
        framebuffer_info.attachmentCount = 1;
        framebuffer_info.pAttachments    = *vk_swapchain_image_views[i];
        framebuffer_info.width           = vk_swapchain_extent.width;
        framebuffer_info.height          = vk_swapchain_extent.height;
        framebuffer_info.layers          = 1;
        result = vkCreateFramebuffer(vk_logical_device, *framebuffer_info, null, *vk_swapchain_framebuffers[i]);
        if result != VK_SUCCESS {
            #if ASSERT_ON_FAIL assert(false, "vkCreateFramebuffer failed.");
            deinit_render_context();
            return false;
        }
    }
    } // frame buffers

    semaphore_info: VkSemaphoreCreateInfo;
    for 0..swapchain_buffer_count-1 {
        result = vkCreateSemaphore(vk_logical_device, *semaphore_info, null, *vk_image_available_semaphores[it]);
        if result != VK_SUCCESS {
            #if ASSERT_ON_FAIL assert(false, "vkCreateSemaphore failed.");
            deinit_render_context();
            return false;
        }
        result = vkCreateSemaphore(vk_logical_device, *semaphore_info, null, *vk_render_finished_semaphores[it]);
        if result != VK_SUCCESS {
            #if ASSERT_ON_FAIL assert(false, "vkCreateSemaphore failed.");
            deinit_render_context();
            return false;
        }
    }

    // setup next frame (for present)
    vkAcquireNextImageKHR(vk_logical_device, vk_swapchain, FOREVER, vk_image_available_semaphores[swapchain_active_buffer_index], VK_NULL_HANDLE, *swapchain_active_buffer_index);

    return true;
}

present_render_context :: () {
    index  := swapchain_active_buffer_index;

    // wait for the gpu on the gpu
    submitInfo: VkSubmitInfo; 
    submitInfo.waitSemaphoreCount   = 1;
    submitInfo.pWaitSemaphores      = *vk_image_available_semaphores[index]; // wait for image to be aquired
    submitInfo.pWaitDstStageMask    = VkPipelineStageFlags.[VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT].data;
    submitInfo.commandBufferCount   = 0;
    submitInfo.pCommandBuffers      = null;
    submitInfo.signalSemaphoreCount = 1;
    submitInfo.pSignalSemaphores    = *vk_render_finished_semaphores[index];
    vkQueueSubmit(vk_queue, 1, *submitInfo, null);

    presentInfo: VkPresentInfoKHR;
    presentInfo.waitSemaphoreCount = 1;
    presentInfo.pWaitSemaphores    = *vk_render_finished_semaphores[index];
    presentInfo.swapchainCount     = 1;
    presentInfo.pSwapchains        = *vk_swapchain;
    presentInfo.pImageIndices      = *swapchain_active_buffer_index;
    vkQueuePresentKHR(vk_queue, *presentInfo);
    
    // set the backbuffer index for next present.
    swapchain_active_buffer_index = (swapchain_active_buffer_index+1) % swapchain_buffer_count;
    vkAcquireNextImageKHR(vk_logical_device, vk_swapchain, FOREVER, vk_image_available_semaphores[swapchain_active_buffer_index], VK_NULL_HANDLE, *swapchain_active_buffer_index);
}

deinit_render_context :: () {
    { // wait for all Framebuffers
        vkQueueWaitIdle(vk_queue); 
    }
    for 0..swapchain_buffer_count-1 {
        if vk_swapchain_framebuffers[it]     then vkDestroyFramebuffer(vk_logical_device, vk_swapchain_framebuffers[it], null);
        if vk_swapchain_image_views[it]      then vkDestroyImageView  (vk_logical_device, vk_swapchain_image_views[it], null);
        if vk_render_finished_semaphores[it] then vkDestroySemaphore  (vk_logical_device, vk_render_finished_semaphores[it], null);
        if vk_image_available_semaphores[it] then vkDestroySemaphore  (vk_logical_device, vk_image_available_semaphores[it], null);
    }
    if vk_render_pass vkDestroyRenderPass(vk_logical_device, vk_render_pass, null);
    if vk_swapchain   vkDestroySwapchainKHR(vk_logical_device, vk_swapchain, null);
    if vk_surface     vkDestroySurfaceKHR(vk_instance, vk_surface, null);
}

//
// Pipeline --------------------------------------
//

vk_pipeline_layout: VkPipelineLayout;
vk_pipeline: VkPipeline;

// my vertex layout
// Vertex :: struct { 
//     x, y: float;
//     r, g, b: float;
// }

init_pipeline :: () -> bool {
    pipeline_info: VkGraphicsPipelineCreateInfo;

    // PIPELINE LAYOUT
    pipeline_layout_info: VkPipelineLayoutCreateInfo;
    result := vkCreatePipelineLayout(vk_logical_device, *pipeline_layout_info, null, *vk_pipeline_layout);
    if result != VK_SUCCESS {
        #if ASSERT_ON_FAIL assert(false, "vkCreatePipelineLayout failed.");
        deinit_pipeline();
        return false;
    }

    pipeline_info.layout = vk_pipeline_layout;

    // SHADERS
    stages: [2] VkPipelineShaderStageCreateInfo;
    // vertex shader
    vs := create_shader_module_from_spv_file("shaders/hello_shader.vert.spv");
    defer vkDestroyShaderModule(vk_logical_device, vs, null);
    stages[0].stage  = VK_SHADER_STAGE_VERTEX_BIT;
    stages[0].module = vs;
    stages[0].pName  = "main".data;
    // fragment shader
    fs := create_shader_module_from_spv_file("shaders/hello_shader.frag.spv");
    defer vkDestroyShaderModule(vk_logical_device, fs, null);
    stages[1].stage  = VK_SHADER_STAGE_FRAGMENT_BIT;
    stages[1].module = fs;
    stages[1].pName  = "main".data;

    pipeline_info.stageCount = stages.count;
    pipeline_info.pStages    = stages.data;

    // //VERTEX LAYOUT 
    // binding_desc   : [1] VkVertexInputBindingDescription;
    // binding_desc[0].binding   = 0;
    // binding_desc[0].stride    = size_of(Vertex); 
    // binding_desc[0].inputRate = VK_VERTEX_INPUT_RATE_VERTEX;

    // attribute_desc: [2] VkVertexInputAttributeDescription;
    // // position XY
    // attribute_desc[0].location = 0;
    // attribute_desc[0].binding = 0;
    // attribute_desc[0].format = VK_FORMAT_R32G32_SFLOAT;
    // attribute_desc[0].offset = 0;
    // // color RGB
    // attribute_desc[1].location = 1;
    // attribute_desc[1].binding = 0;
    // attribute_desc[1].format = VK_FORMAT_R32G32B32_SFLOAT;
    // attribute_desc[1].offset = size_of(float) * 2;

    vertex_input_state: VkPipelineVertexInputStateCreateInfo;
    // vertex_input_state.vertexBindingDescriptionCount   = xx binding_desc.count;
    // vertex_input_state.pVertexBindingDescriptions      = binding_desc.data;
    // vertex_input_state.vertexAttributeDescriptionCount = xx attribute_desc.count;
    // vertex_input_state.pVertexAttributeDescriptions    = attribute_desc.data;
    vertex_input_state.vertexBindingDescriptionCount   = 0;
    vertex_input_state.pVertexBindingDescriptions      = null;
    vertex_input_state.vertexAttributeDescriptionCount = 0;
    vertex_input_state.pVertexAttributeDescriptions    = null;
    
    pipeline_info.pVertexInputState = *vertex_input_state;

    // TOPOLOGY
    vertex_assembly_state: VkPipelineInputAssemblyStateCreateInfo;
    vertex_assembly_state.primitiveRestartEnable = VK_FALSE;
    vertex_assembly_state.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;

    pipeline_info.pInputAssemblyState = *vertex_assembly_state;

    // RASTERIZATION STATE
    raster_state: VkPipelineRasterizationStateCreateInfo;
    raster_state.depthClampEnable = VK_FALSE;
    raster_state.rasterizerDiscardEnable = VK_FALSE;
    raster_state.polygonMode = VK_POLYGON_MODE_FILL;
    raster_state.cullMode = VK_CULL_MODE_BACK_BIT;
    raster_state.frontFace = VK_FRONT_FACE_CLOCKWISE;
    raster_state.depthBiasEnable = VK_FALSE;
    raster_state.depthBiasConstantFactor = 0.0;
    raster_state.depthBiasClamp = 0.0;
    raster_state.depthBiasSlopeFactor = 0.0;
    raster_state.lineWidth = 1.0;

    pipeline_info.pRasterizationState = *raster_state;

    // MULTISAMPLE STATE
    multisample_state: VkPipelineMultisampleStateCreateInfo;
    multisample_state.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;
    multisample_state.sampleShadingEnable = VK_FALSE;
    multisample_state.minSampleShading = 1.0;
    multisample_state.pSampleMask = null;
    multisample_state.alphaToCoverageEnable = VK_FALSE;
    multisample_state.alphaToOneEnable = VK_FALSE;

    pipeline_info.pMultisampleState = *multisample_state;
    
    // BLEND STATE
    blend_attac: VkPipelineColorBlendAttachmentState;
    blend_attac.blendEnable = VK_FALSE;
    blend_attac.srcColorBlendFactor = VK_BLEND_FACTOR_ONE;
    blend_attac.dstColorBlendFactor = VK_BLEND_FACTOR_ZERO;
    blend_attac.colorBlendOp = VK_BLEND_OP_ADD;
    blend_attac.srcAlphaBlendFactor = VK_BLEND_FACTOR_ONE;
    blend_attac.dstAlphaBlendFactor = VK_BLEND_FACTOR_ZERO;
    blend_attac.alphaBlendOp   = VK_BLEND_OP_ADD;
    blend_attac.colorWriteMask = (VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT);

    blend_state: VkPipelineColorBlendStateCreateInfo;
    blend_state.logicOpEnable = VK_FALSE;
    blend_state.attachmentCount = 1;
    blend_state.pAttachments = *blend_attac; 

    pipeline_info.pColorBlendState = *blend_state;

    // VIEWPORT STATE
    viewport_state: VkPipelineViewportStateCreateInfo;
    viewport_state.viewportCount = 1;
    viewport_state.pViewports = null;
    viewport_state.scissorCount = 1;
    viewport_state.pScissors = null;

    pipeline_info.pViewportState = *viewport_state;

    // DYNAMIC STATE
    dyn_state := VkDynamicState.[VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR];
    dynamic_state: VkPipelineDynamicStateCreateInfo;
    dynamic_state.dynamicStateCount = dyn_state.count;
    dynamic_state.pDynamicStates    = dyn_state.data;

    pipeline_info.pDynamicState = *dynamic_state;

    // RENDERPASS
    pipeline_info.renderPass = vk_render_pass;

    result = vkCreateGraphicsPipelines(vk_logical_device, VK_NULL_HANDLE, 1, *pipeline_info, null, *vk_pipeline);
    if result != VK_SUCCESS {
        #if ASSERT_ON_FAIL assert(false, "vkCreateGraphicsPipelines failed.");
        deinit_pipeline();
        return false;
    }

    return true;
}

deinit_pipeline :: () {
    if vk_pipeline vkDestroyPipeline(vk_logical_device, vk_pipeline, null);
    if vk_pipeline_layout vkDestroyPipelineLayout(vk_logical_device, vk_pipeline_layout, null);
}

//
// Command Buffers ------------------------------------
//

vk_command_pool    : VkCommandPool;
vk_command_buffers : [FRAME_COUNT] VkCommandBuffer;
// sync
vk_timeline_semaphore: VkSemaphore; // we will use timeline Semaphore not VKFence

init_command_buffers :: () -> bool {
    result : VkResult = VK_ERROR_INITIALIZATION_FAILED;

    // create pool
    pool_info: VkCommandPoolCreateInfo;
    pool_info.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    pool_info.queueFamilyIndex = vk_queue_family_index;
    result = vkCreateCommandPool(vk_logical_device, *pool_info, null, *vk_command_pool);
    if result != VK_SUCCESS {
        #if ASSERT_ON_FAIL assert(false, "vkCreateCommandPool failed.");
        deinit_command_buffers();
        return false;
    }

    // alloc buffers
    info: VkCommandBufferAllocateInfo;
    info.commandPool = vk_command_pool;
    info.level       = VK_COMMAND_BUFFER_LEVEL_PRIMARY;

    info.commandBufferCount = FRAME_COUNT;

    result = vkAllocateCommandBuffers(vk_logical_device, *info, vk_command_buffers.data);
    if result != VK_SUCCESS {
        #if ASSERT_ON_FAIL assert(false, "vkAllocateCommandBuffers failed.");
        deinit_command_buffers();
        return false;
    }

    semaphore_type_info: VkSemaphoreTypeCreateInfo;
    semaphore_type_info.semaphoreType = VK_SEMAPHORE_TYPE_TIMELINE;
    semaphore_type_info.initialValue  = 0;

    semaphore_info: VkSemaphoreCreateInfo;
    semaphore_info.pNext = *semaphore_type_info;
    semaphore_info.flags = 0;

    result = vkCreateSemaphore(vk_logical_device, *semaphore_info, null, *vk_timeline_semaphore);
    if result != VK_SUCCESS {
        #if ASSERT_ON_FAIL assert(false, "vkCreateSemaphore failed.");
        deinit_command_buffers();
        return false;
    }

    return true;
}

deinit_command_buffers :: () {
    if vk_command_pool { // wait for all commands
        wait_value:= submission_counter;
        info: VkSemaphoreWaitInfo;
        info.flags = 0;
        info.semaphoreCount = 1;
        info.pSemaphores    = *vk_timeline_semaphore;
        info.pValues        = *wait_value;
        vkWaitSemaphores(vk_logical_device, *info, FOREVER);
    }
    if vk_command_pool {
        vkDestroyCommandPool(vk_logical_device, vk_command_pool, null);
    }
    if vk_timeline_semaphore vkDestroySemaphore(vk_logical_device, vk_timeline_semaphore, null);
}

//
// Utils  -------------------------
//

// see: https://www.khronos.org/registry/vulkan/specs/1.2-extensions/man/html/VkDebugUtilsMessengerCallbackDataEXT.html
//
debug_utils_messenger_proc :: (msg_severity:VkDebugUtilsMessageSeverityFlagBitsEXT, msg_type:VkDebugUtilsMessageTypeFlagsEXT, msg:*VkDebugUtilsMessengerCallbackDataEXT, user_data:*void) -> VkBool32 #c_call {
    
    new_context: Context;
    push_context new_context {
        prefix: string;
        if  msg_severity &  VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT {
            prefix = "VERBOSE";
        }
        if msg_severity & VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT {
            prefix = "INFO";
        }
        if msg_severity & VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT {
            prefix = "WARNING";
        }
        if msg_severity & VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT {
            prefix = "ERROR";
        }

        type: string;
        if  msg_type & VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT {
            type = "GENERAL";
        }
        if msg_type & VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT {
            type = "VALIDATION";
        }
        if msg_type & VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT {
            type = "PERFORMANCE";
        }

        print("[Vulkan][%]: % - % (%), %\n", prefix, type, to_string(msg.pMessageIdName), msg.messageIdNumber, to_string(msg.pMessage));
    }
    // The return value of this callback controls whether the Vulkan call that caused the validation message will be aborted or not
	// We return VK_FALSE as we DON'T want Vulkan calls that cause a validation message to abort
	// If you instead want to have calls abort, pass in VK_TRUE and the function will return VK_ERROR_VALIDATION_FAILED_EXT
    return VK_FALSE;
}

print_available_vulkan_extensions :: () {
    extension_count: u32;
    vkEnumerateInstanceExtensionProperties(null, *extension_count, null);
    extension_array := NewArray(extension_count, VkExtensionProperties);
    defer free(extension_array.data);
    vkEnumerateInstanceExtensionProperties(null, *extension_count, extension_array.data);
    print("Available Instance extensions:\n");
    for extension_array print("    % (%)\n", to_string(it.extensionName.data), it.specVersion);
}

print_available_vulkan_layers :: () {
    layer_count: u32;
    vkEnumerateInstanceLayerProperties(*layer_count, null);
    layer_array := NewArray(layer_count, VkLayerProperties);
    defer free(layer_array.data);
    vkEnumerateInstanceLayerProperties(*layer_count, layer_array.data);
    print("Available Instance layers:\n");
    for layer_array print("    % (%)(%)\n", to_string(it.layerName.data), it.specVersion, it.implementationVersion);
} 

print_available_physical_device_extensions :: (physical_device: VkPhysicalDevice) {
    extension_count: u32;
    vkEnumerateDeviceExtensionProperties(physical_device, null, *extension_count, null);
    extension_array := NewArray(extension_count, VkExtensionProperties);
    defer free(extension_array.data);
    vkEnumerateDeviceExtensionProperties(physical_device, null, *extension_count, extension_array.data);
    print("Available Device extensions:\n");
    for extension_array print("    % (%)\n", to_string(it.extensionName.data), it.specVersion);
}

create_shader_module_from_spv_file :: (filepath: string) -> VkShaderModule {
    vk_shader_module: VkShaderModule;

    file, success := File.read_entire_file(filepath);
    if !success {
        #if ASSERT_ON_FAIL assert(false, "File.read_entire_file failed.");
        return null;
    }

    info: VkShaderModuleCreateInfo;
    info.sType    = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    info.codeSize = xx file.count;
    info.pCode    = cast(*u32) file.data;
    result := vkCreateShaderModule(vk_logical_device, *info, null, *vk_shader_module);
    free(file.data);
    if result != VK_SUCCESS {
        #if ASSERT_ON_FAIL assert(false, "vkCreateShaderModule failed.");
        return null;
    }

    return vk_shader_module;
}

// shaders compiled using
//C:\VulkanSDK\1.2.189.2\Bin\glslc.exe shader.vert -o vert.spv
//C:\VulkanSDK\1.2.189.2\Bin\glslc.exe shader.frag -o frag.spv