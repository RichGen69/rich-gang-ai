//! JNI bridge for DreamCycleService (Kotlin).
//!
//! All methods are STATIC on the Kotlin side (`JClass`, declared in a
//! `companion object` with `@JvmStatic`) and match these signatures
//! exactly. Every body is wrapped in `catch_unwind`, returning -1 / null
//! on panic — a panic must never unwind into the JVM.
//!
//! JString -> String conversion uses
//! `env.get_string(&s).map(|j| j.to_string_lossy().into_owned())`.
//! Do NOT use `.map(|s| s.into())`: `JavaStr` does not implement
//! `From<JavaStr> for String` in jni 0.21 and it will not compile.
//! (This is a Section 8 VERIFY item — it is checked by
//! `cargo check --target aarch64-linux-android` in the build report.)

use jni::objects::{JClass, JString};
use jni::sys::{jlong, jstring};
use jni::JNIEnv;
use std::ffi::{c_char, c_void, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};

fn jstring_to_string(env: &mut JNIEnv, s: &JString) -> Option<String> {
    env.get_string(s)
        .map(|j| j.to_string_lossy().into_owned())
        .ok()
}

fn handle_ptr(handle: jlong) -> *mut c_void {
    handle as usize as *mut c_void
}

#[no_mangle]
pub extern "system" fn Java_com_richgang_ai_DreamCycleService_nativeBoot(
    mut env: JNIEnv,
    _class: JClass,
    config: JString,
) -> jlong {
    crate::logging::init();
    catch_unwind(AssertUnwindSafe(|| {
        let cfg = jstring_to_string(&mut env, &config).unwrap_or_else(|| "{}".to_string());
        let c = match CString::new(cfg) {
            Ok(c) => c,
            Err(_) => return -1,
        };
        let h = crate::ffi::rga_daemon_start(c.as_ptr());
        if h.is_null() {
            -1
        } else {
            h as usize as jlong
        }
    }))
    .unwrap_or(-1)
}

#[no_mangle]
pub extern "system" fn Java_com_richgang_ai_DreamCycleService_nativeTick(
    _env: JNIEnv,
    _class: JClass,
    handle: jlong,
) -> jlong {
    catch_unwind(AssertUnwindSafe(|| {
        crate::ffi::rga_dream_cycle_tick(handle_ptr(handle)) as jlong
    }))
    .unwrap_or(-1)
}

#[no_mangle]
pub extern "system" fn Java_com_richgang_ai_DreamCycleService_nativeQuery(
    mut env: JNIEnv,
    _class: JClass,
    handle: jlong,
    persona: JString,
    input: JString,
) -> jstring {
    catch_unwind(AssertUnwindSafe(|| {
        let (Some(p), Some(i)) = (
            jstring_to_string(&mut env, &persona),
            jstring_to_string(&mut env, &input),
        ) else {
            return std::ptr::null_mut();
        };
        let (Ok(cp), Ok(ci)) = (CString::new(p), CString::new(i)) else {
            return std::ptr::null_mut();
        };
        let raw: *mut c_char =
            crate::ffi::rga_agent_query(handle_ptr(handle), cp.as_ptr(), ci.as_ptr());
        if raw.is_null() {
            return std::ptr::null_mut();
        }
        // Copy into a Java string, then free the Rust string exactly once.
        let text = unsafe { std::ffi::CStr::from_ptr(raw) }
            .to_string_lossy()
            .into_owned();
        crate::ffi::rga_string_free(raw);
        match env.new_string(text) {
            Ok(s) => s.into_raw(),
            Err(_) => std::ptr::null_mut(),
        }
    }))
    .unwrap_or_else(|_| std::ptr::null_mut())
}

#[no_mangle]
pub extern "system" fn Java_com_richgang_ai_DreamCycleService_nativeStop(
    _env: JNIEnv,
    _class: JClass,
    handle: jlong,
) {
    let _ = catch_unwind(AssertUnwindSafe(|| {
        if handle != 0 {
            crate::ffi::rga_daemon_stop(handle_ptr(handle));
        }
    }));
}
