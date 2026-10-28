// Hides the extra console window on Windows release builds. It does nothing on a Mac.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    pasal_desktop_lib::run()
}
