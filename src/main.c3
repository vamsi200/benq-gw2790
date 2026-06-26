module benq;
import std::io;
import std::os::process;
import std::collections::list;
import sdl;

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
    CINEMA,
    GAME,
    EPAPER,
    USER,
    STANDARD,
    CODING,
    CARE_MODE
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
        char enum_val;
        bool bool_val;
        ushort raw_val;
    }
}

struct VcpInfo {
    String code;
    String name;
    VcpValue value;
    bool writable;
}

faultdef CMD_RUN_FAILED;

fn VcpInfo? get_vcp(String code, String bus) => @pool(){
    char[1024] buf;

    String? output = process::run_capture_stdout(&buf, { "ddcutil", "getvcp", code, "--bus", bus });
    VcpInfo vcp_info = { };
    VcpValue vcp_val = { };

    if (catch output) return CMD_RUN_FAILED~;

    String line = output.trim();
    if (line.contains("current value") && line.contains("max value")) {
        long? idx1 = line.index_of("(")!;
        long? idx2 = line.index_of(")")!;

        if (catch idx1) vcp_info.name = "unknown";
        if (catch idx2) vcp_info.name = "unknown";

        vcp_info.name = line[idx1 + 1..idx2 - 1]!.trim().copy(mem);
        vcp_val.kind = VcpKind.RANGE;
        vcp_info.writable = true;
        vcp_info.code = code;
        vcp_info.value = vcp_val;

        String[] parts = line.split(tmem, ",");
        vcp_val.data.range_val[0] = (uint)parts[0].split(tmem, "=")[1].trim().to_int()!;
        vcp_val.data.range_val[1] = (uint)parts[1].split(tmem, "=")[1].trim().to_int()!;
    }


    return vcp_info;
}

fn bool set_vcp(uint bus, uint val, String code) {
    char[1024] buf;
    String b = string::tformat("%s", bus);
    String v = string::tformat("%s", val);

    String? output = process::run_capture_stdout(
        &buf,
        { "ddcutil", "setvcp", code, v, "--bus", b }
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


fn int main(String[] args) {
    // Monitor m = detect_monitor();
    // io::printn(m);
    // get_capabilities();
    sdl::init(1);
    // VcpInfo val = get_vcp(BRIGHTNESS, "2")!!;
    // io::printn(val);

      // switch (val.value.kind) {
      //     case RANGE: {
      //             uint[2] s = val.value.data.range_val;
      //       }
      //     case ENUM_VAL:
      //     case BOOL_VAL:
      //     case RAW:
      //     default: 
      //   }

    // bool s = set_vcp(2, 10, BRIGHTNESS);
    // io::printn(val);
    return 0;
}
