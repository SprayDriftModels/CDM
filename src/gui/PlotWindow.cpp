// Copyright (c) 2021 John Buonagurio <jbuonagurio@exponent.com>

#include <d3d11.h>
#include <tchar.h>

#include <imgui.h>
#include <imgui_impl_win32.h>
#include <imgui_impl_dx11.h>
#include <imgui_freetype.h>
#include <implot.h>

#include "SegoeUI.hpp"
#include "PlotWindow.hpp"

LRESULT WINAPI WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
extern IMGUI_IMPL_API LRESULT ImGui_ImplWin32_WndProcHandler(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

namespace cdm {
namespace gui {

static ID3D11Device*            g_pd3dDevice = NULL;
static ID3D11DeviceContext*     g_pd3dDeviceContext = NULL;
static IDXGISwapChain*          g_pSwapChain = NULL;
static ID3D11RenderTargetView*  g_mainRenderTargetView = NULL;

static void InitBaseStyles();
static void InitPlotStyles();
static bool CreateDeviceD3D(HWND hWnd);
static void CleanupDeviceD3D();
static void CreateRenderTarget();
static void CleanupRenderTarget();

static void InitBaseStyles()
{
    ImGuiStyle *style = &ImGui::GetStyle();
    style->WindowPadding           = ImVec2(14,14);    // Padding within a window
    style->WindowRounding          = 0.0f;             // Radius of window corners rounding.
    style->WindowBorderSize        = 0.0f;             // Thickness of border around windows.
    style->FramePadding            = ImVec2(4,4);      // Padding within a frame rectangle.
    style->FrameRounding           = 4.0f;             // Radius of frame corners rounding.
    style->FrameBorderSize         = 0.0f;             // Thickness of border around frames.
    style->ItemSpacing             = ImVec2(12,8);     // Horizontal and vertical spacing between widgets/lines.
    style->ItemInnerSpacing        = ImVec2(8,6);      // Horizontal and vertical spacing between within elements of a composed widget (e.g. a slider and its label).
    style->CellPadding             = ImVec2(4,2);      // Padding within a table cell
    style->ColumnsMinSpacing       = 6.0f;             // Minimum horizontal spacing between two columns. Preferably > (FramePadding.x + 1).
    style->IndentSpacing           = 24.0f;            // Horizontal spacing when e.g. entering a tree node. Generally == (FontSize + FramePadding.x*2).
    style->ScrollbarSize           = 15.0f;            // Width of the vertical scrollbar, Height of the horizontal scrollbar
    style->ScrollbarRounding       = 9.0f;             // Radius of grab corners rounding for scrollbar
    style->GrabMinSize             = 5.0f;             // Minimum width/height of a grab box for slider/scrollbar
    style->GrabRounding            = 0.0f;             // Radius of grabs corners rounding. Set to 0.0f to have rectangular slider grabs.
    style->AntiAliasedLines        = true;             // Enable anti-aliased lines/borders.
    style->AntiAliasedLinesUseTex  = true;             // Enable anti-aliased lines/borders using textures where possible. Require backend to render with bilinear filtering.
    style->AntiAliasedFill         = true;             // Enable anti-aliased filled shapes (rounded rectangles, circles, etc.).
}

static void InitPlotStyles()
{
    ImPlotStyle *style = &ImPlot::GetStyle();
    style->LineWeight              = 1.5;
    style->Marker                  = ImPlotMarker_None;
    style->MarkerSize              = 6;
    style->MarkerWeight            = 1.5;
    style->MinorAlpha              = 0.25f;
    style->MajorTickLen            = ImVec2(10,10);
    style->MinorTickLen            = ImVec2(5,5);
    style->MajorTickSize           = ImVec2(1,1);
    style->MinorTickSize           = ImVec2(1,1);
    style->MajorGridSize           = ImVec2(1,1);
    style->MinorGridSize           = ImVec2(1,1);
    style->PlotPadding             = ImVec2(10,10);
    style->LabelPadding            = ImVec2(5,5);
    style->LegendPadding           = ImVec2(10,10);
    style->LegendInnerPadding      = ImVec2(5,5);
    style->LegendSpacing           = ImVec2(5,5);
    style->MousePosPadding         = ImVec2(10,10);
    style->AnnotationPadding       = ImVec2(2,2);
    style->FitPadding              = ImVec2(0,0);
    style->PlotDefaultSize         = ImVec2(400,300);
    style->PlotMinSize             = ImVec2(200,150);
}

void ShowPlotWindow(const std::vector<std::pair<double, double>>& dsd0,
                    const std::vector<std::pair<double, double>>& dsd1)
{
    // Create application window.
    ImGui_ImplWin32_EnableDpiAwareness();
    WNDCLASSEX wc = { sizeof(WNDCLASSEX), CS_CLASSDC, WndProc, 0L, 0L, GetModuleHandle(NULL), NULL, NULL, NULL, NULL, _T("ImGui Example"), NULL };
    ::RegisterClassEx(&wc);
    HWND hwnd = ::CreateWindow(wc.lpszClassName, _T("Droplet Size Distribution"), WS_OVERLAPPEDWINDOW, 100, 100, 1280, 768, NULL, NULL, wc.hInstance, NULL);

    // Initialize Direct3D.
    if (!CreateDeviceD3D(hwnd)) {
        CleanupDeviceD3D();
        ::UnregisterClass(wc.lpszClassName, wc.hInstance);
        return;
    }

    // Show the window.
    ::ShowWindow(hwnd, SW_SHOWDEFAULT);
    ::UpdateWindow(hwnd);

    // Setup context.
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImPlot::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); (void)io;
    //io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;

    // Setup initial styles.
    InitBaseStyles();
    InitPlotStyles();
    ImGui::StyleColorsDark();
    ImPlot::StyleColorsDark();
    
    // Setup platform/renderer backends.
    ImGui_ImplWin32_Init(hwnd);
    ImGui_ImplDX11_Init(g_pd3dDevice, g_pd3dDeviceContext);

    // Load compressed font.
    static const ImWchar glyph_ranges[] = {
        0x0020, 0x00FF, // Basic Latin + Latin Supplement
        0x0370, 0x03FF, // Greek and Coptic
        0
    };
    ImFont* font = io.Fonts->AddFontFromMemoryCompressedTTF(segoeui_compressed_data, segoeui_compressed_size, 24.0f, NULL, &glyph_ranges[0]);
    IM_ASSERT(font != NULL);

    // Application state.
    //bool show_app_style_editor = false;
    //bool show_plot_style_editor = false;
    bool done = false;
    
    // Main loop.
    while (!done)
    {
        MSG msg;
        while (::PeekMessage(&msg, NULL, 0U, 0U, PM_REMOVE)) {
            ::TranslateMessage(&msg);
            ::DispatchMessage(&msg);
            if (msg.message == WM_QUIT)
                done = true;
        }
        if (done)
            break;

        ImGui_ImplDX11_NewFrame();
        ImGui_ImplWin32_NewFrame();
        ImGui::NewFrame();
        
        const ImGuiViewport *viewport = ImGui::GetMainViewport();
        
        // Create the menu bar.
        if (ImGui::BeginMainMenuBar()) {
            if (ImGui::BeginMenu("File")) {
                if (ImGui::MenuItem("Close")) { done = true; }
                ImGui::EndMenu();
            }
            if (ImGui::BeginMenu("Tools")) {
                if (ImGui::BeginMenu("Color Theme")) {
                    if (ImGui::MenuItem("Dark")) {
                        ImGui::StyleColorsDark();
                        ImPlot::StyleColorsDark();
                    }
                    if (ImGui::MenuItem("Light")) {
                        ImGui::StyleColorsLight();
                        ImPlot::StyleColorsLight();
                    }
                    ImGui::EndMenu();
                }
                //ImGui::MenuItem("Global Style Editor...", NULL, &show_app_style_editor);
                //ImGui::MenuItem("Plot Style Editor...", NULL, &show_plot_style_editor);
                ImGui::EndMenu();
            }
            ImGui::EndMainMenuBar();
        }
        
        //if (show_app_style_editor) {
        //    ImGui::SetNextWindowPos(viewport->WorkPos);
        //    ImGui::SetNextWindowSize(viewport->WorkSize);
        //    if (ImGui::Begin("Global Style Editor", &show_app_style_editor)) {
        //        ImGui::ShowStyleEditor();
        //        ImGui::End();
        //    }
        //}
        //
        //if (show_plot_style_editor) {
        //    ImGui::SetNextWindowPos(viewport->WorkPos);
        //    ImGui::SetNextWindowSize(viewport->WorkSize);
        //    if (ImGui::Begin("Plot Style Editor", &show_plot_style_editor)) {
        //        ImPlot::ShowStyleEditor();
        //        ImGui::End();
        //    }
        //}
        
        // Create the main window.
        const ImGuiWindowFlags flags = ImGuiWindowFlags_NoDecoration |
                                       ImGuiWindowFlags_NoMove |
                                       ImGuiWindowFlags_NoResize |
                                       ImGuiWindowFlags_NoBringToFrontOnFocus |
                                       ImGuiWindowFlags_NoNavFocus |
                                       ImGuiWindowFlags_NoSavedSettings;
        
        ImGui::SetNextWindowPos(viewport->WorkPos);
        ImGui::SetNextWindowSize(viewport->WorkSize);
        
        // Update FrameBg color to match background.
        const ImVec4 bgcol = ImGui::GetStyleColorVec4(ImGuiCol_WindowBg);
        const float bgcol_alpha[4] = { bgcol.x * bgcol.w, bgcol.y * bgcol.w, bgcol.z * bgcol.w, bgcol.w };
        ImGui::PushStyleColor(ImGuiCol_FrameBg, bgcol);
        ImPlot::PushStyleColor(ImPlotCol_FrameBg, bgcol);
        
        // Add the plot items. Use striding with ImPlot::PlotLine to use the AoS data structure (vector of pairs) directly.
        if (ImGui::Begin("Plot", NULL, flags)) {
            //ImGui::Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0f / ImGui::GetIO().Framerate, ImGui::GetIO().Framerate);
            if (ImPlot::BeginPlot("Droplet Size Distribution", u8"Droplet Size (\u03BCm)", "Proportion", ImVec2(-1,-1), ImPlotFlags_NoTitle | ImPlotFlags_AntiAliased | ImPlotFlags_Crosshairs)) {
                ImPlot::SetNextMarkerStyle(ImPlotMarker_Circle);
                ImPlot::PlotScatter(" Input Data", &dsd0[0].first, &dsd0[0].second, dsd0.size(), 0, sizeof(std::pair<double,double>));
                ImPlot::SetNextMarkerStyle(ImPlotMarker_None);
                ImPlot::PlotLine(" Calibrated", &dsd1[0].first, &dsd1[0].second, dsd1.size(), 0, sizeof(std::pair<double,double>));
                ImPlot::EndPlot();
            }
            ImGui::End();
        }
        
        // Restore FrameBg color.
        ImPlot::PopStyleColor(1);
        ImGui::PopStyleColor(1);
        
        // Rendering.
        ImGui::Render();
        g_pd3dDeviceContext->OMSetRenderTargets(1, &g_mainRenderTargetView, NULL);
        g_pd3dDeviceContext->ClearRenderTargetView(g_mainRenderTargetView, bgcol_alpha);
        ImGui_ImplDX11_RenderDrawData(ImGui::GetDrawData());
        g_pSwapChain->Present(1, 0); // Enable vsync.
    }

    // Cleanup
    ImGui_ImplDX11_Shutdown();
    ImGui_ImplWin32_Shutdown();
    ImPlot::DestroyContext();
    ImGui::DestroyContext();

    CleanupDeviceD3D();
    ::DestroyWindow(hwnd);
    ::UnregisterClass(wc.lpszClassName, wc.hInstance);
}

static bool CreateDeviceD3D(HWND hWnd)
{
    // Setup swap chain.
    DXGI_SWAP_CHAIN_DESC sd;
    ZeroMemory(&sd, sizeof(sd));
    sd.BufferCount = 2;
    sd.BufferDesc.Width = 0;
    sd.BufferDesc.Height = 0;
    sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    sd.BufferDesc.RefreshRate.Numerator = 60;
    sd.BufferDesc.RefreshRate.Denominator = 1;
    sd.Flags = DXGI_SWAP_CHAIN_FLAG_ALLOW_MODE_SWITCH;
    sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    sd.OutputWindow = hWnd;
    sd.SampleDesc.Count = 1;
    sd.SampleDesc.Quality = 0;
    sd.Windowed = TRUE;
    sd.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;

    UINT createDeviceFlags = 0; // D3D11_CREATE_DEVICE_DEBUG;
    D3D_FEATURE_LEVEL featureLevel;
    const D3D_FEATURE_LEVEL featureLevelArray[2] = { D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_0 };
    if (D3D11CreateDeviceAndSwapChain(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, createDeviceFlags, featureLevelArray, 2, D3D11_SDK_VERSION, &sd, &g_pSwapChain, &g_pd3dDevice, &featureLevel, &g_pd3dDeviceContext) != S_OK)
        return false;

    CreateRenderTarget();
    return true;
}

static void CleanupDeviceD3D()
{
    CleanupRenderTarget();
    if (g_pSwapChain) { g_pSwapChain->Release(); g_pSwapChain = NULL; }
    if (g_pd3dDeviceContext) { g_pd3dDeviceContext->Release(); g_pd3dDeviceContext = NULL; }
    if (g_pd3dDevice) { g_pd3dDevice->Release(); g_pd3dDevice = NULL; }
}

static void CreateRenderTarget()
{
    ID3D11Texture2D* pBackBuffer;
    g_pSwapChain->GetBuffer(0, IID_PPV_ARGS(&pBackBuffer));
    g_pd3dDevice->CreateRenderTargetView(pBackBuffer, NULL, &g_mainRenderTargetView);
    pBackBuffer->Release();
}

static void CleanupRenderTarget()
{
    if (g_mainRenderTargetView) { g_mainRenderTargetView->Release(); g_mainRenderTargetView = NULL; }
}

} // namespace gui
} // namespace cdm

LRESULT WINAPI WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    using namespace cdm::gui;

    if (ImGui_ImplWin32_WndProcHandler(hWnd, msg, wParam, lParam))
        return true;

    switch (msg) {
    case WM_SIZE:
        if (g_pd3dDevice != NULL && wParam != SIZE_MINIMIZED)
        {
            CleanupRenderTarget();
            g_pSwapChain->ResizeBuffers(0, (UINT)LOWORD(lParam), (UINT)HIWORD(lParam), DXGI_FORMAT_UNKNOWN, 0);
            CreateRenderTarget();
        }
        return 0;
    case WM_SYSCOMMAND:
        if ((wParam & 0xfff0) == SC_KEYMENU) // Disable ALT application menu
            return 0;
        break;
    case WM_DESTROY:
        ::PostQuitMessage(0);
        return 0;
    }
    return ::DefWindowProc(hWnd, msg, wParam, lParam);
}
