use std::sync::Once;

static INIT: Once = Once::new();

/// Initialise logging exactly once. Safe to call from every daemon start:
/// a second `android_logger::init_once` would panic, so the `Once` guard is
/// load-bearing, not decoration.
pub fn init() {
    INIT.call_once(|| {
        #[cfg(target_os = "android")]
        {
            android_logger::init_once(
                android_logger::Config::default()
                    .with_tag("RGA.Rust")
                    .with_max_level(log::LevelFilter::Info),
            );
            std::panic::set_hook(Box::new(|info| {
                log::error!("PANIC: {}", info);
            }));
        }
        #[cfg(not(target_os = "android"))]
        {
            let _ = env_logger::try_init();
        }
    });
}
