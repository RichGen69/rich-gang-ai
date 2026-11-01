use parking_lot::RwLock;
use std::ffi::c_void;
use std::sync::OnceLock;

static LIVE: OnceLock<RwLock<Vec<usize>>> = OnceLock::new();

fn live() -> &'static RwLock<Vec<usize>> {
    LIVE.get_or_init(|| RwLock::new(Vec::new()))
}

pub fn register(h: *mut c_void) {
    live().write().push(h as usize);
}

pub fn is_live(h: *mut c_void) -> bool {
    !h.is_null() && live().read().contains(&(h as usize))
}

pub fn unregister(h: *mut c_void) -> bool {
    let mut g = live().write();
    if let Some(p) = g.iter().position(|x| *x == h as usize) {
        g.remove(p);
        true
    } else {
        false
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::c_void;

    #[test]
    fn register_validate_unregister_cycle() {
        let boxed = Box::new(42u32);
        let h = Box::into_raw(boxed) as *mut c_void;
        assert!(!is_live(h));
        register(h);
        assert!(is_live(h));
        assert!(unregister(h));
        assert!(!is_live(h));
        // Double-unregister must be a safe no-op, not a double-free path.
        assert!(!unregister(h));
        unsafe {
            drop(Box::from_raw(h as *mut u32));
        }
    }

    #[test]
    fn null_is_never_live() {
        assert!(!is_live(std::ptr::null_mut()));
    }
}
