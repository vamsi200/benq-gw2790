module benq;
import std::io;
import std::os::process;
import std::collections::list;
import nuklear;
import std::thread::channel;
import libc;
import std::collections::map;
import std::io::path;
import std::os::env;

const uint SDL_WINDOWPOS_CENTERED = 0x2FFF0000;
const uint SDL_QUIT               = 0x100;
const uint GL_COLOR_BUFFER_BIT    = 0x00004000;

struct GuiArgs {
    BufferedChannel{MonitorCommand}* channel;
    BufferedChannel{MonitorState}* monitor_state_channel;
}

struct Monitor_state_args {
    String bus;
    BufferedChannel{MonitorState}* monitor_state_channel;
}

struct DisplayModes {
    String name;
    DisplayMode mode;
}

struct TemperatureModes {
    String name;
    ColorTemperature mode;
}

struct LowBlueLightPlusModes {
    String name;
    LowBlueLightPlus mode;
}

struct GenericOne {
    String name;
    uint val;
}

constdef CommandType : uint {
    SET_BRIGHTNESS,
    SET_COLOR_MODE,
    SET_CONTRAST,
    SET_COLOR_PRESET,
    SET_VOLUME,
    // SET_RED_GAIN,



    // SET_GREEN_GAIN,

    // SET_BLUE_GAIN,


    SET_LOW_BLUE_LIGHT_PLUS,
    SET_AUDIO_MUTE,
    SET_BI_GEN2,
    SET_AMA,
    SET_SHARPNESS
}

union CommandValue {
    uint brightness;
    DisplayMode mode;
    LowBlueLightPlus lblp_mode;
    uint contrast;
    uint val;
    uint volume;
    ColorTemperature color_temp;
    uint audio_mute;
    uint bi_gen2;
    uint ama;
    uint sharpness;
}

struct MonitorCommand {
    CommandType type;
    CommandValue value;
}

const float ROW_LABEL   = 22.0f;
const float ROW_CONTROL = 25.0f;
const float ROW_BUTTON  = 26.0f;
const float SPACER_XS   = 8.0f;
const float SPACER_SM   = 10.0f;
const float SPACER_MD   = 14.0f;
const float SPACER_LOAD = 20.0f;

const float COL_LEFT_RATIO  = 0.58f;
const float COL_RIGHT_RATIO = 0.42f;

const float RGB_SLIDER_MAX  = 100.0f;
const float RGB_SLIDER_STEP = 0.01f;

const uint AUDIO_MUTE_VALUE = 0x01;
const float TAB_HEIGHT      = 30.0f;

enum GuiTab : int {
    DISPLAY,
    MODE,
    AUDIO,
    SYSTEM_INFORMATION,
}

constdef Ama : uint {
    OFF     = 0x00,
    HIGH    = 0x01,
    PREMIUM = 0x02,
}

struct AmaModes {
    String name;
    Ama mode;
}

struct GuiTabDef {
    String name;
    GuiTab tab;
}

enum SystemInfoState {
    NOT_FETCHED,
    FETCHING,
    FETCHED
}

struct Monitor {
    String device_path;
    String model;
    String manufacturer;

    String horizontal_frequency_hz;
    String vertical_frequency_hz;
    String subpixel_layout;
    String technology_type;
    String usage_time_hours;
    String controller_type;
    String firmware_level;
    String osd_control;
    String osd_language;
    String power_mode;
    String scan_mode;
    String vcp_version;
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

const String CACHE_PATH = "/tmp/benq_monitor_cache";

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

// off - 0x00, on - 0xff
const BIGEN2 = "0xe2";

const String[*] SATURATION_RYGCBM = {
    SATURATION_RED,
    SATURATION_YELLOW,
    SATURATION_GREEN,
    SATURATION_CYAN,
    SATURATION_BLUE,
    SATURATION_MAGENTA,
};


const LOWBLUELIGHTPLUS = "0x19";

// Input / Audio
const INPUT_SOURCE         = "0x60";
const AUDIO_SPEAKER_VOLUME = "0x62";
// Mute - sl=0x01, UnMute - sl=0x02



const AUDIO_MUTE = "0x8D";

// Doesn't work :/
// // 0x1c - Dialogue, 0x00 - Music, 0x21 - Standard
// const AUDIO_MODE = "0xe1";
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

// 0x19 - low blue light plus:
// 0x01 - 0 upto 6 (aka 0x05)

constdef LowBlueLightPlus : uint {
    VAL1 = 0x00,
    VAL2 = 0x01,
    VAL3 = 0x02,
    VAL4 = 0x03,
    VAL5 = 0x04,
}

struct MonitorState {
    uint brightness;
    uint max_brightness;
    uint contrast;
    uint max_contrast;
    DisplayMode display_mode;
    ColorTemperature color_temperature;
    // UserDefine user_define_color;
    uint volume;
    LowBlueLightPlus low_blue_light_plus;
    uint audio_mute;
    uint bi_gen2;
    uint ama;
    uint sharpness;
    // InputSource input;
    // ColorGain gain;
}

// struct UserDefine {
//     uint r;
//     uint g;
//     uint b;
// }

const COLOR_TEMPERATURE_REQUEST = "0x0c";
// Well this ain't working, we have to write to 0x0c, values are:



// 28 - 5000K - Reddish - 0x04

// 35 - 6500K - Normal - 0x05

// 63 - 9300K - Bluish - 0x08

// 35 * (r,g,b) - UserDefine - 0x0b


// Off - 0x00
// High - 0x01
// Premium - 0x02
const AMA = "0xf0";

constdef ColorTemperature : uint {
    NORMAL      = 35,
    BLUISH      = 63,
    REDDISH     = 28,
    USER_DEFINE = 11,
}

// enum AudioScenario {
//     STANDARD,
//     MUSIC,
//     DIALOGUE
// }

enum EyeReminder {
    OFF,
    THIRTY_MIN,
    FORTYFIVE_MIN,
    SIXTRY_MIN
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
}

struct VcpInfo {
    String code;
    VcpValue value;
}

faultdef CMD_RUN_FAILED;

fn String[] build_cmd(Allocator alloc, String[] cmd, String bus) {
    List{String} args = { };
    args.push("ddcutil");
    args.push("getvcp");

    foreach (c : cmd) {
        args.push(c);
    }

    args.push("--bus");
    args.push(bus);

    return args.to_array(alloc);
}


fn VcpInfo? parse_vcp_line(String line) {
    VcpInfo vcp_info = { };
    VcpValue vcp_val = { };

    line = line.trim();

    if (line.contains("current value") && line.contains("max value")) {
        vcp_val.kind = VcpKind.RANGE;

        String[] parts = line.split(tmem, ",");
        vcp_val.data.range_val[0] = parts[0].split(tmem, "=")[1].trim().to_uint()!;
        vcp_val.data.range_val[1] = parts[1].split(tmem, "=")[1].trim().to_uint()!;
        vcp_info.value = vcp_val;
    }

    if (line.contains("Display Mode")) {
        long? idx  = line.index_of("=")!;
        long? idx2 = line.rindex_of(")")!;

        vcp_val.kind = VcpKind.ENUM_VAL;
        vcp_val.data.enum_val = line[idx + 1..idx2 - 1]!;
        vcp_info.value = vcp_val;
    }

    if (line.contains("0x14")) {
        vcp_val.kind = VcpKind.ENUM_VAL;

        if (line.contains("6500")) {
            vcp_val.data.color_val.preset = NORMAL;
        } else if (line.contains("5000")) {
            vcp_val.data.color_val.preset = REDDISH;
        } else if (line.contains("9300")) {
            vcp_val.data.color_val.preset = BLUISH;
        }

        vcp_info.value = vcp_val;
    }

    if (line.contains("0x62")) {
        vcp_val.kind = VcpKind.RAW;

        if (!line.contains("default")) {
            long? idx  = line.rindex_of(":");
            long? idx1 = line.rindex_of("(");
            if (catch idx) vcp_val.data.raw_val = 0;
            if (catch idx1) vcp_val.data.raw_val = 0;

            vcp_val.data.raw_val = line[idx + 1..idx1 - 1]!.trim().to_char()!;
        } else {
            vcp_val.data.raw_val = 0;
        }
        vcp_info.value = vcp_val;
    }

    if (line.contains("0x19")) {
        vcp_val.kind = VcpKind.ENUM_VAL;
        long? idx = line.rindex_of("=");
        if (catch idx) vcp_val.data.enum_val = "0";
        vcp_val.data.enum_val = line[idx + 1..]!.trim();
        vcp_info.value = vcp_val;
    }

    if (line.contains("0x8d")) {
        vcp_val.kind = VcpKind.RAW;
        String[] parts = line.tsplit(",");
        vcp_val.data.raw_val = parts[0].tsplit("=")[1].strip_suffix(")").trim().to_uint()!;
        vcp_info.value = vcp_val;
    }

    if (line.contains("0xe2")) {
        vcp_val.kind = VcpKind.RAW;
        long? idx = line.rindex_of("=");
        if (catch idx) vcp_val.data.raw_val = 0;
        vcp_val.data.raw_val = line[idx + 1..]!.trim().to_uint()!;
        vcp_info.value = vcp_val;
    }

    if (line.contains("0xf0")) {
        vcp_val.kind = VcpKind.RAW;
        long? idx = line.rindex_of("=");
        if (catch idx) vcp_val.data.raw_val = 0;
        vcp_val.data.raw_val = line[idx + 1..]!.trim().to_uint()!;
        vcp_info.value = vcp_val;
    }

    return vcp_info;
}

fn HashMap{String, VcpInfo}? get_vcp(String[] codes, String bus) => @pool() {
    char[4096] buf;

    String[] cmd = build_cmd(tmem, codes, bus);

    String? output = process::run_capture_stdout(&buf, cmd);
    if (catch output) return CMD_RUN_FAILED~;

    String[] lines = output.trim().tsplit("\n");

    HashMap{String, VcpInfo} results;
    results.init(tmem);

    foreach (line : lines) {
        if (line.trim().len == 0) continue;

        long? idx = line.index_of("0x");
        if (catch idx) continue;
        String? code = line[idx..idx + 3];

        if (catch code) continue;

        VcpInfo? info = parse_vcp_line(line);
        if (catch info) continue;

        results.set(code, info);
    }

    return results;
}

// fn UserDefine get_user_define_vals() {
//     UserDefine ud;
//     ud.r = get_vcp(VIDEO_GAIN_RED, "2").value.data.range_val[0]!!;
//     ud.g = get_vcp(VIDEO_GAIN_GREEN, "2").value.data.range_val[0]!!;
//     ud.b = get_vcp(VIDEO_GAIN_BLUE, "2").value.data.range_val[0]!!;
// 
//     return ud;
// }

fn bool load_monitor_state(Monitor_state_args* args) {
    LibcAllocator libc;

    @pool_init(&libc, 1024) {
        MonitorState ms = { };

        HashMap{String, VcpInfo} vcps = get_vcp(
            {
                BRIGHTNESS,
                CONTRAST,
                DISPLAY_MODE,
                SELECT_COLOR_PRESET,
                AUDIO_SPEAKER_VOLUME,
                LOWBLUELIGHTPLUS,
                AUDIO_MUTE,
                BIGEN2,
                AMA,
                SHARPNESS
            },
            args.bus
        )!!;

        VcpInfo? brightness          = vcps.get("0x10");
        VcpInfo? contrast            = vcps.get("0x12");
        VcpInfo? display_mode        = vcps.get("0xdc");
        VcpInfo? color_preset        = vcps.get("0x14");
        VcpInfo? volume              = vcps.get("0x62");
        VcpInfo? low_blue_light_plus = vcps.get("0x19");
        VcpInfo? audio_mute          = vcps.get("0x8d");
        VcpInfo? bi_gen2             = vcps.get("0xe2");
        VcpInfo? ama                 = vcps.get("0xf0");
        VcpInfo? sharpness           = vcps.get("0x87");

        if (catch brightness) return false;
        if (catch contrast) return false;
        if (catch display_mode) return false;
        if (catch color_preset) return false;
        if (catch volume) return false;
        if (catch low_blue_light_plus) return false;
        if (catch audio_mute) return false;
        if (catch bi_gen2) return false;
        if (catch ama) return false;
        if (catch sharpness) return false;

        ms.brightness = brightness.value.data.range_val[0];
        ms.max_brightness = brightness.value.data.range_val[1];
        ms.contrast = contrast.value.data.range_val[0];
        ms.max_contrast = contrast.value.data.range_val[1];
        ms.display_mode = convert_da_thing(display_mode.value.data.enum_val);

        ms.sharpness = sharpness.value.data.range_val[0];
        ms.ama = ama.value.data.raw_val;
        ms.bi_gen2 = bi_gen2.value.data.raw_val;
        ms.audio_mute = audio_mute.value.data.raw_val;
        ms.low_blue_light_plus = convert_lbl(low_blue_light_plus.value.data.enum_val);
        ms.color_temperature = color_preset.value.data.color_val.preset;
        ms.volume = volume.value.data.raw_val;

        if (@ok(args.monitor_state_channel.push(ms))) return true;
        return false;
    };
}

fn LowBlueLightPlus convert_lbl(String lbl) {
    LowBlueLightPlus llp;
    switch (lbl) {
        case "0x00": llp = LowBlueLightPlus.VAL1;
        case "0x01": llp = LowBlueLightPlus.VAL2;
        case "0x02": llp = LowBlueLightPlus.VAL3;
        case "0x03": llp = LowBlueLightPlus.VAL4;
        case "0x04": llp = LowBlueLightPlus.VAL5;
        default: llp = LowBlueLightPlus.VAL1;
    }

    return llp;
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
    char[512] buf;
    String[] cmd;

    if (code == LOWBLUELIGHTPLUS) {
        cmd = { "ddcutil", "setvcp", code, v, "--bus", bus, "--permit-unknown-feature", };
    } else {
        cmd = { "ddcutil", "setvcp", code, v, "--bus", bus, };
    }

    String? output = process::run_capture_stdout(&buf, cmd)!!;
    if (catch output) return false;

    return true;
}

fn String parse_enum_value(String value) {
    long? idx = value.rindex_of("(sl=");
    if (catch idx) return value.trim();
    return value[:idx].trim();
}


fn bool load_static_info(Allocator alloc, Monitor* monitor) {
    char[]? contents = file::load_temp(CACHE_PATH);
    if (catch contents) return false;
    String text = (String)contents;

    foreach (raw_line : text.tsplit("\n")) {
        String line = raw_line.trim();
        if (line.len == 0) continue;

        long? idx = line.index_of("=");
        if (catch idx) continue;

        String key   = line[:idx].trim();
        String value = line[idx + 1..].trim();

        switch (key) {
            case "device_path": monitor.device_path = value.copy(alloc);
            case "model": monitor.model = value.copy(alloc);
            case "manufacturer": monitor.manufacturer = value.copy(alloc);
            case "subpixel_layout": monitor.subpixel_layout = value.copy(alloc);
            case "technology_type": monitor.technology_type = value.copy(alloc);
            case "controller_type": monitor.controller_type = value.copy(alloc);
            case "firmware_level": monitor.firmware_level = value.copy(alloc);
            case "vcp_version": monitor.vcp_version = value.copy(alloc);
            default: continue;
        }
    }
    return true;
}

fn void save_static_info(Monitor* monitor) {
    DString out;
    out.init(tmem);
    out.appendf("device_path=%s\n", monitor.device_path);
    out.appendf("model=%s\n", monitor.model);
    out.appendf("manufacturer=%s\n", monitor.manufacturer);
    out.appendf("subpixel_layout=%s\n", monitor.subpixel_layout);
    out.appendf("technology_type=%s\n", monitor.technology_type);
    out.appendf("controller_type=%s\n", monitor.controller_type);
    out.appendf("firmware_level=%s\n", monitor.firmware_level);
    out.appendf("vcp_version=%s\n", monitor.vcp_version);

    (void)file::save(CACHE_PATH, out.str_view());
}

fn void fetch_dynamic_vcp_info(Allocator alloc, Monitor* monitor) => @pool() {
    char[4096] vcp_buf;
    String? vcp_output = process::run_capture_stdout(&vcp_buf, {
        "ddcutil", "getvcp",
        HORIZONTAL_FREQUENCY, VERTICAL_FREQUENCY,
        FLAT_PANEL_SUBPIXEL_LAYOUT, DISPLAY_TECHNOLOGY_TYPE,
        DISPLAY_USAGE_TIME, DISPLAY_DESCRIPTOR_LENGTH,
        APPLICATION_ENABLE_KEY, DISPLAY_CONTROLLER_TYPE,
        DISPLAY_FIRMWARE_LEVEL, OSD, OSD_LANGUAGE,
        POWER_MODE, SCAN_FORMAT, VCP_VERSION,
        "--bus", monitor.device_path
        });
    if (catch vcp_output) abort("Failed to get monitor VCP information");

    String remaining = vcp_output;
    while (remaining.len > 0) {
        long? nl = remaining.index_of("\n");
        String raw_line;
        if (catch nl) {
            raw_line = remaining;
            remaining = "";
        } else {
            raw_line = remaining[:nl];
            remaining = remaining[nl + 1..];
        }

        String line = raw_line.trim();
        if (line.len < 13) continue;

        String code = line[9..12];

        long? sep = line.index_of("): ");
        if (catch sep) continue;
        String value = line[sep + 3..].trim();

        switch (code) {
            case "0xac":
                long? sp = value.index_of(" ");
                if (catch sp) continue;
                monitor.horizontal_frequency_hz = value[:sp].copy(alloc);
            case "0xae":
                long? sp = value.index_of(" ");
                if (catch sp) continue;
                monitor.vertical_frequency_hz = value[:sp].copy(alloc);
            case "0xc0":
                long? eq = value.index_of("= ");
                long? paren = value.rindex_of(" (");
                if (catch eq) continue;
                if (catch paren) continue;
                monitor.usage_time_hours = value[eq + 2..paren - 1].trim().copy(alloc);
            case "0xca":
                DString osd_out;
                osd_out.init(tmem);
                long oi = 0;
                while (oi < value.len) {
                    if (value[oi] == '(') {
                        long? close = value[oi..].index_of(")");
                        if (catch close) {
                            osd_out.append_char(value[oi]);
                            oi++;
                            continue;
                        }
                        oi += close + 1;
                        continue;
                    }
                    osd_out.append_char(value[oi]);
                    oi++;
                }
                monitor.osd_control = osd_out.str_view().trim().copy(alloc);

            case "0xcc":
                monitor.osd_language = parse_enum_value(value).copy(alloc);
            case "0xd6":
                long? comma = value.index_of(",");
                if (catch comma) {
                    monitor.power_mode = value.trim().copy(alloc);
                    continue;
                }

                String first = value[:comma];
                String second = value[comma + 1..];

                long? paren = second.index_of("(");
                if (catch paren) monitor.power_mode = value.copy(alloc);
                second = second[:paren!!];

                long? c1 = first.index_of(":");
                long? c2 = second.index_of(":");

                String first_val;
                if (catch c1) {
                    first_val = first.trim();
                } else {
                    first_val = first[c1 + 1..].trim();
                }

                String second_val;
                if (catch c2) {
                    second_val = second.trim();
                } else {
                    second_val = second[c2 + 1..].trim();
                }

                if (first_val == "On") {
                    monitor.power_mode = first_val.copy(alloc);
                } else if (second_val == "On") {
                    monitor.power_mode = second_val.copy(alloc);
                } else {
                    monitor.power_mode = (first_val.len > 0 ? first_val : second_val).copy(alloc);
                }
            case "0xda":
                monitor.scan_mode = parse_enum_value(value).copy(alloc);
            default:
                continue;
        }
    }
}

fn Monitor detect_monitor(Allocator alloc, bool force_refresh = false) => @pool() {
    Monitor monitor;

    if (!force_refresh && load_static_info(alloc, &monitor)) {
        fetch_dynamic_vcp_info(alloc, &monitor);
        return monitor;
    }

    char[4096] detect_buf;

    String? detect_output = process::run_capture_stdout(&detect_buf, { "ddcutil", "detect" });
    if (catch detect_output) abort("Failed to get monitor information");

    bool in_display  = false;
    String remaining = detect_output;

    while (remaining.len > 0) {
        long? nl = remaining.index_of("\n");
        String raw_line;
        if (catch nl) {
            raw_line = remaining;
            remaining = "";
        } else {
            raw_line = remaining[:nl];
            remaining = remaining[nl + 1..];
        }

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
                long? dash = value.rindex_of("-");
                if (catch dash) continue;
                monitor.device_path = value[dash + 1..].trim().copy(alloc);
            case "Model":
                monitor.model = value.copy(alloc);
            case "Mfg id":
                monitor.manufacturer = value.copy(alloc);
            default:
                continue;
        }
    }

    char[4096] vcp_buf;
    String? vcp_output = process::run_capture_stdout(&vcp_buf, {
        "ddcutil", "getvcp",
        HORIZONTAL_FREQUENCY, VERTICAL_FREQUENCY,
        FLAT_PANEL_SUBPIXEL_LAYOUT, DISPLAY_TECHNOLOGY_TYPE,
        DISPLAY_USAGE_TIME, DISPLAY_DESCRIPTOR_LENGTH,
        APPLICATION_ENABLE_KEY, DISPLAY_CONTROLLER_TYPE,
        DISPLAY_FIRMWARE_LEVEL, OSD, OSD_LANGUAGE,
        POWER_MODE, SCAN_FORMAT, VCP_VERSION,
        "--bus", monitor.device_path
        });
    if (catch vcp_output) abort("Failed to get monitor VCP information");

    remaining = vcp_output;
    while (remaining.len > 0) {
        long? nl = remaining.index_of("\n");
        String raw_line;
        if (catch nl) {
            raw_line = remaining;
            remaining = "";
        } else {
            raw_line = remaining[:nl];
            remaining = remaining[nl + 1..];
        }

        String line = raw_line.trim();
        if (line.len < 13) continue;

        String code = line[9..12];

        long? sep = line.index_of("): ");
        if (catch sep) continue;
        String value = line[sep + 3..].trim();

        switch (code) {
            case "0xac":
                long? sp = value.index_of(" ");
                if (catch sp) continue;
                monitor.horizontal_frequency_hz = value[:sp].copy(alloc);
            case "0xae":
                long? sp = value.index_of(" ");
                if (catch sp) continue;
                monitor.vertical_frequency_hz = value[:sp].copy(alloc);
            case "0xb2":
                monitor.subpixel_layout = parse_enum_value(value).copy(alloc);
            case "0xb6":
                monitor.technology_type = parse_enum_value(value).copy(alloc);
            case "0xc0":
                long? eq = value.index_of("= ");
                long? paren = value.rindex_of(" (");
                if (catch eq) continue;
                if (catch paren) continue;
                monitor.usage_time_hours = value[eq + 2..paren - 1].trim().copy(alloc);
            case "0xc8":
                long? mfg_start = value.index_of("Mfg:");
                long? mfg_paren = value.index_of("(");
                if (catch mfg_start) {
                    monitor.controller_type = value.copy(alloc);
                    continue;
                }
                if (catch mfg_paren) {
                    monitor.controller_type = value.copy(alloc);
                    continue;
                }

                String mfg = value[mfg_start + 4..mfg_paren - 1].trim();

                long? mh_idx = value.index_of("mh=");
                long? ml_idx = value.index_of("ml=");
                long? sh_idx = value.index_of("sh=");

                if (catch mh_idx) monitor.controller_type = value.copy(alloc);
                if (catch ml_idx) monitor.controller_type = value.copy(alloc);
                if (catch sh_idx) monitor.controller_type = value.copy(alloc);

                String mh = "";
                String ml = "";
                String sh = "";



                {
                    String? rest = value[mh_idx + 3..];
                    if (catch rest) value.copy(alloc);

                    long? c = rest.index_of(",");
                    if (catch c) {
                        mh = rest!!.trim();
                    } else {
                        mh = rest!![:c].trim();
                    }
                }

                String? rest = value[ml_idx + 3..];
                if (catch rest) value.copy(alloc);

                long? c = rest!!.index_of(",");
                if (catch c) {
                    ml = rest!!.trim();
                } else {
                    ml = rest!![:c].trim();
                }

                String? val = value[sh_idx + 3..].trim();
                if (catch val) value.copy(alloc);
                sh = val!!;

                monitor.controller_type = string::format(alloc, "%s (%s:%s:%s)", mfg, mh, ml, sh);

            case "0xc9":
                monitor.firmware_level = value.copy(alloc);
            case "0xca":
                DString osd_out;
                osd_out.init(tmem);
                long oi = 0;

                while (oi < value.len) {
                    if (value[oi] == '(') {
                        long? close = value[oi..].index_of(")");
                        if (catch close) {
                            osd_out.append_char(value[oi]);
                            oi++;
                            continue;
                        }
                        oi += close + 1;
                        continue;
                    }
                    osd_out.append_char(value[oi]);
                    oi++;
                }
                monitor.osd_control = osd_out.str_view().trim().copy(alloc);

            case "0xcc":
                monitor.osd_language = parse_enum_value(value).copy(alloc);
            case "0xd6":
                long? comma = value.index_of(",");
                if (catch comma) {
                    monitor.power_mode = value.trim().copy(alloc);
                    continue;
                }

                String first = value[:comma];
                String second = value[comma + 1..];

                long? paren = second.index_of("(");
                if (catch paren) monitor.power_mode = value.copy(alloc);
                second = second[:paren!!];

                long? c1 = first.index_of(":");
                long? c2 = second.index_of(":");

                String first_val;
                if (catch c1) {
                    first_val = first.trim();
                } else {
                    first_val = first[c1 + 1..].trim();
                }

                String second_val;
                if (catch c2) {
                    second_val = second.trim();
                } else {
                    second_val = second[c2 + 1..].trim();
                }

                if (first_val == "On") {
                    monitor.power_mode = first_val.copy(alloc);
                } else if (second_val == "On") {
                    monitor.power_mode = second_val.copy(alloc);
                } else {
                    monitor.power_mode = (first_val.len > 0 ? first_val : second_val).copy(alloc);
                }
            case "0xda":
                monitor.scan_mode = parse_enum_value(value).copy(alloc);
            case "0xdf":
                monitor.vcp_version = value.copy(alloc);
            default:
                continue;
        }
    }

    save_static_info(&monitor);
    return monitor;
}

fn void render_monitor_info(Nk_context* ctx, Monitor* monitor) {
    nuklear::nk_layout_row_dynamic(ctx, 25, 2);

    nuklear::nk_label(ctx, "Device Path", (uint)Nk_text_alignment.NK_TEXT_LEFT);
    nuklear::nk_label(ctx, (CChar*)monitor.device_path, (uint)Nk_text_alignment.NK_TEXT_RIGHT);

    nuklear::nk_label(ctx, "Model", (uint)Nk_text_alignment.NK_TEXT_LEFT);
    nuklear::nk_label(ctx, (CChar*)monitor.model, (uint)Nk_text_alignment.NK_TEXT_RIGHT);

    nuklear::nk_label(ctx, "Manufacturer", (uint)Nk_text_alignment.NK_TEXT_LEFT);
    nuklear::nk_label(ctx, (CChar*)monitor.manufacturer, (uint)Nk_text_alignment.NK_TEXT_RIGHT);

    nuklear::nk_label(ctx, "Horizontal Frequency", (uint)Nk_text_alignment.NK_TEXT_LEFT);
    nuklear::nk_label(
        ctx,
        (CChar*)monitor.horizontal_frequency_hz,
        (uint)Nk_text_alignment.NK_TEXT_RIGHT
    );

    nuklear::nk_label(ctx, "Vertical Frequency", (uint)Nk_text_alignment.NK_TEXT_LEFT);
    nuklear::nk_label(
        ctx,
        (CChar*)monitor.vertical_frequency_hz,
        (uint)Nk_text_alignment.NK_TEXT_RIGHT
    );

    nuklear::nk_label(ctx, "Subpixel Layout", (uint)Nk_text_alignment.NK_TEXT_LEFT);
    nuklear::nk_label(ctx, (CChar*)monitor.subpixel_layout, (uint)Nk_text_alignment.NK_TEXT_RIGHT);

    nuklear::nk_label(ctx, "Technology Type", (uint)Nk_text_alignment.NK_TEXT_LEFT);
    nuklear::nk_label(ctx, (CChar*)monitor.technology_type, (uint)Nk_text_alignment.NK_TEXT_RIGHT);

    nuklear::nk_label(ctx, "Usage Time (hrs)", (uint)Nk_text_alignment.NK_TEXT_LEFT);
    nuklear::nk_label(ctx, (CChar*)monitor.usage_time_hours, (uint)Nk_text_alignment.NK_TEXT_RIGHT);

    nuklear::nk_label(ctx, "Controller Type", (uint)Nk_text_alignment.NK_TEXT_LEFT);
    nuklear::nk_label(ctx, (CChar*)monitor.controller_type, (uint)Nk_text_alignment.NK_TEXT_RIGHT);

    nuklear::nk_label(ctx, "Firmware Level", (uint)Nk_text_alignment.NK_TEXT_LEFT);
    nuklear::nk_label(ctx, (CChar*)monitor.firmware_level, (uint)Nk_text_alignment.NK_TEXT_RIGHT);

    nuklear::nk_label(ctx, "OSD Control", (uint)Nk_text_alignment.NK_TEXT_LEFT);
    nuklear::nk_label(ctx, (CChar*)monitor.osd_control, (uint)Nk_text_alignment.NK_TEXT_RIGHT);

    nuklear::nk_label(ctx, "OSD Language", (uint)Nk_text_alignment.NK_TEXT_LEFT);
    nuklear::nk_label(ctx, (CChar*)monitor.osd_language, (uint)Nk_text_alignment.NK_TEXT_RIGHT);

    nuklear::nk_label(ctx, "Power Mode", (uint)Nk_text_alignment.NK_TEXT_LEFT);
    nuklear::nk_label(ctx, (CChar*)monitor.power_mode, (uint)Nk_text_alignment.NK_TEXT_RIGHT);

    nuklear::nk_label(ctx, "Scan Mode", (uint)Nk_text_alignment.NK_TEXT_LEFT);
    nuklear::nk_label(ctx, (CChar*)monitor.scan_mode, (uint)Nk_text_alignment.NK_TEXT_RIGHT);

    nuklear::nk_label(ctx, "VCP Version", (uint)Nk_text_alignment.NK_TEXT_LEFT);
    nuklear::nk_label(ctx, (CChar*)monitor.vcp_version, (uint)Nk_text_alignment.NK_TEXT_RIGHT);
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
            800,
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
        Nk_font_atlas* atlas;
        Nk_font* font;
        nuklear::nk_sdl_font_stash_begin(&atlas);
        String font_path = resource_path(&libc, "IosevkaNerdFont-Regular.ttf");

        font = nuklear::nk_font_atlas_add_from_file(atlas, font_path, 16.0f, null);

        nuklear::nk_sdl_font_stash_end();
        nuklear::nk_style_set_font(ctx, &font.handle);

        uint brightness, max_brightness, contrast, max_contrast;
        DisplayMode display_code;
        float brightness_slider_val, brightness_max_value;
        float constrast_slider_val, constrast_max_value;
        float volume_slider_val, sharpness_slider_val;
        float sharpness_max_val = (float)10 / 100;
        int running             = 1;
        ColorTemperature color_code;
        LowBlueLightPlus low_blue_light_plus_val;
        float red, green, blue;
        uint audio_mute, bi_gen2;
        bool state_received     = false;
        GuiTab active_tab       = GuiTab.DISPLAY;

        GuiTabDef[] tab_defs = {
            { "Display", GuiTab.DISPLAY },
            { "Mode", GuiTab.MODE },
            { "Audio", GuiTab.AUDIO },
            { "System Information", GuiTab.SYSTEM_INFORMATION }
        };

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
        };

        LowBlueLightPlusModes[] low_blue_light_plus_modes = {
            { "1", LowBlueLightPlus.VAL1 },
            { "2", LowBlueLightPlus.VAL2 },
            { "3", LowBlueLightPlus.VAL3 },
            { "4", LowBlueLightPlus.VAL4 },
            { "5", LowBlueLightPlus.VAL5 },
        };

        GenericOne[] audio_mute_modes = { { "Mute", 0x01 }, { "UnMute", 0x02 }, };

        GenericOne[] bi_gen_modes = { { "Off", 0x00 }, { "On", 0xff }, };

        AmaModes[] ama_modes = {
            { "Off", Ama.OFF },
            { "High", Ama.HIGH },
            { "Premium", Ama.PREMIUM }
        };

        SystemInfoState system_info_state = NOT_FETCHED;
        Monitor system_info_cache;
        bool force_refresh_requested      = false;

        Ama ama_mode;
        while (running) {
            if (!state_received) {
                MonitorState? ms = args.monitor_state_channel.try_pop();
                if (@ok(ms)) {
                    brightness_slider_val = (float)(ms.brightness)!! / 100;
                    brightness_max_value = (float)(ms.max_brightness)!! / 100;
                    constrast_slider_val = (float)(ms.contrast)!! / 100;
                    constrast_max_value = (float)(ms.max_contrast)!! / 100;
                    color_code = ms.color_temperature!!;
                    display_code = ms.display_mode!!;
                    // red = (float)(ms.user_define_color.r)!! / 100;
                    // green = (float)(ms.user_define_color.g)!! / 100;
                    // blue = (float)(ms.user_define_color.b)!! / 100;
                    volume_slider_val = (float)(ms.volume)!! / 100;
                    low_blue_light_plus_val = ms.low_blue_light_plus!!;
                    audio_mute = ms.audio_mute!!;
                    bi_gen2 = ms.bi_gen2!!;
                    ama_mode = (Ama)ms.ama!!;
                    sharpness_slider_val = (float)ms.sharpness!! / 100;
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
                    // Tab strip
                    nuklear::nk_layout_row_dynamic(ctx, TAB_HEIGHT, tab_defs.len);
                    foreach (GuiTabDef td : tab_defs) {
                        Nk_symbol_type symbol = td.tab
                            == active_tab ? Nk_symbol_type
                                .NK_SYMBOL_CIRCLE_SOLID : Nk_symbol_type.NK_SYMBOL_CIRCLE_OUTLINE;


                        if (nuklear::nk_button_symbol_label(
                            ctx,
                            symbol,
                            (CChar*)td.name,
                            (uint)Nk_text_alignment.NK_TEXT_LEFT
                        )) {
                            active_tab = td.tab;
                        }
                    }

                    nuklear::nk_layout_row_dynamic(ctx, SPACER_XS, 1);
                    nuklear::nk_spacing(ctx, 1);

                    // Active tab content
                    nuklear::nk_layout_row_dynamic(ctx, (float)h - 24 - TAB_HEIGHT - SPACER_XS, 1);
                    if (nuklear::nk_group_begin(
                        ctx,
                        "TabContent",
                        (uint)Nk_panel_flags.NK_WINDOW_BORDER
                    )) {
                        switch (active_tab) {
                            case GuiTab.DISPLAY:

                                {
                                    // Brightness
                                    nuklear::nk_layout_row_dynamic(ctx, ROW_CONTROL, 1);
                                    String b_val = string::format(
                                        &libc,
                                        "Brightness: %d",
                                        (int)(brightness_slider_val * 100.0f)
                                    );

                                    nuklear::nk_label(
                                        ctx,
                                        (CChar*)b_val,
                                        (uint)Nk_text_alignment.NK_TEXT_LEFT
                                    );
                                    nuklear::nk_layout_row_dynamic(ctx, ROW_CONTROL, 1);
                                    if (nuklear::nk_slider_float(
                                        ctx,
                                        0.0f,
                                        &&brightness_slider_val,
                                        brightness_max_value,
                                        0.01f
                                    )) {
                                        (void)bc.try_push(
                                            {
                                                .type = CommandType.SET_BRIGHTNESS,
                                                .value = {
                                                    .brightness = (uint)(brightness_slider_val
                                                        * 100.f)
                                                },
                                            }
                                        );
                                    }

                                    nuklear::nk_layout_row_dynamic(ctx, SPACER_MD, 1);
                                    nuklear::nk_spacing(ctx, 1);

                                    // Contrast
                                    nuklear::nk_layout_row_dynamic(ctx, ROW_CONTROL, 1);
                                    String c_val = string::format(
                                        &libc,
                                        "Contrast: %d",
                                        (int)(constrast_slider_val * 100.0f)
                                    );

                                    nuklear::nk_label(
                                        ctx,
                                        (CChar*)c_val,
                                        (uint)Nk_text_alignment.NK_TEXT_LEFT
                                    );
                                    nuklear::nk_layout_row_dynamic(ctx, ROW_CONTROL, 1);
                                    if (nuklear::nk_slider_float(
                                        ctx,
                                        0.0f,
                                        &&constrast_slider_val,
                                        constrast_max_value,
                                        0.01f
                                    )) {
                                        (void)bc.try_push(
                                            {
                                                .type = CommandType.SET_CONTRAST,
                                                .value = {
                                                    .contrast = (uint)(constrast_slider_val
                                                        * 100.f)
                                                },
                                            }
                                        );
                                    }

                                    nuklear::nk_layout_row_dynamic(ctx, SPACER_SM, 1);
                                    nuklear::nk_spacing(ctx, 1);

                                    // Sharpness
                                    nuklear::nk_layout_row_dynamic(ctx, ROW_CONTROL, 1);
                                    String s_val = string::format(
                                        &libc,
                                        "Sharpness: %d",
                                        (int)(sharpness_slider_val * 100.0f + 0.5f)
                                    );

                                    nuklear::nk_label(
                                        ctx,
                                        (CChar*)s_val,
                                        (uint)Nk_text_alignment.NK_TEXT_LEFT
                                    );
                                    nuklear::nk_layout_row_dynamic(ctx, ROW_CONTROL, 1);
                                    if (nuklear::nk_slider_float(
                                        ctx,
                                        0.0f,
                                        &&sharpness_slider_val,
                                        sharpness_max_val,
                                        0.01f
                                    )) {
                                        (void)bc.try_push(
                                            {
                                                .type = CommandType.SET_SHARPNESS,
                                                .value = {
                                                    .sharpness = (uint)(sharpness_slider_val
                                                        * 100.f
                                                        + 0.5f)
                                                },
                                            }
                                        );
                                    }

                                    nuklear::nk_layout_row_dynamic(ctx, SPACER_MD, 1);
                                    nuklear::nk_spacing(ctx, 1);

                                    // Low Blue Light Plus
                                    nuklear::nk_layout_row_dynamic(ctx, ROW_CONTROL, 1);
                                    nuklear::nk_label(
                                        ctx,
                                        "Low Blue Light Plus",
                                        (uint)Nk_text_alignment.NK_TEXT_LEFT
                                    );
                                    nuklear::nk_layout_row_dynamic(ctx, ROW_CONTROL, 1);

                                    foreach (LowBlueLightPlusModes md : low_blue_light_plus_modes) {
                                        Nk_symbol_type symbol = md.mode
                                            == low_blue_light_plus_val ? Nk_symbol_type
                                                .NK_SYMBOL_CIRCLE_SOLID : Nk_symbol_type
                                                    .NK_SYMBOL_CIRCLE_OUTLINE;

                                        if (nuklear::nk_button_symbol_label(
                                            ctx,
                                            symbol,
                                            (CChar*)md.name,
                                            (uint)Nk_text_alignment.NK_TEXT_LEFT
                                        )) {
                                            if (md.mode != low_blue_light_plus_val) {
                                                low_blue_light_plus_val = md.mode;
                                                (void)bc.try_push(
                                                    {
                                                        .type = CommandType
                                                            .SET_LOW_BLUE_LIGHT_PLUS,
                                                        .value = {
                                                            .lblp_mode = low_blue_light_plus_val
                                                        },
                                                    }
                                                );
                                            }
                                        }
                                    }

                                    nuklear::nk_layout_row_dynamic(ctx, SPACER_MD, 1);
                                    nuklear::nk_spacing(ctx, 1);

                                    nuklear::nk_layout_row_dynamic(ctx, ROW_BUTTON, 1);
                                    nuklear::nk_label(
                                        ctx,
                                        "B.I Gen 2",
                                        (uint)Nk_text_alignment.NK_TEXT_LEFT
                                    );

                                    nuklear::nk_layout_row_dynamic(ctx, ROW_BUTTON, 1);


                                    foreach (GenericOne dm : bi_gen_modes) {
                                        Nk_symbol_type symbol = dm.val
                                            == bi_gen2 ? Nk_symbol_type
                                                .NK_SYMBOL_CIRCLE_SOLID : Nk_symbol_type
                                                    .NK_SYMBOL_CIRCLE_OUTLINE;

                                        nuklear::Nk_bool selected = 0;
                                        if (dm.val == bi_gen2) selected = 1;

                                        if (nuklear::nk_selectable_label(
                                            ctx,
                                            (CChar*)dm.name,
                                            (uint)Nk_text_alignment.NK_TEXT_LEFT,
                                            &selected
                                        )) {
                                            if (selected) {
                                                bi_gen2 = dm.val;
                                                (void)bc.try_push(
                                                    {
                                                        .type = CommandType.SET_BI_GEN2,
                                                        .value = { .bi_gen2 = bi_gen2 },
                                                    }
                                                );
                                            }
                                        }
                                    }
                                    break;
                                }

                            case GuiTab.MODE:

                                {
                                    nuklear::nk_layout_row_dynamic(ctx, ROW_LABEL, 1);

                                    // Display Mode
                                    nuklear::nk_label(
                                        ctx,
                                        "Display Mode",
                                        (uint)Nk_text_alignment.NK_TEXT_LEFT
                                    );

                                    nuklear::nk_layout_row_dynamic(ctx, ROW_BUTTON, 1);
                                    foreach (DisplayModes dm : display_modes) {
                                        Nk_symbol_type symbol = dm.mode
                                            == display_code ? Nk_symbol_type
                                                .NK_SYMBOL_CIRCLE_SOLID : Nk_symbol_type
                                                    .NK_SYMBOL_CIRCLE_OUTLINE;

                                        if (nuklear::nk_button_symbol_label(
                                            ctx,
                                            symbol,
                                            (CChar*)dm.name,
                                            (uint)Nk_text_alignment.NK_TEXT_LEFT
                                        )) {
                                            if (dm.mode != display_code) {
                                                display_code = dm.mode;
                                                (void)bc.try_push(
                                                    {
                                                        .type = CommandType.SET_COLOR_MODE,
                                                        .value = { .mode = display_code },
                                                    }
                                                );
                                            }
                                        }
                                    }

                                    // Color Preset
                                    nuklear::nk_layout_row_dynamic(ctx, ROW_LABEL, 1);
                                    nuklear::nk_label(
                                        ctx,
                                        "Color Preset",
                                        (uint)Nk_text_alignment.NK_TEXT_LEFT
                                    );

                                    nuklear::nk_layout_row_dynamic(ctx, ROW_BUTTON, 1);
                                    foreach (TemperatureModes tm : temp_modes) {
                                        Nk_symbol_type symbol = tm.mode
                                            == color_code ? Nk_symbol_type
                                                .NK_SYMBOL_CIRCLE_SOLID : Nk_symbol_type
                                                    .NK_SYMBOL_CIRCLE_OUTLINE;

                                        if (nuklear::nk_button_symbol_label(
                                            ctx,
                                            symbol,
                                            (CChar*)tm.name,
                                            (uint)Nk_text_alignment.NK_TEXT_LEFT
                                        )) {
                                            if (tm.mode != color_code) {
                                                color_code = tm.mode;
                                                if (color_code != ColorTemperature.USER_DEFINE) {
                                                    (void)bc.try_push(
                                                        {
                                                            .type = CommandType.SET_COLOR_PRESET,
                                                            .value = { .color_temp = color_code },
                                                        }
                                                    );
                                                }
                                            }
                                        }
                                    }

                                    nuklear::nk_layout_row_dynamic(ctx, ROW_LABEL, 1);
                                    nuklear::nk_label(
                                        ctx,
                                        "AMA",
                                        (uint)Nk_text_alignment.NK_TEXT_LEFT
                                    );
                                    nuklear::nk_layout_row_dynamic(ctx, ROW_BUTTON, 1);

                                    foreach (AmaModes tm : ama_modes) {
                                        Nk_symbol_type symbol = tm.mode
                                            == ama_mode ? Nk_symbol_type
                                                .NK_SYMBOL_CIRCLE_SOLID : Nk_symbol_type
                                                    .NK_SYMBOL_CIRCLE_OUTLINE;

                                        if (nuklear::nk_button_symbol_label(
                                            ctx,
                                            symbol,
                                            (CChar*)tm.name,
                                            (uint)Nk_text_alignment.NK_TEXT_LEFT
                                        )) {
                                            if (tm.mode != ama_mode) {
                                                ama_mode = tm.mode;
                                                (void)bc.try_push(
                                                    {
                                                        .type = CommandType.SET_AMA,
                                                        .value = { .ama = (uint)ama_mode },
                                                    }
                                                );
                                            }
                                        }
                                    }

                                    // User-defined RGB
                                    // if (color_code == ColorTemperature.USER_DEFINE) {
                                    //     nuklear::nk_layout_row_dynamic(ctx, SPACER_MD, 1);
                                    // 
                                    //     nuklear::nk_layout_row_dynamic(ctx, 200.0f, 1);
                                    //     if (nuklear::nk_group_begin(
                                    //         ctx,
                                    //         "rgb_group",
                                    //         (uint)Nk_panel_flags.NK_WINDOW_BORDER
                                    //             | (uint)Nk_panel_flags.NK_WINDOW_TITLE
                                    //     )) {
                                    //         nuklear::nk_layout_row_dynamic(ctx, SPACER_XS, 1);
                                    //         nuklear::nk_spacing(ctx, 1);
                                    // 
                                    //         nuklear::nk_layout_row_dynamic(ctx, SPACER_LOAD, 1);
                                    //         if (nuklear::nk_slider_float(
                                    //             ctx,
                                    //             0.0f,
                                    //             &red,
                                    //             RGB_SLIDER_MAX,
                                    //             RGB_SLIDER_STEP
                                    //         )) {
                                    //             if (@ok(
                                    //                 bc.try_push(
                                    //                     {
                                    //                         .type = CommandType.SET_RED_GAIN,
                                    //                         .value = {
                                    //                             .val = (uint)(red * 100.0f)
                                    //                         },
                                    //                     }
                                    //                 )
                                    //             ));}
                                    // 
                                    //         nuklear::nk_layout_row_dynamic(ctx, SPACER_LOAD, 1);
                                    //         if (nuklear::nk_slider_float(
                                    //             ctx,
                                    //             0.0f,
                                    //             &green,
                                    //             RGB_SLIDER_MAX,
                                    //             RGB_SLIDER_STEP
                                    //         )) {
                                    //             if (@ok(
                                    //                 bc.try_push(
                                    //                     {
                                    //                         .type = CommandType.SET_GREEN_GAIN,
                                    //                         .value = {
                                    //                             .val = (uint)(green * 100.0f)
                                    //                         },
                                    //                     }
                                    //                 )
                                    //             ));}
                                    // 
                                    //         nuklear::nk_layout_row_dynamic(ctx, SPACER_LOAD, 1);
                                    //         if (nuklear::nk_slider_float(
                                    //             ctx,
                                    //             0.0f,
                                    //             &blue,
                                    //             RGB_SLIDER_MAX,
                                    //             RGB_SLIDER_STEP
                                    //         )) {
                                    //             if (@ok(
                                    //                 bc.try_push(
                                    //                     {
                                    //                         .type = CommandType.SET_BLUE_GAIN,
                                    //                         .value = {
                                    //                             .val = (uint)(blue * 100.0f)
                                    //                         },
                                    //                     }
                                    //                 )
                                    //             ));}
                                    // 
                                    //         nuklear::nk_group_end(ctx);
                                    //     }
                                    // }

                                    break;
                                }

                            case GuiTab.AUDIO:

                                {
                                    nuklear::nk_layout_row_dynamic(ctx, SPACER_SM, 1);
                                    nuklear::nk_spacing(ctx, 1);

                                    // Audio Mute
                                    nuklear::nk_layout_row_dynamic(ctx, ROW_BUTTON, 1);
                                    nuklear::nk_label(
                                        ctx,
                                        "Audio Mute",
                                        (uint)Nk_text_alignment.NK_TEXT_LEFT
                                    );

                                    foreach (GenericOne dm : audio_mute_modes) {
                                        Nk_symbol_type symbol = dm.val
                                            == audio_mute ? Nk_symbol_type
                                                .NK_SYMBOL_CIRCLE_SOLID : Nk_symbol_type
                                                    .NK_SYMBOL_CIRCLE_OUTLINE;

                                        if (nuklear::nk_button_symbol_label(
                                            ctx,
                                            symbol,
                                            (CChar*)dm.name,
                                            (uint)Nk_text_alignment.NK_TEXT_LEFT
                                        )) {
                                            if (dm.val != audio_mute) {
                                                audio_mute = dm.val;
                                                (void)bc.try_push(
                                                    {
                                                        .type = CommandType.SET_AUDIO_MUTE,
                                                        .value = { .audio_mute = audio_mute },
                                                    }
                                                );
                                            }
                                        }
                                    }

                                    nuklear::nk_layout_row_dynamic(ctx, SPACER_MD, 1);
                                    nuklear::nk_spacing(ctx, 1);

                                    // Volume
                                    bool audio_is_muted = audio_mute == AUDIO_MUTE_VALUE;

                                    String a_val = string::format(
                                        &libc,
                                        "Volume: %d",
                                        (int)(volume_slider_val * 100.0f)
                                    );


                                    nuklear::nk_layout_row_dynamic(ctx, ROW_CONTROL, 1);
                                    nuklear::nk_label(
                                        ctx,
                                        (CChar*)a_val,
                                        (uint)Nk_text_alignment.NK_TEXT_LEFT
                                    );
                                    nuklear::nk_layout_row_dynamic(ctx, ROW_CONTROL, 1);

                                    if (audio_is_muted) nuklear::nk_widget_disable_begin(ctx);

                                    if (nuklear::nk_slider_float(
                                        ctx,
                                        0.0f,
                                        &&volume_slider_val,
                                        1.0f,
                                        0.01f
                                    )) {
                                        (void)bc.try_push(
                                            {
                                                .type = CommandType.SET_VOLUME,
                                                .value = {
                                                    .volume = (uint)(volume_slider_val * 100.f)
                                                },
                                            }
                                        );
                                    }

                                    if (audio_is_muted) nuklear::nk_widget_disable_end(ctx);
                                    break;
                                }

                            case GuiTab.SYSTEM_INFORMATION:
                                switch (system_info_state) {
                                    case NOT_FETCHED:
                                        nuklear::nk_layout_row_dynamic(ctx, 30, 1);
                                        nuklear::nk_label(
                                            ctx,
                                            "Fetching monitor information...",
                                            (uint)Nk_text_alignment.NK_TEXT_CENTERED
                                        );
                                        system_info_state = FETCHING;

                                    case FETCHING:
                                        nuklear::nk_layout_row_dynamic(ctx, 30, 1);
                                        nuklear::nk_label(
                                            ctx,
                                            "Fetching monitor information...",
                                            (uint)Nk_text_alignment.NK_TEXT_CENTERED
                                        );
                                        system_info_cache = detect_monitor(
                                            &libc,
                                            force_refresh_requested
                                        );
                                        force_refresh_requested = false;
                                        system_info_state = FETCHED;

                                    case FETCHED:
                                        render_monitor_info(ctx, &system_info_cache);

                                        nuklear::nk_spacing(ctx, 1);
                                        nuklear::nk_layout_row_dynamic(ctx, 30, 1);
                                        if (nuklear::nk_button_label(ctx, "Refresh")) {
                                            force_refresh_requested = true;
                                            system_info_state = NOT_FETCHED;
                                        }
                                }
                        }
                        nuklear::nk_group_end(ctx);
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
                    nuklear::nk_layout_row_dynamic(ctx, ROW_CONTROL, 1);
                    nuklear::nk_label(
                        ctx,
                        "Getting monitor information...",
                        (uint)Nk_text_alignment.NK_TEXT_CENTERED
                    );

                    nuklear::nk_layout_row_dynamic(ctx, SPACER_LOAD, 1);
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

            uint br_value      = cmd.value.brightness;
            uint ct_value      = cmd.value.contrast;
            uint sharpness_val = cmd.value.sharpness;
            uint red_value     = cmd.value.val;
            uint green_value   = cmd.value.val;
            uint blue_value    = cmd.value.val;
            uint volume        = cmd.value.volume;

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

                case CommandType.SET_SHARPNESS:
                    for (;;) {
                        MonitorCommand? next = bc.try_pop();
                        if (catch next) break;
                        if (next.type
                            == CommandType.SET_SHARPNESS) sharpness_val = next.value.sharpness;
                    }
                    set_vcp("2", sharpness_val, SHARPNESS);

                case CommandType.SET_COLOR_MODE:
                    set_vcp("2", (uint)cmd.value.mode, DISPLAY_MODE);

                case CommandType.SET_COLOR_PRESET:
                    set_vcp("2", (uint)cmd.value.color_temp, COLOR_TEMPERATURE_REQUEST);

                // case CommandType.SET_RED_GAIN:
                //     for (;;) {
                //         MonitorCommand? next = bc.try_pop();
                //         if (catch next) break;
                //         if (next.type == CommandType.SET_RED_GAIN) red_value = next.value.val;
                //     }
                //     set_vcp("2", red_value, VIDEO_GAIN_RED);

                // case CommandType.SET_GREEN_GAIN:
                //     for (;;) {
                //         MonitorCommand? next = bc.try_pop();
                //         if (catch next) break;
                //         if (next.type == CommandType.SET_GREEN_GAIN) green_value = next.value.val;
                //     }
                //     set_vcp("2", green_value, VIDEO_GAIN_GREEN);
                // 
                // case CommandType.SET_BLUE_GAIN:
                //     for (;;) {
                //         MonitorCommand? next = bc.try_pop();
                //         if (catch next) break;
                //         if (next.type == CommandType.SET_BLUE_GAIN) blue_value = next.value.val;
                //     }
                //     set_vcp("2", blue_value, VIDEO_GAIN_BLUE);

                case CommandType.SET_VOLUME:
                    for (;;) {
                        MonitorCommand? next = bc.try_pop();
                        if (catch next) break;
                        if (next.type == CommandType.SET_VOLUME) volume = next.value.volume;
                    }
                    set_vcp("2", volume, AUDIO_SPEAKER_VOLUME);

                case CommandType.SET_LOW_BLUE_LIGHT_PLUS:
                    set_vcp("2", (uint)cmd.value.lblp_mode, LOWBLUELIGHTPLUS);

                case CommandType.SET_AUDIO_MUTE:
                    set_vcp("2", (uint)cmd.value.audio_mute, AUDIO_MUTE);
                case CommandType.SET_BI_GEN2:
                    set_vcp("2", (uint)cmd.value.bi_gen2, BIGEN2);

                default:
            }
        }
    };
}

fn String get_bus(Allocator alloc) => @pool() {
    char[4096] detect_buf;

    String? detect_output = process::run_capture_stdout(&detect_buf, { "ddcutil", "detect" });
    if (catch detect_output) abort("Failed to bus");

    bool in_display  = false;
    String remaining = detect_output;
    String device_path;

    while (remaining.len > 0) {
        long? nl = remaining.index_of("\n");
        String raw_line;
        if (catch nl) {
            raw_line = remaining;
            remaining = "";
        } else {
            raw_line = remaining[:nl];
            remaining = remaining[nl + 1..];
        }

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
                long? dash = value.rindex_of("-");
                if (catch dash) continue;
                device_path = value[dash + 1..].trim().copy(alloc);
                break;
            default:
                continue;
        }
    }

    return device_path;
}

fn String resource_path(Allocator alloc, String name) {
    char[4096] buf;

    sz len = libc::readlink("/proc/self/exe", &buf[0], buf.len - 1);
    if (len <= 0) {
        return name.copy(alloc);
    }

    buf[len] = '\0';

    ZString exe = (ZString)&buf[0];
    Path dir    = (Path)((String)exe.str_view()).path_dirname(alloc)!!;

    PathPosix dev = dir.tappend("/../resources/").tappend(name)!!;

    if (path::exists(dev)) {
        return dev.copy(alloc);
    }

    return dir.tappend("/../share/benq/").tappend(name).copy(alloc)!!;
}

fn int main(String[] args) => @pool() {
    Thread tg, tb, ts;
    GuiArgs ga = { };
    ga.channel = channel::create_buffered(tmem, 1024 * 1024)!!;
    ga.monitor_state_channel = channel::create_buffered(tmem, 1024 * 1024)!!;
    defer ga.monitor_state_channel.destroy();
    defer ga.channel.destroy();

    Monitor_state_args msa = { };
    msa.bus = get_bus(tmem);
    msa.monitor_state_channel = ga.monitor_state_channel;

    tg.create((ThreadFn)&gui_thing, &ga)!!;
    ts.create((ThreadFn)&load_monitor_state, &msa)!!;
    tb.create((ThreadFn)&change_stuff, ga.channel)!!;


    tg.join()!!;
    ga.channel.close();
    ts.join()!!;
    tb.join()!!;

    ga.monitor_state_channel.close();
    return 0;
}
