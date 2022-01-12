//
// Hello d3d12 example
//
// by Hamad Almamari - last update 07/01/2022
//

// https://alain.xyz/blog/raw-directx12
// https://github.com/microsoft/DirectX-Graphics-Samples/tree/master/Samples/Desktop/D3D12HelloWorld
// https://devblogs.microsoft.com/directx/dxgi-flip-model/
// https://walbourn.github.io/care-and-feeding-of-modern-swapchains/ 

#import "Basic";
System  :: #import "System"; // get_path_of_running_executable
String  :: #import "String"; // path_strip_filename

#import "Windows";
D3dcompiler :: #import "D3dcompiler";

// You can use any window module all what we need is the "hwnd", in this example we will use "sk_Window"
Window :: #import "sk_Window";
#import "sk_dxgi";
#import "sk_d3d12";

// Constants
DEBUG   :: true;
// VERBOSE :: false;
ASSERT_ON_FAIL :: true;
BREAK_ON_ERROR :: false; // while you debug the .exe in VS the code will break. keep this false to see debug msgs.

FRAME_COUNT :u32: 2;
FOREVER     :u64: 0xffff_ffff_ffff_ffff; // U64_MAX
WIDTH       :u32: 800;
HEIGHT      :u32: 500;
VSYNC       :: false;

main :: () {
    path := String.path_strip_filename(System.get_path_of_running_executable());
    set_working_directory(path);

    window := Window.create(WIDTH, HEIGHT, "Hello D3d12");
    defer Window.destroy(window);

    init_d3d12();

    init_render_context(window.hwnd);

    init_pipeline();

    init_command_lists();

    while true { 
        Window.process_events(window);
        if !window.valid break;

        draw_one_frame();
        #if DEBUG print_debug_msgs();
    }

    // CLEANUP
    { // wait (Wait for all commands to be executed)
        wait_value:= submission_counter;
        if (d3d12_fence.GetCompletedValue(d3d12_fence) < wait_value) {
            d3d12_fence.SetEventOnCompletion(d3d12_fence, wait_value, d3d12_fence_event);
            WaitForSingleObject(d3d12_fence_event, 0xffff_ffff); // 0xffff_ffff is U32_MAX
        }
    }

    deinit_pipeline();
    deinit_command_lists();
    deinit_render_context();
    deinit_d3d12();
}

// those values "frame" and "submission_counter" will be used for commands submission/execution synchronization.
frame: u32;               // current frame (acquired/active frame) which is (active command list index)
submission_counter: u64;  // submission/execution counter/frame index

// SEE: https://github.com/microsoft/DirectX-Graphics-Samples/blob/master/Samples/Desktop/D3D12HelloWorld/src/HelloFrameBuffering/D3D12HelloFrameBuffering.cpp
draw_one_frame :: () {
    hr: HRESULT;
    { // wait (Wait for the command list to execute)
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
        if (d3d12_fence.GetCompletedValue(d3d12_fence) < wait_value) {
            hr = d3d12_fence.SetEventOnCompletion(d3d12_fence, wait_value, d3d12_fence_event);
            WaitForSingleObject(d3d12_fence_event, 0xffff_ffff); // 0xffff_ffff is U32_MAX
        }
    }

    // Populate Command List

    // when ExecuteCommandList() is called on a particular command 
    // list, that command list can then be reset at any time and must be before 
    // re-recording.
    hr = d3d12_command_lists[frame].Reset(d3d12_command_lists[frame], d3d12_command_allocator, d3d12_pipeline_state);
    assert(S_OK == hr);

    // Set necessary state.
    d3d12_command_lists[frame].SetGraphicsRootSignature(d3d12_command_lists[frame], d3d12_root_signature);

    viewport: D3D12_VIEWPORT;
    viewport.TopLeftX = 0.0;
    viewport.TopLeftY = 0.0;
    viewport.Width    = xx WIDTH;
    viewport.Height   = xx HEIGHT;
    viewport.MinDepth = 0.0;
    viewport.MaxDepth = 1.0; 

    d3d12_command_lists[frame].RSSetViewports(d3d12_command_lists[frame], 1, *viewport);

    surface_size: D3D12_RECT;
    surface_size.left = 0;
    surface_size.top = 0;
    surface_size.right = xx WIDTH;
    surface_size.bottom = xx HEIGHT;

    d3d12_command_lists[frame].RSSetScissorRects(d3d12_command_lists[frame], 1, *surface_size);

    // Indicate that the back buffer will be used as a render target. (rp)
    rt_barrier: D3D12_RESOURCE_BARRIER;
    rt_barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    rt_barrier.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE;
    rt_barrier.Transition.pResource   = d3d12_swapchain_rtvs[swapchain_active_buffer_index];
    rt_barrier.Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT;
    rt_barrier.Transition.StateAfter  = D3D12_RESOURCE_STATE_RENDER_TARGET;
    rt_barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    d3d12_command_lists[frame].ResourceBarrier(d3d12_command_lists[frame], 1, *rt_barrier);

    rtv_handle: D3D12_CPU_DESCRIPTOR_HANDLE = d3d12_swapchain_rtv_heap.GetCPUDescriptorHandleForHeapStart(d3d12_swapchain_rtv_heap);
    rtv_handle.ptr = rtv_handle.ptr + (swapchain_active_buffer_index * d3d12_swapchain_rtv_heap_inc_size);
    d3d12_command_lists[frame].OMSetRenderTargets(d3d12_command_lists[frame], 1, *rtv_handle, .FALSE, null);

    // Record commands.
    clearColor := float.[0.1, 0.2, 0.4, 1.0];
    d3d12_command_lists[frame].ClearRenderTargetView(d3d12_command_lists[frame], rtv_handle, *clearColor, 0, null);
    d3d12_command_lists[frame].IASetPrimitiveTopology(d3d12_command_lists[frame], D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    //d3d12_command_lists[frame].IASetVertexBuffers(d3d12_command_lists[frame], 0, 1, *m_vertexBufferView);
    d3d12_command_lists[frame].DrawInstanced(d3d12_command_lists[frame], 3, 1, 0, 0);

    // Indicate that the back buffer will now be used to present. (rp)
    present_barrier: D3D12_RESOURCE_BARRIER;
    present_barrier.Type  = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    present_barrier.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE;
    present_barrier.Transition.pResource   = d3d12_swapchain_rtvs[swapchain_active_buffer_index];
    present_barrier.Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET;
    present_barrier.Transition.StateAfter  = D3D12_RESOURCE_STATE_PRESENT;
    present_barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;

    d3d12_command_lists[frame].ResourceBarrier(d3d12_command_lists[frame], 1, *present_barrier);

    hr = d3d12_command_lists[frame].Close(d3d12_command_lists[frame]);


    { // submit
        // Execute the command list.
        d3d12_queue.ExecuteCommandLists(d3d12_queue, 1, xx *d3d12_command_lists[frame]);
        // then increment submission counter
        submission_counter += 1;
        // Signal and increment the fence value.
        d3d12_queue.Signal(d3d12_queue, d3d12_fence, submission_counter);
        // move to next frame
        frame = (frame+1) % FRAME_COUNT;
    }

    // now present
    // print("present: swapchain_active_buffer_index:% \n", swapchain_active_buffer_index);
    present_render_context();
}

//
// Init (call once) -----------------------
//

d3d12_factory: *IDXGIFactory4;
d3d12_adapter: *IDXGIAdapter1;
d3d12_device : *ID3D12Device;
d3d12_queue  : *ID3D12CommandQueue;

// Debug
d3d12_info_queue: *ID3D12InfoQueue; 

init_d3d12 :: () -> bool {
    hr: HRESULT;
    dxgi_factory_flags: u32 = 0;

    #if DEBUG {
        // Enable the debug layer (requires the Graphics Tools "optional feature").
        // For Windows 10, to create a device that supports the debug layer,
        // enable the "Graphics Tools" optional feature. Go to the Settings panel,
        // under System, Apps & features, Manage optional Features, Add a feature,
        // and then look for "Graphics Tools".
        // NOTE: Enabling the debug layer after device creation will invalidate the active device.
        {
            debug_interface: *ID3D12Debug1;
            if SUCCEEDED(D3D12GetDebugInterface(*debug_interface.iid, xx *debug_interface)) {
                debug_interface.EnableDebugLayer(debug_interface);
                // debug_interface.SetEnableGPUBasedValidation(debug_interface, .TRUE);
                // debug_interface.SetEnableSynchronizedCommandQueueValidation(debug_interface, .TRUE);
            }
        }
    }

    // Cretae Factory
    hr = CreateDXGIFactory2(dxgi_factory_flags, *d3d12_factory.iid, xx *d3d12_factory);
    if hr != S_OK {
        #if ASSERT_ON_FAIL assert(false, "CreateDXGIFactory2 failed.");
        deinit_d3d12();
        return false;
    }

    // Get Harwere Adapter
    warp_adapter_found := false;

    // first check warp adapter
    // https://docs.microsoft.com/en-us/windows/win32/direct3darticles/directx-warp

    hr = d3d12_factory.EnumWarpAdapter(xx d3d12_factory, *d3d12_adapter.iid, xx *d3d12_adapter);
    if S_OK == hr {
        // Check to see whether the adapter supports Direct3D 12, but don't create the
        // actual device yet.
        hr = D3D12CreateDevice(xx d3d12_adapter, D3D_FEATURE_LEVEL_12_0, *d3d12_device.iid, null);
        // If ppDevice is NULL and the function succeeds, S_FALSE (0x1) is returned, rather than S_OK.
        if hr == 0x1 {
            warp_adapter_found = true;
        } 
    } else {
        if d3d12_adapter d3d12_adapter.Release(xx d3d12_adapter);
    }

    adapter_index :u32= 0;
    while true && !warp_adapter_found{
        // print("checking: % adapter_index\n", adapter_index);
        if SUCCEEDED(d3d12_factory.EnumAdapters1(xx d3d12_factory, adapter_index, *d3d12_adapter)) {
            // print("found\n");
            desc:DXGI_ADAPTER_DESC1;
            d3d12_adapter.GetDesc1(d3d12_adapter, *desc); 
            // print("desc: %\n", desc);
            // Don't select the Basic Render Driver adapter.
            if (desc.Flags & cast(u32) DXGI_ADAPTER_FLAG_SOFTWARE) continue;
            // Check to see whether the adapter supports Direct3D 12, but don't create the
            // actual device yet.
            hr = D3D12CreateDevice(xx d3d12_adapter, D3D_FEATURE_LEVEL_12_0, *ID3D12Device.iid, null);
            // If ppDevice is NULL and the function succeeds, S_FALSE (0x1) is returned, rather than S_OK.
            if 0x1 == hr then break;
        }
        // Else we won't use this iteration's adapter, so release it
        d3d12_adapter.Release(xx d3d12_adapter);
        adapter_index += 1;
    }

    // Create Device
    // deviceCreationFlags |= D3D11_CREATE_DEVICE_DEBUG;
    hr = D3D12CreateDevice(xx d3d12_adapter, D3D_FEATURE_LEVEL_12_0, *d3d12_device.iid, xx *d3d12_device);
    if hr != S_OK {
        #if ASSERT_ON_FAIL assert(false, "D3D12CreateDevice failed.");
        deinit_d3d12();
        return false;
    }

    #if DEBUG {
        if SUCCEEDED(d3d12_device.QueryInterface(xx d3d12_device, *d3d12_info_queue.iid, xx *d3d12_info_queue)) {
            //  break (while running the .exe in VS)
            #if BREAK_ON_ERROR {
                d3d12_info_queue.SetBreakOnSeverity(d3d12_info_queue, D3D12_MESSAGE_SEVERITY_CORRUPTION, .TRUE);
                d3d12_info_queue.SetBreakOnSeverity(d3d12_info_queue, D3D12_MESSAGE_SEVERITY_ERROR, .TRUE);
            }
            // d3d12_info_queue.SetBreakOnSeverity(d3d12_info_queue, D3D12_MESSAGE_SEVERITY_WARNING, .TRUE);
            // d3d12_info_queue.SetBreakOnSeverity(d3d12_info_queue, D3D12_MESSAGE_SEVERITY_INFO, .TRUE);
            // d3d12_info_queue.SetBreakOnSeverity(d3d12_info_queue, D3D12_MESSAGE_SEVERITY_MESSAGE, .TRUE);

            //  setup
            size := d3d12_info_queue.GetStorageFilterStackSize(d3d12_info_queue);
            while size > 1 {
                d3d12_info_queue.ClearStorageFilter(d3d12_info_queue);
                size = d3d12_info_queue.GetStorageFilterStackSize(d3d12_info_queue);
            }

            size = d3d12_info_queue.GetRetrievalFilterStackSize(d3d12_info_queue);
            while size > 1 {
            d3d12_info_queue.ClearRetrievalFilter(d3d12_info_queue);
            size = d3d12_info_queue.GetRetrievalFilterStackSize(d3d12_info_queue);
            }

            d3d12_info_queue.ClearStoredMessages(d3d12_info_queue);
            d3d12_info_queue.SetMuteDebugOutput(d3d12_info_queue, .FALSE);
        } else {
            print("d3d12_device.QueryInterface faild.\n");
        }
    }

    // Describe and create the command queue.
    queue_desc: D3D12_COMMAND_QUEUE_DESC;
    queue_desc.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE; //D3D12_COMMAND_QUEUE_FLAG_DISABLE_GPU_TIMEOUT;
    queue_desc.Type  = D3D12_COMMAND_LIST_TYPE_DIRECT;
    hr = d3d12_device.CreateCommandQueue(d3d12_device, *queue_desc, *d3d12_queue.iid, xx *d3d12_queue);
    if hr != S_OK {
        #if ASSERT_ON_FAIL assert(false, "d3d12_device.CreateCommandQueue failed.");
        deinit_d3d12();
        return false;
    }

    return true;
}

deinit_d3d12 :: () {
    if d3d12_queue d3d12_queue.Release(xx d3d12_queue);
    #if DEBUG {
        debug_device: *ID3D12DebugDevice;
        ok := d3d12_device.QueryInterface(xx d3d12_device, *debug_device.iid, xx *debug_device);
        if d3d12_device  d3d12_device.Release(xx d3d12_device);
        if ok == S_OK {
            debug_device.ReportLiveDeviceObjects(debug_device, xx (D3D12_RLDO_DETAIL));
            debug_device.Release(xx debug_device);
            print_debug_msgs();
        }
    } else {
        if d3d12_device  d3d12_device.Release(xx d3d12_device);
    }
    if d3d12_info_queue d3d12_info_queue.Release(xx d3d12_info_queue);
    if d3d12_adapter d3d12_adapter.Release(xx d3d12_adapter);
    if d3d12_factory d3d12_factory.Release(xx d3d12_factory);
}

//
// Render Context  -------------------------
//
// swapchain
MAX_SWAPCHAIN_BUFFER_COUNT   :: 3; //  max swapchain buffers (RTVs)
swapchain_buffer_count       : u32; // used backbuffer/framebuffer/RTVs count
swapchain_active_buffer_index: u32; // active backbuffer/framebuffer related to "swapchain_buffer_count" (will be used for next present)
d3d12_swapchain            : *IDXGISwapChain3;

// framebuffers (RTVs)
d3d12_swapchain_rtvs       : [MAX_SWAPCHAIN_BUFFER_COUNT] *ID3D12Resource;
d3d12_swapchain_rtv_heap   : *ID3D12DescriptorHeap;
d3d12_swapchain_rtv_heap_inc_size: u32;

d3d12_render_finished_fence_event: *void;
d3d12_render_finished_fence: *ID3D12Fence;
present_counter: u64;

init_render_context :: (hwnd: *void) -> bool {
    hr: HRESULT;
    // SEE: https://devblogs.microsoft.com/directx/dxgi-flip-model/
    // SEE: https://docs.microsoft.com/en-us/windows/win32/api/dxgi/ne-dxgi-dxgi_swap_effect
    // Describe and create the swap chain.
    #if !VSYNC {
        swapchain_buffer_count = 3;
    } else {
        swapchain_buffer_count = 2; 
    }

    swap_chain_desc: DXGI_SWAP_CHAIN_DESC1;
    swap_chain_desc.BufferCount      = swapchain_buffer_count;
    swap_chain_desc.Width            = xx WIDTH;
    swap_chain_desc.Height           = xx HEIGHT;
    swap_chain_desc.Format           = DXGI_FORMAT_R8G8B8A8_UNORM;
    swap_chain_desc.BufferUsage      = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    swap_chain_desc.SwapEffect       = DXGI_SWAP_EFFECT_FLIP_DISCARD; // NOTE: BufferCount must be > 1 for using "DXGI_SWAP_EFFECT_FLIP_DISCARD/DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL"
    swap_chain_desc.SampleDesc.Count = 1;

    hr = d3d12_factory.CreateSwapChainForHwnd(xx d3d12_factory,
        xx d3d12_queue,    // Swapchain needs the queue so that it can force a flush on it.
        hwnd,
        *swap_chain_desc,
        null,
        null,
        xx *d3d12_swapchain
        );

    if hr != S_OK {
        #if ASSERT_ON_FAIL assert(false, "d3d12_factory.CreateSwapChainForHwnd failed.");
        deinit_render_context();
        return false;
    }

    // This sample does not support fullscreen transitions.
    d3d12_factory.MakeWindowAssociation(xx d3d12_factory, hwnd, DXGI_MWA_NO_ALT_ENTER);

    // Create descriptor heaps.
    {
        // Describe and create a render target view (RTV) descriptor heap.
        rtv_heap_desc: D3D12_DESCRIPTOR_HEAP_DESC;
        rtv_heap_desc.NumDescriptors = swapchain_buffer_count;
        rtv_heap_desc.Type  = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
        rtv_heap_desc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE;
        hr = d3d12_device.CreateDescriptorHeap(d3d12_device, *rtv_heap_desc, *d3d12_swapchain_rtv_heap.iid, xx *d3d12_swapchain_rtv_heap);
        if hr != S_OK {
            #if ASSERT_ON_FAIL assert(false, "d3d12_device.CreateDescriptorHeap failed.");
            deinit_render_context();
            return false;
        }
        d3d12_swapchain_rtv_heap_inc_size = d3d12_device.GetDescriptorHandleIncrementSize(d3d12_device, D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
    }

    // Create frame resources.
    {
        rtv_handle: D3D12_CPU_DESCRIPTOR_HANDLE = d3d12_swapchain_rtv_heap.GetCPUDescriptorHandleForHeapStart(d3d12_swapchain_rtv_heap);
        // Create a RTV for each frame.
        for n:0..swapchain_buffer_count-1 {
            hr = d3d12_swapchain.GetBuffer(xx d3d12_swapchain, xx n, *d3d12_swapchain_rtvs[n].iid, xx *d3d12_swapchain_rtvs[n]);
            if hr != S_OK {
                #if ASSERT_ON_FAIL assert(false, "d3d12_swapchain.GetBuffer failed.");
                deinit_render_context();
                return false;
            }
            d3d12_device.CreateRenderTargetView(xx d3d12_device, d3d12_swapchain_rtvs[n], null, rtv_handle);
            rtv_handle.ptr += (1 * d3d12_swapchain_rtv_heap_inc_size);
        }
    }

    // Create synchronization objects
    hr = d3d12_device.CreateFence(d3d12_device, 0, D3D12_FENCE_FLAG_NONE, *d3d12_render_finished_fence.iid, xx *d3d12_render_finished_fence);
    if hr != S_OK {
        #if ASSERT_ON_FAIL assert(false, "d3d12_device.CreateFence failed.");
        deinit_render_context();
        return false;
    }

    // Create an event handle to use for frame synchronization.
     d3d12_render_finished_fence_event := CreateEventW(null, 0, 0, null);
    if d3d12_render_finished_fence_event == null {
        #if ASSERT_ON_FAIL assert(false, "CreateEventW failed.");
        deinit_render_context();
        return false;
    }

    // set the backbuffer index for next present.
    swapchain_active_buffer_index = d3d12_swapchain.GetCurrentBackBufferIndex(d3d12_swapchain);

    return true;
}

present_render_context :: () {
    // Present the frame. ()
    #if VSYNC {
        d3d12_swapchain.Present(xx d3d12_swapchain, 1, 0);
    } else {
        d3d12_swapchain.Present(xx d3d12_swapchain, 0, 0);
    }
    present_counter += 1;
    // Signal and increment the fence value.
    d3d12_queue.Signal(d3d12_queue, d3d12_render_finished_fence, present_counter);
    // set the backbuffer index for next present.
    swapchain_active_buffer_index = d3d12_swapchain.GetCurrentBackBufferIndex(d3d12_swapchain);
}

deinit_render_context :: () {
    // vv := d3d12_render_finished_fence.GetCompletedValue(d3d12_render_finished_fence);
    // print("d3d12_render_finished_fence: % - present_counter: %\n", vv, present_counter);
    { // wait for all RTVs
        wait_value := present_counter;
        if (d3d12_render_finished_fence.GetCompletedValue(d3d12_render_finished_fence) < wait_value) {
            d3d12_render_finished_fence.SetEventOnCompletion(d3d12_render_finished_fence, wait_value, d3d12_render_finished_fence_event);
            WaitForSingleObject(d3d12_render_finished_fence_event, 0xffff_ffff); // 0xffff_ffff is U32_MAX
        }
    }
    for 0..swapchain_buffer_count-1 {
        if d3d12_swapchain_rtvs[it] d3d12_swapchain_rtvs[it].Release(xx d3d12_swapchain_rtvs[it]);
    }
    if d3d12_swapchain_rtv_heap d3d12_swapchain_rtv_heap.Release(xx d3d12_swapchain_rtv_heap);
    if d3d12_swapchain d3d12_swapchain.Release(xx d3d12_swapchain);
    if d3d12_render_finished_fence d3d12_render_finished_fence.Release(xx d3d12_render_finished_fence);
}

//
// Pipeline --------------------------------------
//

d3d12_root_signature : *ID3D12RootSignature;
d3d12_pipeline_state : *ID3D12PipelineState;

init_pipeline :: () -> bool {
    hr: HRESULT;
    pipeline_desc: D3D12_GRAPHICS_PIPELINE_STATE_DESC;
    // Create an empty root signature.
    // NOTE: see https://alain.xyz/blog/raw-directx12 if you want to use Root Signature Version 1.1
    root_signature_desc: D3D12_ROOT_SIGNATURE_DESC;
    root_signature_desc.NumParameters = 0;
    root_signature_desc.pParameters = null;
    root_signature_desc.NumStaticSamplers = 0;
    root_signature_desc.pStaticSamplers = null;
    //root_signature_desc.Flags = D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT; Since we do not use vertex buffer
    signature: *ID3DBlob;
    error: *ID3DBlob;
    hr = D3D12SerializeRootSignature(*root_signature_desc, D3D_ROOT_SIGNATURE_VERSION_1, xx *signature, xx *error);
    if hr != S_OK {
        #if ASSERT_ON_FAIL assert(false, "D3D12SerializeRootSignature failed.");
        deinit_pipeline();
        return false;
    }
    hr = d3d12_device.CreateRootSignature(xx d3d12_device, 0, signature.GetBufferPointer(signature), signature.GetBufferSize(signature), *d3d12_root_signature.iid, xx *d3d12_root_signature);
    if hr != S_OK {
        #if ASSERT_ON_FAIL assert(false, "d3d12_device.CreateRootSignature failed.");
        deinit_pipeline();
        return false;
    }

    pipeline_desc.pRootSignature = d3d12_root_signature;

    // SHADERS
    // vertex shader
    _vs_bytecode := compile_shader(SHADER_TEXT, "VSMain", "vs_5_0");
    vs_bytecode : D3D12_SHADER_BYTECODE;
    vs_bytecode.pShaderBytecode = _vs_bytecode.data;
    vs_bytecode.BytecodeLength  = xx _vs_bytecode.count;
    // fragment shader
    _ps_bytecode := compile_shader(SHADER_TEXT, "PSMain", "ps_5_0");
    ps_bytecode : D3D12_SHADER_BYTECODE;
    ps_bytecode.pShaderBytecode = _ps_bytecode.data;
    ps_bytecode.BytecodeLength  = xx _ps_bytecode.count;

    pipeline_desc.VS = vs_bytecode;
    pipeline_desc.PS = ps_bytecode;

    // VERTEX LAYOUT
    pipeline_desc.InputLayout.pInputElementDescs = null;
    pipeline_desc.InputLayout.NumElements        = 0;

    // TOPOLOGY
    pipeline_desc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;

    // RASTERIZATION STATE (rester)
    raster_desc: D3D12_RASTERIZER_DESC;
    raster_desc.FillMode = D3D12_FILL_MODE_SOLID;
    raster_desc.CullMode = D3D12_CULL_MODE_NONE;
    raster_desc.FrontCounterClockwise = .FALSE;
    raster_desc.DepthBias = 0; //D3D12_DEFAULT_DEPTH_BIAS;
    raster_desc.DepthBiasClamp = 0; //D3D12_DEFAULT_DEPTH_BIAS_CLAMP;
    raster_desc.SlopeScaledDepthBias = 0; //D3D12_DEFAULT_SLOPE_SCALED_DEPTH_BIAS;
    raster_desc.DepthClipEnable = .TRUE;
    raster_desc.MultisampleEnable = .FALSE;
    raster_desc.AntialiasedLineEnable = .FALSE;

    pipeline_desc.RasterizerState = raster_desc;

    // DEPTH/Stencil State
    pipeline_desc.DepthStencilState.DepthEnable = .FALSE;
    pipeline_desc.DepthStencilState.StencilEnable = .FALSE;
    pipeline_desc.SampleMask = 0xffff_ffff; // U32_MAX

    // BLEND STATE
    blend_desc: D3D12_BLEND_DESC;
    blend_desc.AlphaToCoverageEnable = .FALSE;
    blend_desc.IndependentBlendEnable = .FALSE;
    def_rtv_blend_desc := D3D12_RENDER_TARGET_BLEND_DESC.{
        .FALSE,
        .FALSE,
        D3D12_BLEND_ONE,
        D3D12_BLEND_ZERO,
        D3D12_BLEND_OP_ADD,
        D3D12_BLEND_ONE,
        D3D12_BLEND_ZERO,
        D3D12_BLEND_OP_ADD,
        D3D12_LOGIC_OP_NOOP,
        cast(u8) D3D12_COLOR_WRITE_ENABLE_ALL,
    };
    for i : 0..D3D12_SIMULTANEOUS_RENDER_TARGET_COUNT-1 blend_desc.RenderTarget[i] = def_rtv_blend_desc;
    
    pipeline_desc.BlendState = blend_desc;

    // Output
    pipeline_desc.NumRenderTargets = 1;
    pipeline_desc.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM;
    pipeline_desc.SampleDesc.Count = 1;
        
    hr = d3d12_device.CreateGraphicsPipelineState(d3d12_device, *pipeline_desc, *d3d12_pipeline_state.iid, xx *d3d12_pipeline_state);
    if hr != S_OK {
        #if ASSERT_ON_FAIL assert(false, "d3d12_device.CreateGraphicsPipelineState failed.");
        deinit_pipeline();
        return false;
    }
    return true;
}

deinit_pipeline :: () {
    if d3d12_root_signature d3d12_root_signature.Release(xx d3d12_root_signature);
    if d3d12_pipeline_state d3d12_pipeline_state.Release(xx d3d12_pipeline_state);
}

//
// Command Lists --------------------------------------
//
d3d12_command_allocator: *ID3D12CommandAllocator;
d3d12_command_lists    : [FRAME_COUNT] *ID3D12GraphicsCommandList;

d3d12_fence_event: *void;
d3d12_fence     : *ID3D12Fence;
// d3d12_fenceValue: u64;

init_command_lists :: () -> bool {
    hr: HRESULT;
    hr = d3d12_device.CreateCommandAllocator(xx d3d12_device, D3D12_COMMAND_LIST_TYPE_DIRECT, *d3d12_command_allocator.iid, xx *d3d12_command_allocator);
    if hr != S_OK {
        #if ASSERT_ON_FAIL assert(false, "d3d12_device.CreateCommandAllocator failed.");
        deinit_command_lists();
        return false;
    }

    // Create the command lists.
    for i: 0..FRAME_COUNT-1 {
        hr = d3d12_device.CreateCommandList(d3d12_device, 0, D3D12_COMMAND_LIST_TYPE_DIRECT, d3d12_command_allocator, d3d12_pipeline_state, *d3d12_command_lists[i].iid, xx *d3d12_command_lists[i]);
        if hr != S_OK {
            #if ASSERT_ON_FAIL assert(false, "d3d12_device.CreateCommandList failed.");
            deinit_command_lists();
            return false;
        }
        // Command lists are created in the recording state, but there is nothing
        // to record yet. The main loop expects it to be closed, so close it now.
        d3d12_command_lists[i].Close(d3d12_command_lists[i]);
    }

    // Create synchronization objects
    hr = d3d12_device.CreateFence(d3d12_device, 0, D3D12_FENCE_FLAG_NONE, *d3d12_fence.iid, xx *d3d12_fence);
    if hr != S_OK {
        #if ASSERT_ON_FAIL assert(false, "d3d12_device.CreateFence failed.");
        deinit_command_lists();
        return false;
    }

    // Create an event handle to use for frame synchronization.
     d3d12_fence_event := CreateEventW(null, 0, 0, null);
    if d3d12_fence_event == null {
        #if ASSERT_ON_FAIL assert(false, "CreateEventW failed.");
        deinit_command_lists();
        return false;
    }

    return true;
}

deinit_command_lists :: () {
    if d3d12_command_allocator d3d12_command_allocator.Reset(d3d12_command_allocator);
    for 0..FRAME_COUNT-1 {
        if d3d12_command_lists[it] d3d12_command_lists[it].Release(xx d3d12_command_lists[it]);
    }
    if d3d12_command_allocator d3d12_command_allocator.Release(xx d3d12_command_allocator);
    if d3d12_fence             d3d12_fence.Release(xx d3d12_fence);
}

//
// Utils -----------------------------------
//


print_debug_msgs :: () {
    if !d3d12_info_queue return;
    msgs_count := d3d12_info_queue.GetNumStoredMessages(d3d12_info_queue);
    // print("msgs_count: %\n", msgs_count);
    if msgs_count == 0 return;

    for 0..msgs_count-1 {
        size: u64;
        hr := d3d12_info_queue.GetMessage(d3d12_info_queue, it, null, *size);

        // WRNING: This is dummy you should never alloc and free for each msg, but this just an example
        // You shall find better way.
        msg: *D3D12_MESSAGE = xx alloc(xx size);
        defer free(msg);
        hr = d3d12_info_queue.GetMessage(d3d12_info_queue, it, msg, *size);

        str: string;
        str.data  = msg.pDescription;
        str.count = xx msg.DescriptionByteLength;

        prefix: string;
        if  msg.Severity == {
            case .D3D12_MESSAGE_SEVERITY_CORRUPTION; prefix = "CORRUPTION";
            case .D3D12_MESSAGE_SEVERITY_ERROR;      prefix = "ERROR";
            case .D3D12_MESSAGE_SEVERITY_WARNING;    prefix = "WARNING";
            case .D3D12_MESSAGE_SEVERITY_INFO;       prefix = "INFO";
            case .D3D12_MESSAGE_SEVERITY_MESSAGE;    prefix = "MESSAGE";
        }

        category: string;
        if  msg.Category == {
            case .D3D12_MESSAGE_CATEGORY_APPLICATION_DEFINED;   category = "APPLICATION_DEFINED";
            case .D3D12_MESSAGE_CATEGORY_MISCELLANEOUS;         category = "MISCELLANEOUS";
            case .D3D12_MESSAGE_CATEGORY_INITIALIZATION;        category = "INITIALIZATION";
            case .D3D12_MESSAGE_CATEGORY_CLEANUP;               category = "CLEANUP";
            case .D3D12_MESSAGE_CATEGORY_COMPILATION;           category = "COMPILATION";
            case .D3D12_MESSAGE_CATEGORY_STATE_CREATION;        category = "STATE_CREATION";
            case .D3D12_MESSAGE_CATEGORY_STATE_SETTING;         category = "STATE_SETTING";
            case .D3D12_MESSAGE_CATEGORY_STATE_GETTING;         category = "STATE_GETTING";
            case .D3D12_MESSAGE_CATEGORY_RESOURCE_MANIPULATION; category = "RESOURCE_MANIPULATION";
            case .D3D12_MESSAGE_CATEGORY_EXECUTION;             category = "EXECUTION";
            case .D3D12_MESSAGE_CATEGORY_SHADER;                category = "SHADER";
        }

        print("[D3D12][%]:% - %, \n", prefix, category, msg.ID);
        print("%\n", str);
    }

    d3d12_info_queue.ClearStoredMessages(d3d12_info_queue);
}

print_hr :: (hr: HRESULT) {
    if hr == {
    case S_OK;            print("S_OK\n");
    case E_FAIL;          print("E_FAIL\n");
    case E_NOTIMPL;       print("E_NOTIMPL\n");
    case E_NOINTERFACE;   print("E_NOINTERFACE\n");
    case E_POINTER;       print("E_POINTER\n");
    case E_ABORT;         print("E_ABORT\n");
    case E_ACCESSDENIED;  print("E_ACCESSDENIED\n");
    case E_HANDLE;        print("E_HANDLE\n");
    case E_OUTOFMEMORY;   print("E_OUTOFMEMORY\n");
    case E_INVALIDARG;    print("E_INVALIDARG\n");
    case E_UNEXPECTED;    print("E_UNEXPECTED\n");
    case; print("Unknown");
    }
}

compile_shader :: (source: string, entry_point: string, shader_model: string) -> string, HRESULT {
    flags := D3dcompiler.D3DCOMPILE_ENABLE_STRICTNESS; 

    #if DEBUG {
        // Set the D3DCOMPILE_DEBUG flag to embed debug information in the shaders. 
        // Setting this flag improves the shader debugging experience, but still allows  
        // the shaders to be optimized and to run exactly the way they will run in  
        // the release configuration of this program. 
        flags |= D3dcompiler.D3DCOMPILE_DEBUG; 
        // Disable optimizations to further improve shader debugging 
        flags |= D3dcompiler.D3DCOMPILE_SKIP_OPTIMIZATION; 
    }
 
    defines: [] string;
    bytecode, errors, hr := D3dcompiler.D3DCompile(source, "source", defines, null, entry_point, shader_model, xx flags, 0);
    defer free(errors);

    if FAILED(hr) { 
        free(bytecode);
        if errors print ("Error msg: %\n", errors);
        return "", hr;
    } 
    
    return bytecode, hr;
}

SHADER_TEXT :: #string DONE
struct PSInput
{
    float4 position : SV_POSITION;
    float4 color    : COLOR;
};

static float2 positions[3] = {
    float2(0.0, 0.5),
    float2(0.5, -0.5),
    float2(-0.5, -0.5)
};

static float3 colors[3] = {
    float3(1.0, 0.0, 0.0),
    float3(0.0, 1.0, 0.0),
    float3(0.0, 0.0, 1.0)
};


PSInput VSMain(uint vertex_id: SV_VERTEXID)
{
    PSInput result;
    result.position = float4(positions[vertex_id], 0.0, 1.0);
    result.color    = float4(colors[vertex_id], 1.0);

    return result;
}

float4 PSMain(PSInput input) : SV_TARGET
{
    return input.color;
}
DONE;