module benq;
import std::io;
import std::os::process;
import std::collections::list;
import nuklear;
import nuklear_sdl_gl3;
import std::thread::channel;

struct Monitor {
    String model;
    String manufacturer;

    String device_path; // /dev/i2c-*
}

enum InputSource {
    DP,
    HDMI1,
    HDMI2,
}

struct ColorGain {
    int red;
    int green;
    int blue;
}

constdef DisplayMode : uint {
    M_BOOK    = 0x0f,
    CINEMA    = 0x32,
    GAME      = 0x28,
    EPAPER    = 0x27,
    USER      = 0x12,
    STANDARD  = 0x00,
    CODING    = 0x27,
    CARE_MODE = 0x27
}

struct MonitorState {
    uint brightness;
    uint max_brightness;
    uint contrast;
    uint max_contrast;
    DisplayMode display_mode;
    ColorTemperature color_temperature;
    UserDefine user_define_color;
    uint volume;
    // 
    // bool muted;
    // 
    // InputSource input;
    // 
    // ColorGain gain;
}

struct UserDefine {
    uint r;
    uint g;
    uint b;
}

const COLOR_TEMPERATURE_REQUEST = "0x0c";
// Well this ain't working, we have to write to 0x0c, values are:



// 28 - 5000K - Reddish - 0x04

// 35 - 6500K - Normal - 0x05

// 63 - 9300K - Bluish - 0x08

// 35 * (r,g,b) - UserDefine - 0x0b

constdef ColorTemperature : uint {
    NORMAL      = 35,
    BLUISH      = 63,
    REDDISH     = 28,
    USER_DEFINE = 11,
}

enum AudioScenario {
    STANDARD,
    MUSIC,
    DIALOGUE
}

enum EyeReminder {
    OFF,
    THIRTY_MIN,
    FORTYFIVE_MIN,
    SIXTRY_MIN
}

struct MonitorSettings {
    // Display
    int brightness;
    int contrast;
    int sharpness;

    // Input
    InputSource input;

    // Color
    DisplayMode color_mode;
    ColorTemperature color_temp;
    // Gamma gamma;

    // Audio
    int volume;
    bool mute;
    AudioScenario audio_scenario;

    // Eye Care
    bool bi_gen2;
    // LowBlueLightPlus low_blue_light_plus;
    EyeReminder eye_reminder;
}

enum VcpKind {
    RANGE,
    ENUM_VAL,
    BOOL_VAL,
    RAW,
    MULTI,
    UNSUPPORTED,
}

struct VcpValue {
    VcpKind kind;
    union data {
        uint[2] range_val;
        uint[] multiple_val;
        String enum_val;
        EnumValue color_val;
        bool bool_val;
        uint raw_val;
    }
}

struct EnumValue {
    ColorTemperature preset;
    UserDefine rgb;
}

struct VcpInfo {
    String code;
    String name;
    VcpValue value;
}

faultdef CMD_RUN_FAILED;

fn VcpInfo? get_vcp(String code, String bus) => @pool() {
    char[1024] buf;

    String? output   = process::run_capture_stdout(
        &buf,
        { "ddcutil", "getvcp", code, "--bus", bus }
    );
    VcpInfo vcp_info = { };
    VcpValue vcp_val = { };

    if (catch output) return CMD_RUN_FAILED~;

    String line = output.trim();
    if (line.contains("current value") && line.contains("max value")) {
        long? idx1 = line.index_of("(")!;
        long? idx2 = line.index_of(")")!;

        if (catch idx1) vcp_info.name = "unknown".copy(mem);
        if (catch idx2) vcp_info.name = "unknown".copy(mem);

        vcp_info.name = line[idx1 + 1..idx2 - 1]!.trim().copy(mem);
        vcp_val.kind = VcpKind.RANGE;
        vcp_info.code = code;

        String[] parts = line.split(tmem, ",");
        vcp_val.data.range_val[0] = (uint)parts[0].split(tmem, "=")[1].trim().to_int()!;
        vcp_val.data.range_val[1] = (uint)parts[1].split(tmem, "=")[1].trim().to_int()!;
        vcp_info.value = vcp_val;
    }

    if (line.contains("Display Mode")) {
        long? idx  = line.index_of("=")!;
        long? idx2 = line.rindex_of(")")!;

        if (catch idx) vcp_info.name = "unknown".copy(mem);
        if (catch idx2) vcp_info.name = "unknown".copy(mem);

        vcp_val.kind = VcpKind.ENUM_VAL;
        vcp_info.code = code;
        vcp_val.data.enum_val = line[idx + 1..idx2 - 1]!;
        vcp_info.name = color_mode_to_string(convert_da_thing(vcp_val.data.enum_val));
        vcp_info.value = vcp_val;
    }

    if (line.contains("0x14")) {
        vcp_val.kind = VcpKind.ENUM_VAL;
        vcp_info.code = code;

        if (line.contains("6500")) {
            vcp_val.data.color_val.preset = NORMAL;
            vcp_info.name = "Normal";
        } else if (line.contains("5000")) {
            vcp_val.data.color_val.preset = REDDISH;
            vcp_info.name = "Reddish";
        } else if (line.contains("9300")) {
            vcp_val.data.color_val.preset = BLUISH;
            vcp_info.name = "Bluish";
        } else {
            vcp_val.data.color_val.rgb = get_user_define_vals();
            vcp_val.data.color_val.preset = USER_DEFINE;
            vcp_info.name = "User Define";
        }

        vcp_info.value = vcp_val;
    }

    if (line.contains("0x62")) {
        vcp_val.kind = VcpKind.RAW;
        vcp_info.code = code;
        long? idx  = line.rindex_of(":");
        long? idx1 = line.rindex_of("(");
        if (catch idx) vcp_val.data.raw_val = 0;
        if (catch idx1) vcp_val.data.raw_val = 0;
        vcp_val.data.raw_val = line[idx + 1..idx1 - 1]!.trim().to_char()!;
        vcp_info.name = "Volume";
        vcp_info.value = vcp_val;
    }

    return vcp_info;
}

fn UserDefine get_user_define_vals() {
    UserDefine ud;
    ud.r = get_vcp(VIDEO_GAIN_RED, "2").value.data.range_val[0]!!;
    ud.g = get_vcp(VIDEO_GAIN_GREEN, "2").value.data.range_val[0]!!;
    ud.b = get_vcp(VIDEO_GAIN_BLUE, "2").value.data.range_val[0]!!;

    return ud;
}

fn bool load_monitor_state(BufferedChannel{MonitorState}* monitor_state_channel) {
    LibcAllocator libc;

    @pool_init(&libc, 1024) {
        MonitorState ms      = { };
        VcpInfo brightness   = get_vcp(BRIGHTNESS, "2")!!;
        VcpInfo contrast     = get_vcp(CONTRAST, "2")!!;
        VcpInfo display_mode = get_vcp(DISPLAY_MODE, "2")!!;
        VcpInfo color_preset = get_vcp(SELECT_COLOR_PRESET, "2")!!;
        VcpInfo volume       = get_vcp(AUDIO_SPEAKER_VOLUME, "2")!!;

        ms.color_temperature = color_preset.value.data.color_val.preset;
        ms.brightness = brightness.value.data.range_val[0];
        ms.max_brightness = brightness.value.data.range_val[1];

        ms.contrast = contrast.value.data.range_val[0];
        ms.max_contrast = contrast.value.data.range_val[1];

        ms.display_mode = convert_da_thing(display_mode.value.data.enum_val);
        ms.user_define_color = color_preset.value.data.color_val.rgb;

        ms.volume = volume.value.data.raw_val;

        if (@ok(monitor_state_channel.push(ms))) return true;
        return false;
    };
}

fn String color_mode_to_string(DisplayMode cm) {
    switch (cm) {
        case DisplayMode.M_BOOK: return "M-Book";
        case DisplayMode.CINEMA: return "Cinema";
        case DisplayMode.GAME: return "Game";
        case DisplayMode.EPAPER: return "ePaper";
        case DisplayMode.USER: return "User";
        case DisplayMode.STANDARD: return "Standard";
        default: return "Unknown";
    }
}

fn DisplayMode convert_da_thing(String color_code) {
    DisplayMode cm;
    switch (color_code) {
        case "0x0f": cm = DisplayMode.M_BOOK;
        case "0x32": cm = DisplayMode.CINEMA;
        case "0x28": cm = DisplayMode.GAME;
        case "0x27": cm = DisplayMode.EPAPER;
        case "0x12": cm = DisplayMode.USER;
        case "0x00": cm = DisplayMode.STANDARD;
        default: cm = DisplayMode.M_BOOK;
    }

    return cm;
}

fn bool set_vcp(String bus, uint val, String code) => @pool() {
    String v = string::tformat("%s", val);
    char[1024] buf;

    String? output = process::run_capture_stdout(
        &buf,
        { "ddcutil", "setvcp", code, v, "--bus", bus }
    )!!;
    if (catch output) return false;
    return true;
}

// Image Controls
const BRIGHTNESS          = "0x10";
const CONTRAST            = "0x12";
const SELECT_COLOR_PRESET = "0x14";

const VIDEO_GAIN_RED   = "0x16";
const VIDEO_GAIN_GREEN = "0x18";
const VIDEO_GAIN_BLUE  = "0x1A";

const String[*] VIDEO_GAIN_RGB = { VIDEO_GAIN_RED, VIDEO_GAIN_GREEN, VIDEO_GAIN_BLUE, };

// Geometry
const HORIZONTAL_POSITION = "0x20";
const VERTICAL_POSITION   = "0x30";


// Active Control
const ACTIVE_CONTROL = "0x52";


// 6-Axis Saturation
const SATURATION_RED     = "0x59";
const SATURATION_YELLOW  = "0x5A";
const SATURATION_GREEN   = "0x5B";
const SATURATION_CYAN    = "0x5C";
const SATURATION_BLUE    = "0x5D";
const SATURATION_MAGENTA = "0x5E";

const String[*] SATURATION_RYGCBM = {
    SATURATION_RED,
    SATURATION_YELLOW,
    SATURATION_GREEN,
    SATURATION_CYAN,
    SATURATION_BLUE,
    SATURATION_MAGENTA,
};


// Input / Audio
const INPUT_SOURCE         = "0x60";
const AUDIO_SPEAKER_VOLUME = "0x62";
const AUDIO_MUTE           = "0x8D";

// Video Black Level
const VIDEO_BLACK_LEVEL_RED   = "0x6C";
const VIDEO_BLACK_LEVEL_GREEN = "0x6E";
const VIDEO_BLACK_LEVEL_BLUE  = "0x70";

const String[*] VIDEO_BLACK_LEVEL_RGB = {
    VIDEO_BLACK_LEVEL_RED,
    VIDEO_BLACK_LEVEL_GREEN,
    VIDEO_BLACK_LEVEL_BLUE,
};

// Display Processing
const GAMMA               = "0x72";
const DISPLAY_SCALING     = "0x86";
const SHARPNESS           = "0x87";
const TV_COLOR_SATURATION = "0x8A";

// Hue Controls
const HUE = "0x90";

const HUE_RED     = "0x9B";
const HUE_YELLOW  = "0x9C";
const HUE_GREEN   = "0x9D";
const HUE_CYAN    = "0x9E";
const HUE_BLUE    = "0x9F";
const HUE_MAGENTA = "0xA0";

const String[*] HUE_RYGCBM = { HUE_RED, HUE_YELLOW, HUE_GREEN, HUE_CYAN, HUE_BLUE, HUE_MAGENTA, };

// Timing Information
const HORIZONTAL_FREQUENCY = "0xAC";
const VERTICAL_FREQUENCY   = "0xAE";

// Display Information
const FLAT_PANEL_SUBPIXEL_LAYOUT = "0xB2";
const DISPLAY_TECHNOLOGY_TYPE    = "0xB6";
const DISPLAY_USAGE_TIME         = "0xC0";
const DISPLAY_DESCRIPTOR_LENGTH  = "0xC2";
const APPLICATION_ENABLE_KEY     = "0xC6";
const DISPLAY_CONTROLLER_TYPE    = "0xC8";
const DISPLAY_FIRMWARE_LEVEL     = "0xC9";

// OSD
const OSD          = "0xCA";
const OSD_LANGUAGE = "0xCC";

// Power
const POWER_MODE   = "0xD6";
const SCAN_FORMAT  = "0xDA";
const DISPLAY_MODE = "0xDC";

// Protocol
const VCP_VERSION = "0xDF";

fn Monitor detect_monitor() => @pool() {
    Monitor monitor;

    char[4096] buf;
    String? output = process::run_capture_stdout(&buf, { "ddcutil", "detect" });

    if (catch output) abort("Failed to get monitor information");

    bool in_display = false;

    foreach (raw_line : output.split(tmem, "\n")) {
        String line = raw_line.trim();

        if (line.starts_with("Display ")) {
            in_display = true;
            continue;
        }

        if (!in_display) continue;

        if (line.starts_with("Invalid display")) break;

        long? idx = line.index_of(":");
        if (catch idx) continue;

        String key   = line[:idx].trim();
        String value = line[idx + 1..].trim();

        switch (key) {
            case "I2C bus":
                monitor.device_path = value;

            case "Model":
                monitor.model = value;

            case "Mfg id":
                monitor.manufacturer = value;

            default:
                continue;
        }
    }

    return monitor;
}


const uint SDL_WINDOWPOS_CENTERED = 0x2FFF0000;
const uint SDL_QUIT               = 0x100;
const uint GL_COLOR_BUFFER_BIT    = 0x00004000;

struct DisplayModes {
    String name;
    DisplayMode mode;
}

struct TemperatureModes {
    String name;
    ColorTemperature mode;
}

constdef CommandType : uint {
    SET_BRIGHTNESS,
    SET_COLOR_MODE,
    SET_CONTRAST,
    SET_COLOR_PRESET,
    SET_VOLUME,
    SET_RED_GAIN,
    SET_GREEN_GAIN,
    SET_BLUE_GAIN,
}

union CommandValue {
    uint brightness;
    DisplayMode mode;
    uint contrast;
    uint val;
    uint volume;
    ColorTemperature color_temp;
}

struct MonitorCommand {
    CommandType type;
    CommandValue value;
}

fn void gui_thing(GuiArgs* args) {
    LibcAllocator libc;
    BufferedChannel{MonitorCommand}* bc = args.channel;

    @pool_init(&libc, 8096) {
        nuklear::sdl_init(nuklear::SDL_INIT_VIDEO);
        nuklear::sdl_gl_setattribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
        nuklear::sdl_gl_setattribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
        nuklear::sdl_gl_setattribute(
            SDL_GL_CONTEXT_PROFILE_MASK,
            (int)SDL_GLprofile.SDL_GL_CONTEXT_PROFILE_CORE
        );

        SDL_Window* win = nuklear::sdl_createwindow(
            "Benq",
            SDL_WINDOWPOS_CENTERED,
            SDL_WINDOWPOS_CENTERED,
            800,
            600,
            (uint)nuklear::SDL_WindowFlags.SDL_WINDOW_OPENGL
                | (uint)nuklear::SDL_WindowFlags.SDL_WINDOW_SHOWN
                | (uint)nuklear::SDL_WindowFlags.SDL_WINDOW_ALLOW_HIGHDPI
        );

        SDL_GLContext glctx = nuklear::sdl_gl_createcontext(win);
        nuklear::sdl_gl_makecurrent(win, glctx);
        nuklear::sdl_gl_setswapinterval(1);

        nuklear::glewExperimental = 1;
        nuklear::glewinit();

        Nk_context* ctx = nuklear::nk_sdl_init(win);
        nuklear::Nk_font_atlas* atlas;
        nuklear::nk_sdl_font_stash_begin(&atlas);
        nuklear::nk_sdl_font_stash_end();

        uint brightness, max_brightness, contrast, max_contrast;
        DisplayMode display_code;
        float brightness_slider_val, brightness_max_value, constrast_slider_val, constrast_max_value, volume_slider_val;
        int running = 1;
        ColorTemperature color_code;
        float red, green, blue;

        bool state_received = false;
        DisplayModes[] display_modes = {
            { "M-BOOK", DisplayMode.M_BOOK },
            { "Cinema", DisplayMode.CINEMA },
            { "Game", DisplayMode.GAME },
            { "ePaper", DisplayMode.EPAPER },
            { "User", DisplayMode.USER },
            { "Standard", DisplayMode.STANDARD },
        };

        TemperatureModes[] temp_modes = {
            { "Normal", ColorTemperature.NORMAL },
            { "Bluish", ColorTemperature.BLUISH },
            { "Reddish", ColorTemperature.REDDISH },
            { "User Define", ColorTemperature.USER_DEFINE }
        };

        while (running) {

            {
                if (!state_received) {
                    MonitorState? ms = args.monitor_state_channel.try_pop();
                    if (@ok(ms)) {
                        brightness_slider_val = (float)(ms.brightness)!! / 100;
                        brightness_max_value = (float)(ms.max_brightness)!! / 100;
                        constrast_slider_val = (float)(ms.contrast)!! / 100;
                        constrast_max_value = (float)(ms.max_contrast)!! / 100;
                        color_code = ms.color_temperature!!;
                        display_code = ms.display_mode!!;
                        red = (float)(ms.user_define_color.r)!! / 100;
                        green = (float)(ms.user_define_color.g)!! / 100;
                        blue = (float)(ms.user_define_color.b)!! / 100;
                        volume_slider_val = (float)(ms.volume)!! / 100;
                        state_received = true;
                    }
                }
                nuklear::SDL_Event evt;
                nuklear::nk_input_begin(ctx);
                while (nuklear::sdl_pollevent(&evt)) {
                    if (evt.type == SDL_QUIT) running = 0;
                    nuklear::nk_sdl_handle_event(&evt);
                }
                if (state_received) {
                    nuklear::nk_input_end(ctx);
                    int w, h;
                    nuklear::sdl_getwindowsize(win, &w, &h);

                    if (nuklear::nk_begin(
                        ctx,
                        "Main",
                        nuklear::nk_rect(0, 0, w, h),
                        (uint)Nk_panel_flags.NK_WINDOW_NO_SCROLLBAR
                    )) {
                        // Sliders

                        // Gruvbox Theme

                        // Window
                        ctx.style.window.background = nuklear::nk_rgb(40, 40, 40); // bg0
                        ctx.style.window.fixed_background = nuklear::nk_style_item_color(
                            nuklear::nk_rgb(40, 40, 40)
                        );
                        ctx.style.window.border_color = nuklear::nk_rgb(60, 56, 54); // bg1
                        ctx.style.window.popup_border_color = nuklear::nk_rgb(60, 56, 54);
                        ctx.style.window.combo_border_color = nuklear::nk_rgb(60, 56, 54);
                        ctx.style.window.contextual_border_color = nuklear::nk_rgb(60, 56, 54);
                        ctx.style.window.menu_border_color = nuklear::nk_rgb(60, 56, 54);
                        ctx.style.window.group_border_color = nuklear::nk_rgb(60, 56, 54);
                        ctx.style.window.tooltip_border_color = nuklear::nk_rgb(60, 56, 54);
                        ctx.style.window.border = 1;
                        ctx.style.window.combo_border = 1;
                        ctx.style.window.contextual_border = 1;
                        ctx.style.window.menu_border = 1;
                        ctx.style.window.group_border = 1;
                        ctx.style.window.tooltip_border = 1;
                        ctx.style.window.popup_border = 1;
                        ctx.style.window.rounding = 2;
                        ctx.style.window.padding = nuklear::nk_vec2(12, 12);
                        ctx.style.window.spacing = nuklear::nk_vec2(6, 6);

                        // Window header
                        ctx.style.window.header.normal = nuklear::nk_style_item_color(
                            nuklear::nk_rgb(50, 48, 47)
                        ); // bg0_h
                        ctx.style.window.header.hover = nuklear::nk_style_item_color(
                            nuklear::nk_rgb(50, 48, 47)
                        );
                        ctx.style.window.header.active = nuklear::nk_style_item_color(
                            nuklear::nk_rgb(50, 48, 47)
                        );
                        ctx.style.window.header.label_normal = nuklear::nk_rgb(
                            235,
                            219,
                            178
                        ); // fg1
                        ctx.style.window.header.label_hover = nuklear::nk_rgb(
                            250,
                            189,
                            47
                        ); // yellow
                        ctx.style.window.header.label_active = nuklear::nk_rgb(250, 189, 47);
                        ctx.style.window.header.padding = nuklear::nk_vec2(4, 4);
                        ctx.style.window.header.label_padding = nuklear::nk_vec2(4, 4);
                        ctx.style.window.header.spacing = nuklear::nk_vec2(2, 2);

                        // Buttons
                        ctx.style.button.normal = nuklear::nk_style_item_color(
                            nuklear::nk_rgb(60, 56, 54)
                        ); // bg1
                        ctx.style.button.hover = nuklear::nk_style_item_color(
                            nuklear::nk_rgb(80, 73, 69)
                        ); // bg2
                        ctx.style.button.active = nuklear::nk_style_item_color(
                            nuklear::nk_rgb(214, 93, 14)
                        ); // orange
                        ctx.style.button.border_color = nuklear::nk_rgb(40, 40, 40);
                        ctx.style.button.text_background = nuklear::nk_rgb(60, 56, 54);
                        ctx.style.button.text_normal = nuklear::nk_rgb(235, 219, 178); // fg1
                        ctx.style.button.text_hover = nuklear::nk_rgb(250, 189, 47); // yellow
                        ctx.style.button.text_active = nuklear::nk_rgb(
                            29,
                            32,
                            33
                        ); // bg0_h
                        ctx.style.button.border = 1;
                        ctx.style.button.rounding = 2;
                        ctx.style.button.padding = nuklear::nk_vec2(6, 4);

                        // Sliders
                        ctx.style.slider.normal = nuklear::nk_style_item_color(
                            nuklear::nk_rgb(50, 48, 47)
                        );
                        ctx.style.slider.hover = nuklear::nk_style_item_color(
                            nuklear::nk_rgb(50, 48, 47)
                        );
                        ctx.style.slider.active = nuklear::nk_style_item_color(
                            nuklear::nk_rgb(50, 48, 47)
                        );
                        ctx.style.slider.bar_normal = nuklear::nk_rgb(80, 73, 69);
                        ctx.style.slider.bar_hover = nuklear::nk_rgb(80, 73, 69);
                        ctx.style.slider.bar_active = nuklear::nk_rgb(80, 73, 69);
                        ctx.style.slider.bar_filled = nuklear::nk_rgb(214, 93, 14); // orange fill
                        ctx.style.slider.cursor_normal = nuklear::nk_style_item_color(
                            nuklear::nk_rgb(250, 189, 47)
                        ); // yellow knob
                        ctx.style.slider.cursor_hover = nuklear::nk_style_item_color(
                            nuklear::nk_rgb(254, 128, 25)
                        );
                        ctx.style.slider.cursor_active = nuklear::nk_style_item_color(
                            nuklear::nk_rgb(250, 189, 47)
                        );
                        ctx.style.slider.border_color = nuklear::nk_rgb(40, 40, 40);
                        ctx.style.slider.padding = nuklear::nk_vec2(0, 0);
                        ctx.style.slider.border = 1;
                        ctx.style.slider.rounding = 2;
                        ctx.style.slider.bar_height = 5;


                        nuklear::nk_layout_row_dynamic(ctx, 8, 1);

                        nuklear::nk_layout_row_dynamic(ctx, 25, 1);
                        nuklear::nk_label(ctx, "Brightness", (uint)Nk_text_alignment.NK_TEXT_LEFT);
                        nuklear::nk_layout_row_dynamic(ctx, 25, 1);

                        if (nuklear::nk_slider_float(
                            ctx,
                            0.0f,
                            &&brightness_slider_val,
                            brightness_max_value,
                            0.01f
                        )) {
                            if (@ok(
                                bc.try_push(
                                    {
                                        .type = CommandType.SET_BRIGHTNESS,
                                        .value = {
                                            .brightness = (uint)(brightness_slider_val * 100.f)
                                        },
                                    }
                                )
                            )) io::printn("sent");
                        }

                        nuklear::nk_layout_row_dynamic(ctx, 8, 1);
                        nuklear::nk_spacing(ctx, 1);

                        nuklear::nk_layout_row_dynamic(ctx, 25, 1);
                        nuklear::nk_label(ctx, "Contrast", (uint)Nk_text_alignment.NK_TEXT_LEFT);
                        nuklear::nk_layout_row_dynamic(ctx, 25, 1);
                        if (nuklear::nk_slider_float(
                            ctx,
                            0.0f,
                            &&constrast_slider_val,
                            constrast_max_value,
                            0.01f
                        )) {
                            if (@ok(
                                bc.try_push(
                                    {
                                        .type = CommandType.SET_CONTRAST,
                                        .value = {
                                            .contrast = (uint)(constrast_slider_val * 100.f)
                                        },
                                    }
                                )
                            )) io::printn("sent");
                        }

                        nuklear::nk_layout_row_dynamic(ctx, 8, 1);
                        nuklear::nk_spacing(ctx, 1);

                        nuklear::nk_layout_row_dynamic(ctx, 25, 1);
                        nuklear::nk_label(ctx, "Volume", (uint)Nk_text_alignment.NK_TEXT_LEFT);
                        nuklear::nk_layout_row_dynamic(ctx, 25, 1);
                        if (nuklear::nk_slider_float(ctx, 0.0f, &&volume_slider_val, 1.0f, 0.01f)) {
                            if (@ok(
                                bc.try_push(
                                    {
                                        .type = CommandType.SET_VOLUME,
                                        .value = { .volume = (uint)(volume_slider_val * 100.f) },
                                    }
                                )
                            )) io::printn("sent");
                        }

                        nuklear::nk_layout_row_dynamic(ctx, 15, 1);
                        nuklear::nk_spacing(ctx, 1);

                        // Display Mode
                        nuklear::nk_layout_row_dynamic(ctx, 25, 1);
                        nuklear::nk_label(
                            ctx,
                            "Display Mode",
                            (uint)Nk_text_alignment.NK_TEXT_LEFT
                        );

                        nuklear::nk_layout_row_dynamic(ctx, 28, 2);

                        foreach (DisplayModes dm : display_modes) {
                            Nk_symbol_type symbol = dm.mode
                                == display_code ? Nk_symbol_type
                                    .NK_SYMBOL_CIRCLE_SOLID : Nk_symbol_type
                                        .NK_SYMBOL_CIRCLE_OUTLINE;

                            if (nuklear::nk_button_symbol_label(
                                ctx,
                                symbol,
                                dm.name,
                                (uint)Nk_text_alignment.NK_TEXT_LEFT
                            )) {
                                if (dm.mode != display_code) {
                                    display_code = dm.mode;
                                    if (@ok(
                                        bc.try_push(
                                            {
                                                .type = CommandType.SET_COLOR_MODE,
                                                .value = { .mode = display_code },
                                            }
                                        )
                                    )) io::printn("sent");
                                }
                            }
                        }

                        nuklear::nk_layout_row_dynamic(ctx, 15, 1);
                        nuklear::nk_spacing(ctx, 1);

                        // Color Preset
                        nuklear::nk_layout_row_dynamic(ctx, 25, 1);
                        nuklear::nk_label(
                            ctx,
                            "Color Preset",
                            (uint)Nk_text_alignment.NK_TEXT_LEFT
                        );
                        nuklear::nk_layout_row_dynamic(ctx, 28, 2);

                        foreach (TemperatureModes tm : temp_modes) {
                            Nk_symbol_type symbol = tm.mode
                                == color_code ? Nk_symbol_type
                                    .NK_SYMBOL_CIRCLE_SOLID : Nk_symbol_type
                                        .NK_SYMBOL_CIRCLE_OUTLINE;

                            if (nuklear::nk_button_symbol_label(
                                ctx,
                                symbol,
                                tm.name,
                                (uint)Nk_text_alignment.NK_TEXT_LEFT
                            )) {
                                if (tm.mode != color_code) {
                                    color_code = tm.mode;
                                    if (color_code != ColorTemperature.USER_DEFINE) {
                                        if (@ok(
                                            bc.try_push(
                                                {
                                                    .type = CommandType.SET_COLOR_PRESET,
                                                    .value = { .color_temp = color_code },
                                                }
                                            )
                                        )) io::printn("sent");
                                    }
                                }
                            }
                        }

                        if (color_code == ColorTemperature.USER_DEFINE) {
                            nuklear::nk_layout_row_dynamic(ctx, 15, 1);
                            nuklear::nk_spacing(ctx, 1);

                            nuklear::nk_layout_row_dynamic(ctx, 20, 1);
                            nuklear::nk_label(
                                ctx,
                                "RGB Gains",
                                (uint)Nk_text_alignment.NK_TEXT_LEFT
                            );

                            nuklear::nk_layout_row_dynamic(ctx, 6, 1);
                            nuklear::nk_spacing(ctx, 1);

                            nuklear::nk_layout_row_dynamic(ctx, 22, 1);
                            if (nuklear::nk_slider_float(ctx, 0.0f, &red, 100, 0.01f)) {
                                if (@ok(
                                    bc.try_push(
                                        {
                                            .type = CommandType.SET_RED_GAIN,
                                            .value = { .val = (uint)(red * 100.0f) }
                                        }
                                    )
                                ));}

                            nuklear::nk_layout_row_dynamic(ctx, 22, 1);
                            if (nuklear::nk_slider_float(ctx, 0.0f, &green, 100, 0.01f)) {
                                if (@ok(
                                    bc.try_push(
                                        {
                                            .type = CommandType.SET_GREEN_GAIN,
                                            .value = { .val = (uint)(green * 100.0f), }
                                        }
                                    )
                                ));}

                            nuklear::nk_layout_row_dynamic(ctx, 22, 1);
                            if (nuklear::nk_slider_float(ctx, 0.0f, &blue, 100, 0.01f)) {
                                if (@ok(
                                    bc.try_push(
                                        {
                                            .type = CommandType.SET_BLUE_GAIN,
                                            .value = { .val = (uint)(blue * 100.0f) }
                                        }
                                    )
                                ));}
                        }
                    }

                    nuklear::nk_end(ctx);

                    nuklear::glViewport(0, 0, w, h);
                    nuklear::glClearColor(0.12f, 0.12f, 0.15f, 1.0f);
                    nuklear::glClear(GL_COLOR_BUFFER_BIT);
                    nuklear::nk_sdl_render(NK_ANTI_ALIASING_ON, 512 * 1024, 128 * 1024);
                    nuklear::sdl_gl_swapwindow(win);
                } else {
                    int w, h;
                    nuklear::sdl_getwindowsize(win, &w, &h);
                    Nk_rect bounds = nuklear::nk_rect(0, 0, 300, 100);
                    bounds.x = (w - bounds.w) / 2.0f;
                    bounds.y = (h - bounds.h) / 2.0f;
                    if (nuklear::nk_begin(
                        ctx,
                        "Loading",
                        bounds,
                        (uint)Nk_panel_flags.NK_WINDOW_NO_SCROLLBAR
                    )) {
                        nuklear::nk_layout_row_dynamic(ctx, 25, 1);
                        nuklear::nk_label(
                            ctx,
                            "Getting monitor information...",
                            (uint)Nk_text_alignment.NK_TEXT_CENTERED
                        );

                        nuklear::nk_layout_row_dynamic(ctx, 20, 1);
                        nuklear::nk_label(
                            ctx,
                            "Please wait...",
                            (uint)Nk_text_alignment.NK_TEXT_CENTERED
                        );
                        nuklear::nk_end(ctx);
                        nuklear::glViewport(0, 0, w, h);
                        nuklear::glClearColor(0.12f, 0.12f, 0.15f, 1.0f);
                        nuklear::glClear(GL_COLOR_BUFFER_BIT);
                        nuklear::nk_sdl_render(NK_ANTI_ALIASING_ON, 512 * 1024, 128 * 1024);
                        nuklear::sdl_gl_swapwindow(win);
                    }
                }
            }
        }

        nuklear::nk_sdl_shutdown();
        nuklear::sdl_gl_deletecontext(glctx);
        nuklear::sdl_destroywindow(win);
        nuklear::sdl_quit();
    };
}

fn void change_stuff(BufferedChannel{MonitorCommand}* bc) {
    LibcAllocator libc;
    @pool_init(&libc, 512) {
        for (;;) {
            MonitorCommand? cmd = bc.pop();
            if (catch cmd) return;

            uint br_value    = cmd.value.brightness;
            uint ct_value    = cmd.value.contrast;
            uint red_value   = cmd.value.val;
            uint green_value = cmd.value.val;
            uint blue_value  = cmd.value.val;
            uint volume      = cmd.value.volume;

            thread::sleep_ms(80);

            switch (cmd.type) {
                case CommandType.SET_BRIGHTNESS:
                    for (;;) {
                        MonitorCommand? next = bc.try_pop();
                        if (catch next) break;
                        if (next.type
                            == CommandType.SET_BRIGHTNESS) br_value = next.value.brightness;
                    }
                    set_vcp("2", br_value, BRIGHTNESS);

                case CommandType.SET_CONTRAST:
                    for (;;) {
                        MonitorCommand? next = bc.try_pop();
                        if (catch next) break;
                        if (next.type == CommandType.SET_CONTRAST) ct_value = next.value.contrast;
                    }
                    set_vcp("2", ct_value, CONTRAST);

                case CommandType.SET_COLOR_MODE:
                    set_vcp("2", (uint)cmd.value.mode, DISPLAY_MODE);

                case CommandType.SET_COLOR_PRESET:
                    set_vcp("2", (uint)cmd.value.color_temp, COLOR_TEMPERATURE_REQUEST);

                case CommandType.SET_RED_GAIN:
                    for (;;) {
                        MonitorCommand? next = bc.try_pop();
                        if (catch next) break;
                        if (next.type == CommandType.SET_RED_GAIN) red_value = next.value.val;
                    }
                    set_vcp("2", red_value, VIDEO_GAIN_RED);

                case CommandType.SET_GREEN_GAIN:
                    for (;;) {
                        MonitorCommand? next = bc.try_pop();
                        if (catch next) break;
                        if (next.type == CommandType.SET_GREEN_GAIN) green_value = next.value.val;
                    }
                    set_vcp("2", green_value, VIDEO_GAIN_GREEN);

                case CommandType.SET_BLUE_GAIN:
                    for (;;) {
                        MonitorCommand? next = bc.try_pop();
                        if (catch next) break;
                        if (next.type == CommandType.SET_BLUE_GAIN) blue_value = next.value.val;
                    }
                    set_vcp("2", blue_value, VIDEO_GAIN_BLUE);

                case CommandType.SET_VOLUME:
                    for (;;) {
                        MonitorCommand? next = bc.try_pop();
                        if (catch next) break;
                        if (next.type == CommandType.SET_VOLUME) volume = next.value.volume;
                    }
                    set_vcp("2", volume, AUDIO_SPEAKER_VOLUME);
                default:
            }
        }
    };
}

struct GuiArgs {
    BufferedChannel{MonitorCommand}* channel;
    BufferedChannel{MonitorState}* monitor_state_channel;
}

fn int main(String[] args) {
    // VcpInfo s = get_vcp(AUDIO_SPEAKER_VOLUME, "2")!!;

    // io::printn(s);

    // io::printn(color_preset);

    // UserDefine ud = get_user_define_vals();

    // io::printn(ud);


    // io::printn(Nk_style_slider::size);
    // io::printn(Nk_style_button::size);
    // io::printn(Nk_style::size);
    // io::printn(Nk_context::size);

    Thread tg, tb, ts;
    GuiArgs ga = { };
    ga.channel = channel::create_buffered(mem, 1024 * 1024)!!;
    ga.monitor_state_channel = channel::create_buffered(mem, 1024 * 1024)!!;
    defer ga.monitor_state_channel.destroy();
    defer ga.channel.destroy();


    tg.create((ThreadFn)&gui_thing, &ga)!!;
    tb.create((ThreadFn)&change_stuff, ga.channel)!!;
    ts.create((ThreadFn)&load_monitor_state, ga.monitor_state_channel)!!;
    tg.join()!!;
    ga.channel.close();

    tb.join()!!;
    ts.join()!!;

    ga.monitor_state_channel.close();

    return 0;
}
