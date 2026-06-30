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

constdef ColorMode : uint {
    M_BOOK = 0x0f,
    CINEMA = 0x32,
    GAME = 0x28,
    EPAPER = 0x27,
    USER = 0x12,
    STANDARD = 0x00,
    CODING = 0x27,
    CARE_MODE = 0x27
}

struct MonitorState {
    int brightness;
    int contrast;
    int volume;

    bool muted;

    InputSource input;
    ColorMode mode;

    ColorGain gain;
}

// Bluish 9300 K (sl=0x08)
// UserDefine User 1 (sl=0x0b)
// 
struct UserDefine {
    int r;
    int g;
    int b;
}

enum ColorTemperature {
    NORMAL,
    BLUISH,
    REDDISH,
    USER_DEFINE
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
    ColorMode color_mode;
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
    UNSUPPORTED,
}

struct VcpValue {
    VcpKind kind;
    union data {
        uint[2] range_val;
        String enum_val;
        bool bool_val;
        ushort raw_val;
    }
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
          long? idx = line.index_of("=")!;
          long? idx2 = line.rindex_of(")")!;

          if (catch idx) vcp_info.name = "unknown".copy(mem);
          if (catch idx2) vcp_info.name = "unknown".copy(mem);

          //vcp_info.name = 
          vcp_val.kind = VcpKind.ENUM_VAL;
          vcp_info.code = code;
          vcp_val.data.enum_val = line[idx+1..idx2 - 1]!;
          vcp_info.value = vcp_val;
    }

    return vcp_info;
}

fn ColorMode convert_da_thing(String color_code) {
    ColorMode cm;
    switch (color_code) {
        case "0x0f": cm = ColorMode.M_BOOK;
        case "0x32": cm = ColorMode.CINEMA;
        case "0x28": cm = ColorMode.GAME;
        case "0x27": cm = ColorMode.EPAPER;
        case "0x12": cm = ColorMode.USER;
        case "0x00": cm = ColorMode.STANDARD;
        default: cm = ColorMode.M_BOOK;
    }

    return cm;
}
fn bool set_vcp(String bus, uint val, String code) => @pool(){
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

// fn void get_capabilities() => @pool() {
//     char[4096] buf;
//     String output    = process::run_capture_stdout(
//         &buf,
//         { "ddcutil", "capabilities", "--bus", "2" }
//     )!!;
//     bool in_commands = false;
// 
//     foreach (raw_line : output.split(tmem, "\n")) {
//         String line = raw_line.trim();
//         if (line.starts_with("Commands")) {
//             in_commands = true;
//             continue;
//         }
//     }
// 
//     io::printn(output);
// }

const uint SDL_WINDOWPOS_CENTERED = 0x2FFF0000;
const uint SDL_QUIT               = 0x100;
const uint GL_COLOR_BUFFER_BIT    = 0x00004000;

fn void gui_thing(BufferedChannel{uint}* bc) {
    LibcAllocator libc;
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
        VcpInfo info = get_vcp(BRIGHTNESS, "2")!!;
        int[2] data;
        ColorMode color_code;

        switch (info.value.kind) {
            case RANGE: data = info.value.data.range_val;
            case ENUM_VAL: color_code = convert_da_thing(info.value.data.enum_val);
            default:
        }

        String color_code_str = string::tformat("%s", color_code);
        io::printn(color_code_str);
        float slider_val = (float)data[0] / 100;
        float max_value  = (float)data[1] / 100;
        int running      = 1;
      
        while (running) {
            nuklear::SDL_Event evt;
            nuklear::nk_input_begin(ctx);
            while (nuklear::sdl_pollevent(&evt)) {
                if (evt.type == SDL_QUIT) running = 0;
                nuklear::nk_sdl_handle_event(&evt);
            }

            nuklear::nk_input_end(ctx);
            int w, h;
            nuklear::sdl_getwindowsize(win, &w, &h);

            if (nuklear::nk_begin(
                ctx,
                "Main",
                nuklear::nk_rect(0, 0, w, h),
                (uint)Nk_panel_flags.NK_WINDOW_NO_SCROLLBAR
            )) {
                nuklear::nk_layout_row_dynamic(ctx, 30, 3);
                nuklear::nk_layout_row_dynamic(ctx, 25, 1);
                nuklear::nk_label(ctx, "Brightness", (uint)Nk_text_alignment.NK_TEXT_LEFT);
                nuklear::nk_layout_row_dynamic(ctx, 25, 1);
                if (nuklear::nk_slider_float(ctx, 0.0f, &&slider_val, max_value, 0.01f)) {
                    if (@ok(bc.try_push((uint)(slider_val * 100.0f)))) io::printn("sent");
                }
                if (nuklear::nk_button_symbol_label(ctx, Nk_symbol_type.NK_SYMBOL_CIRCLE_SOLID, color_code_str, (uint)Nk_text_alignment.NK_TEXT_LEFT)){

                }
            }
            nuklear::nk_end(ctx);

            nuklear::glViewport(0, 0, w, h);
            nuklear::glClearColor(0.12f, 0.12f, 0.15f, 1.0f);
            nuklear::glClear(GL_COLOR_BUFFER_BIT);
            nuklear::nk_sdl_render(NK_ANTI_ALIASING_ON, 512 * 1024, 128 * 1024);
            nuklear::sdl_gl_swapwindow(win);
        }

        nuklear::nk_sdl_shutdown();
        nuklear::sdl_gl_deletecontext(glctx);
        nuklear::sdl_destroywindow(win);
        nuklear::sdl_quit();
    };
}

fn void change_brightness(BufferedChannel{uint}* bc) {
    LibcAllocator libc;
    @pool_init(&libc, 512) {
        for (;;) {
            uint value = bc.pop()!!;
            thread::sleep_ms(80);

            for (;;) {
                uint? next = bc.try_pop();
                if (catch next) break;
                value = next;
            }

            if (set_vcp("2", value, BRIGHTNESS)) io::printn("val set");
        }
    };
}


fn int main(String[] args) {
    // get_vcp("0xdc", "2")!!;
    Thread tg, tb;
    BufferedChannel{uint}* bc = channel::create_buffered(mem, 1024 * 1024)!!;
    defer bc.destroy();

    tg.create((ThreadFn)&gui_thing, bc)!!;
    tb.create((ThreadFn)&change_brightness, bc)!!;
    tg.join()!!;
    tb.join()!!;

    bc.close();
    return 0;
}
