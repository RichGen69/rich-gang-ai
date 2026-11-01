//! Memory-mapped SPSC ring buffer (v5 Tier 5, integrated 2026-10-23
//! from spikes `spikes/v5_004_memmap2/` + `spikes/v5_005_memmap_ring/`
//! — see docs/SPIKE_V5_004_MEMMAP2.md, docs/SPIKE_V5_005_MEMMAP_RING.md,
//! docs/DESIGN_MEMMAP2_RING_2026-10-23.md and
//! docs/INTEGRATION_V5_MEMMAP_RING_2026-10-23.md).
//!
//! HONEST SCOPE: this is a single-producer / single-consumer (SPSC)
//! byte-message ring backed by one memory-mapped file (memmap2),
//! proven by the spikes over two mappings of one file in one OS.
//! "Memory-mapped" describes the mechanism; it is NOT a measured
//! "zero-copy" performance claim — no latency or throughput has been
//! measured anywhere, and the word is not used as one here. No
//! cross-process or Dart-side reader has been proven; the daemon is,
//! for now, both producer and consumer through its two mappings
//! (the FFI surface).
//!
//! PROTOCOL v2 (ported from spike 005, then hardened 2026-10-23 with
//! per-record CRC-32 — see docs/DESIGN_MEMMAP2_RING_2026-10-23.md):
//! 64-byte header (magic "RGRB0002", capacity, producer-owned
//! monotonic head, consumer-owned monotonic tail), records of
//! [u32 length][payload][u32 CRC-32/IEEE over the length bytes +
//! payload] that never straddle the data-area end (wrap marker
//! 0xFFFF_FFFF, or <4-byte pure padding — both counted in the
//! counters), head published last after a SeqCst fence. The CRC
//! detects torn/corrupted records: the consumer validates length
//! bounds and CRC BEFORE delivering, and any mismatch is an explicit
//! `ring_corrupt` error naming the record's logical offset — bad
//! bytes are never delivered and never silently skipped (the tail
//! does not advance past a corrupt record). The CRC proves the
//! record's bytes match what the producer checksummed; it does NOT
//! prove the producer itself didn't crash mid-write before head
//! publication (those bytes stay invisible, as before), and it is
//! not a defence against a writer who recomputes CRCs. v1 files
//! (magic "RGRB0001") are REJECTED with `ring_bad_magic` — rings are
//! transient IPC files, recreated at each daemon start, so there is
//! no data migration. A full ring is an explicit `ring_full`
//! error and NOTHING is written — no overwrite, no drop-oldest; the
//! caller owns backpressure. An empty recv is `Ok(None)` — a real
//! empty state, never fabricated data.
//!
//! Location is config-driven, like the store (Richard's data rules):
//! config key `"ring_path"` names the ring file and `"ring_capacity"`
//! its data-area size in bytes (power of two, >= 64). No `"ring_path"`
//! key — the shipped `daemon_config.json` state — means the ring is
//! DISABLED and the state surface reports `"enabled": false`;
//! send/recv on a disabled ring are explicit errors, never a silent
//! in-memory substitute. A present `"ring_path"` with a missing or
//! invalid `"ring_capacity"`, or a path that cannot be opened, FAILS
//! daemon start — no capacity is ever guessed as a default. Opening
//! a ring truncates/creates its file: each daemon start begins a
//! fresh ring cycle (the spike's create semantics, stated plainly).

use memmap2::{MmapMut, MmapOptions};
use parking_lot::Mutex;
use std::fs::OpenOptions;
use std::io;
use std::path::PathBuf;
use std::sync::atomic::{fence, Ordering};

const HEADER: usize = 64;
const MAGIC: &[u8; 8] = b"RGRB0002";
const OFF_MAGIC: usize = 0;
const OFF_CAP: usize = 8;
const OFF_HEAD: usize = 16;
const OFF_TAIL: usize = 24;
const WRAP: u32 = 0xFFFF_FFFF;
/// Per-record framing: u32 length + u32 CRC-32.
const FRAME: u64 = 8;

// --- CRC-32 (IEEE 802.3, reflected, poly 0xEDB88320) ----------------
// Small table-driven implementation, in-module on purpose: no new
// external dependency for 20 lines of arithmetic. The table is built
// at compile time by a const fn; unit tests pin the implementation
// against published check vectors (CRC32("123456789") = 0xCBF43926).
const fn build_crc_table() -> [u32; 256] {
    let mut table = [0u32; 256];
    let mut i = 0usize;
    while i < 256 {
        let mut c = i as u32;
        let mut k = 0;
        while k < 8 {
            c = if c & 1 != 0 { 0xEDB8_8320 ^ (c >> 1) } else { c >> 1 };
            k += 1;
        }
        table[i] = c;
        i += 1;
    }
    table
}
static CRC_TABLE: [u32; 256] = build_crc_table();

fn crc32_update(mut crc: u32, data: &[u8]) -> u32 {
    for &b in data {
        crc = CRC_TABLE[((crc ^ b as u32) & 0xFF) as usize] ^ (crc >> 8);
    }
    crc
}

/// CRC-32 of `data` (init/final XOR per the IEEE variant).
pub fn crc32(data: &[u8]) -> u32 {
    crc32_update(0xFFFF_FFFF, data) ^ 0xFFFF_FFFF
}

/// A record's checksum covers its length bytes followed by its
/// payload, so a torn length field is detected too, not just a torn
/// payload.
fn record_crc(len_bytes: &[u8; 4], payload: &[u8]) -> u32 {
    let crc = crc32_update(0xFFFF_FFFF, len_bytes);
    crc32_update(crc, payload) ^ 0xFFFF_FFFF
}

fn err(msg: &str) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidInput, msg.to_string())
}

fn corrupt_err(offset: u64) -> io::Error {
    io::Error::new(
        io::ErrorKind::InvalidData,
        format!("ring_corrupt: offset={offset}"),
    )
}

// Volatile u64 access into the map + SeqCst fences: the spike's
// discipline for counters shared through the page cache (design doc).
fn load_u64(map: &[u8], off: usize) -> u64 {
    fence(Ordering::SeqCst);
    let p = map.as_ptr().wrapping_add(off) as *const u64;
    // SAFETY: `off` is one of the fixed header offsets (8/16/24),
    // always inside the 64-byte header of a mapping sized
    // HEADER + capacity by construction.
    unsafe { p.read_volatile() }
}
fn store_u64(map: &mut [u8], off: usize, v: u64) {
    let p = map.as_mut_ptr().wrapping_add(off) as *mut u64;
    // SAFETY: same fixed-header-offset invariant as load_u64.
    unsafe { p.write_volatile(v) }
    fence(Ordering::SeqCst);
}

#[derive(PartialEq, Clone, Copy, Debug)]
pub enum Role {
    Producer,
    Consumer,
}

/// One side of the ring: a single mapping with a single role.
/// Ported from spike 005 unchanged in protocol.
pub struct Ring {
    path: PathBuf,
    map: MmapMut,
    capacity: u64,
    role: Role,
}

impl Ring {
    /// Producer side: create/truncate the file, write the header.
    pub fn create(path: PathBuf, capacity: u64) -> io::Result<Self> {
        if capacity == 0 {
            return Err(err("ring_zero_capacity"));
        }
        if !capacity.is_power_of_two() || capacity < 64 {
            return Err(err("ring_capacity_not_power_of_two"));
        }
        let file = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(true)
            .open(&path)?;
        file.set_len((HEADER as u64) + capacity)?;
        // SAFETY: memmap2's contract — the mapped file is owned
        // exclusively by this ring for the mapping's lifetime, sized
        // before mapping, never truncated or written by anyone else
        // while mapped. The daemon creates the file itself.
        let mut map = unsafe { MmapOptions::new().map_mut(&file)? };
        map[OFF_MAGIC..OFF_MAGIC + 8].copy_from_slice(MAGIC);
        store_u64(&mut map, OFF_CAP, capacity);
        store_u64(&mut map, OFF_HEAD, 0);
        store_u64(&mut map, OFF_TAIL, 0);
        Ok(Self {
            path,
            map,
            capacity,
            role: Role::Producer,
        })
    }

    /// Consumer side: open an existing ring file, validate header.
    pub fn open_consumer(path: PathBuf) -> io::Result<Self> {
        let file = OpenOptions::new().read(true).write(true).open(&path)?;
        let len = file.metadata()?.len();
        if len < (HEADER as u64) + 64 {
            return Err(err("ring_file_too_small"));
        }
        // SAFETY: file was created by Ring::create and is not
        // truncated or resized by anyone while mapped (design doc).
        let map = unsafe { MmapOptions::new().map_mut(&file)? };
        if &map[OFF_MAGIC..OFF_MAGIC + 8] != MAGIC {
            return Err(err("ring_bad_magic"));
        }
        let capacity = load_u64(&map, OFF_CAP);
        if capacity == 0 || (HEADER as u64) + capacity != len {
            return Err(err("ring_capacity_mismatch"));
        }
        Ok(Self {
            path,
            map,
            capacity,
            role: Role::Consumer,
        })
    }

    pub fn capacity(&self) -> u64 {
        self.capacity
    }

    pub fn head(&self) -> u64 {
        load_u64(&self.map, OFF_HEAD)
    }

    pub fn tail(&self) -> u64 {
        load_u64(&self.map, OFF_TAIL)
    }

    /// (pending bytes including record framing and wrap padding,
    /// pending message count), computed by walking the records
    /// between tail and head WITHOUT consuming them. Read from this
    /// side's mapping; used only for the state surface. The walk
    /// validates bounds and CRC like `recv` does and STOPS at the
    /// first record that fails validation — the count is the number
    /// of whole, intact messages; bytes of a corrupt tail-end are
    /// still included in pending_bytes (head - tail) but are not
    /// counted as a message they cannot be proven to be.
    pub fn pending_counts(&self) -> (u64, u64) {
        let head = self.head();
        let mut tail = self.tail();
        let mut msgs: u64 = 0;
        while tail < head {
            let pos = tail % self.capacity;
            let tailroom = self.capacity - pos;
            if tailroom < 4 {
                tail += tailroom; // pure padding up to the wrap
                continue;
            }
            let at = (HEADER as u64 + pos) as usize;
            let len_bytes: [u8; 4] = self.map[at..at + 4].try_into().unwrap();
            let len = u32::from_le_bytes(len_bytes);
            if len == WRAP {
                tail += tailroom;
                continue;
            }
            let total = FRAME + len as u64;
            if len == 0
                || len as u64 > self.capacity / 2
                || total > tailroom
                || tail + total > head
            {
                break; // torn/corrupt: not a countable message
            }
            let payload = &self.map[at + 4..at + 4 + len as usize];
            let stored = u32::from_le_bytes(
                self.map[at + 4 + len as usize..at + 8 + len as usize]
                    .try_into()
                    .unwrap(),
            );
            if record_crc(&len_bytes, payload) != stored {
                break; // corrupt: not a countable message
            }
            msgs += 1;
            tail += total;
        }
        (head - self.tail(), msgs)
    }

    /// Producer only. Full = explicit `ring_full`, nothing written.
    pub fn send(&mut self, payload: &[u8]) -> io::Result<()> {
        if self.role != Role::Producer {
            return Err(err("ring_wrong_role"));
        }
        if payload.is_empty() || payload.len() as u64 > self.capacity / 2 {
            return Err(err("ring_message_size"));
        }
        let rec = FRAME + payload.len() as u64;
        let len_bytes = (payload.len() as u32).to_le_bytes();
        let crc_bytes = record_crc(&len_bytes, payload).to_le_bytes();
        loop {
            let head = self.head();
            let tail = self.tail();
            let used = head - tail;
            let pos = head % self.capacity;
            let tailroom = self.capacity - pos;
            // Bytes this record will consume, including wrap padding.
            let consume = if tailroom >= rec {
                rec
            } else {
                tailroom + rec // wrap marker (or pure padding) + record at 0
            };
            if used + consume > self.capacity {
                return Err(err("ring_full"));
            }
            let base = HEADER as u64;
            // Record bytes (length + payload + CRC) are fully
            // written BEFORE head is published below — the CRC is
            // part of the record, published under the same
            // head-published-last discipline as the payload.
            let write_rec = |map: &mut [u8], at: usize| {
                map[at..at + 4].copy_from_slice(&len_bytes);
                map[at + 4..at + 4 + payload.len()].copy_from_slice(payload);
                map[at + 4 + payload.len()..at + 8 + payload.len()]
                    .copy_from_slice(&crc_bytes);
            };
            if tailroom >= rec {
                let at = (base + pos) as usize;
                write_rec(&mut self.map, at);
            } else {
                if tailroom >= 4 {
                    let at = (base + pos) as usize;
                    self.map[at..at + 4].copy_from_slice(&WRAP.to_le_bytes());
                }
                let at = base as usize;
                write_rec(&mut self.map, at);
            }
            // Publish head LAST, after the bytes (design doc).
            store_u64(&mut self.map, OFF_HEAD, head + consume);
            return Ok(());
        }
    }

    /// Consumer only. Empty = Ok(None): a real empty state.
    /// A record that fails bounds or CRC validation is an explicit
    /// `ring_corrupt: offset=<logical tail>` error: the bytes are
    /// NOT delivered, NOT skipped, and the tail does NOT advance —
    /// every later recv reports the same corruption until the ring
    /// file is recreated (daemon restart truncates it).
    pub fn recv(&mut self) -> io::Result<Option<Vec<u8>>> {
        if self.role != Role::Consumer {
            return Err(err("ring_wrong_role"));
        }
        let head = self.head();
        let tail = self.tail();
        if head == tail {
            return Ok(None);
        }
        let base = HEADER as u64;
        let pos = tail % self.capacity;
        let tailroom = self.capacity - pos;
        if tailroom < 4 {
            // Pure padding up to the wrap; skip it and re-read.
            store_u64(&mut self.map, OFF_TAIL, tail + tailroom);
            return self.recv();
        }
        let at = (base + pos) as usize;
        let len_bytes: [u8; 4] = self.map[at..at + 4].try_into().unwrap();
        let len = u32::from_le_bytes(len_bytes);
        if len == WRAP {
            // A wrap marker is only valid if everything up to the
            // wrap was actually published; a marker beyond head is
            // corruption, not padding.
            if tail + tailroom > head {
                return Err(corrupt_err(tail));
            }
            store_u64(&mut self.map, OFF_TAIL, tail + tailroom);
            return self.recv();
        }
        let total = FRAME + len as u64;
        // Bounds first: a zero/oversize length, a record that would
        // straddle the data-area end (the producer wraps instead),
        // or a record extending past the published head (torn —
        // head was published but the record is incomplete) are all
        // corruption, stated explicitly, never delivered.
        if len == 0 || len as u64 > self.capacity / 2 || total > tailroom || tail + total > head {
            return Err(corrupt_err(tail));
        }
        let payload = &self.map[at + 4..at + 4 + len as usize];
        let stored = u32::from_le_bytes(
            self.map[at + 4 + len as usize..at + 8 + len as usize]
                .try_into()
                .unwrap(),
        );
        if record_crc(&len_bytes, payload) != stored {
            return Err(corrupt_err(tail));
        }
        let data = payload.to_vec();
        store_u64(&mut self.map, OFF_TAIL, tail + total);
        Ok(Some(data))
    }

    pub fn path(&self) -> &PathBuf {
        &self.path
    }
}

/// Snapshot of the ring for the state surface. For a disabled ring
/// every counter is 0 and `enabled` is false — the zeros are the
/// documented shape of "no ring", never presented as a live ring.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RingState {
    pub enabled: bool,
    pub capacity: u64,
    pub head: u64,
    pub tail: u64,
    pub pending_bytes: u64,
    pub pending_messages: u64,
}

struct RingPair {
    producer: Ring,
    consumer: Ring,
}

/// The daemon-facing ring: the producer and consumer mappings of one
/// ring file, behind a single mutex (the core's established pattern,
/// cf. SqlStore's `Mutex<Connection>`). Disabled when the config
/// names no `"ring_path"`.
pub struct RingIpc {
    inner: Option<Mutex<RingPair>>,
    capacity: u64,
}

impl RingIpc {
    /// Disabled ring (no "ring_path" in config).
    pub fn disabled() -> Self {
        Self {
            inner: None,
            capacity: 0,
        }
    }

    /// Enabled ring at `path` with the given data-area capacity.
    /// Any open failure is an explicit `Err` (`ring_open_failed`).
    pub fn open(path: &str, capacity: u64) -> Result<Self, String> {
        let producer = Ring::create(PathBuf::from(path), capacity)
            .map_err(|e| format!("ring_open_failed: {path}: {e}"))?;
        let consumer = Ring::open_consumer(PathBuf::from(path))
            .map_err(|e| format!("ring_open_failed: {path}: {e}"))?;
        Ok(Self {
            inner: Some(Mutex::new(RingPair { producer, consumer })),
            capacity,
        })
    }

    /// Build from the daemon config: `"ring_path"` (non-empty string)
    /// + `"ring_capacity"` (power-of-two integer >= 64) -> enabled;
    /// no `"ring_path"` -> disabled. A present path with a missing or
    /// invalid capacity, or an unopenable path, is an explicit error
    /// and fails daemon start — capacity is never defaulted.
    pub fn from_config(config: &serde_json::Value) -> Result<Self, String> {
        let path = match config.get("ring_path").and_then(|v| v.as_str()) {
            Some(p) if !p.trim().is_empty() => p,
            _ => return Ok(Self::disabled()),
        };
        let capacity = match config.get("ring_capacity").and_then(|v| v.as_u64()) {
            Some(c) if c >= 64 && c.is_power_of_two() => c,
            _ => {
                return Err(
                    "ring_config_invalid: \"ring_capacity\" must be a power-of-two integer >= 64 when \"ring_path\" is set"
                        .to_string(),
                )
            }
        };
        Self::open(path, capacity)
    }

    pub fn is_enabled(&self) -> bool {
        self.inner.is_some()
    }

    pub fn capacity(&self) -> u64 {
        self.capacity
    }

    pub fn state(&self) -> RingState {
        match &self.inner {
            None => RingState {
                enabled: false,
                capacity: 0,
                head: 0,
                tail: 0,
                pending_bytes: 0,
                pending_messages: 0,
            },
            Some(m) => {
                let pair = m.lock();
                let (pending_bytes, pending_messages) = pair.consumer.pending_counts();
                RingState {
                    enabled: true,
                    capacity: self.capacity,
                    head: pair.consumer.head(),
                    tail: pair.consumer.tail(),
                    pending_bytes,
                    pending_messages,
                }
            }
        }
    }

    /// Send one message. Disabled/full/oversize are explicit errors
    /// carrying the protocol's own codes (`ring_disabled`,
    /// `ring_full`, `ring_message_size`); a full ring drops nothing
    /// and overwrites nothing.
    pub fn send(&self, payload: &[u8]) -> Result<(), String> {
        match &self.inner {
            None => Err("ring_disabled".to_string()),
            Some(m) => m
                .lock()
                .producer
                .send(payload)
                .map_err(|e| e.to_string()),
        }
    }

    /// Receive the oldest pending message. Empty ring is `Ok(None)`;
    /// disabled is an explicit `ring_disabled` error.
    pub fn recv(&self) -> Result<Option<Vec<u8>>, String> {
        match &self.inner {
            None => Err("ring_disabled".to_string()),
            Some(m) => m.lock().consumer.recv().map_err(|e| e.to_string()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicU64, Ordering as AOrd};

    static C: AtomicU64 = AtomicU64::new(0);

    fn tp(tag: &str) -> PathBuf {
        let n = C.fetch_add(1, AOrd::SeqCst);
        std::env::temp_dir().join(format!(
            "rga_core_ring_{}_{}_{}.bin",
            tag,
            std::process::id(),
            n
        ))
    }

    fn pair(tag: &str, cap: u64) -> (Ring, Ring, PathBuf) {
        let p = tp(tag);
        let prod = Ring::create(p.clone(), cap).unwrap();
        let cons = Ring::open_consumer(p.clone()).unwrap();
        (prod, cons, p)
    }

    // --- The spike 005 protocol tests, ported unchanged in intent. ---

    #[test]
    fn in_order_across_two_mappings() {
        let (mut prod, mut cons, p) = pair("order", 256);
        prod.send(b"one").unwrap();
        prod.send(b"two").unwrap();
        prod.send(b"three").unwrap();
        assert_eq!(cons.recv().unwrap(), Some(b"one".to_vec()));
        assert_eq!(cons.recv().unwrap(), Some(b"two".to_vec()));
        assert_eq!(cons.recv().unwrap(), Some(b"three".to_vec()));
        assert_eq!(cons.recv().unwrap(), None);
        std::fs::remove_file(p).ok();
    }

    #[test]
    fn consumer_opened_after_sends_sees_pending() {
        let p = tp("late");
        let mut prod = Ring::create(p.clone(), 256).unwrap();
        prod.send(b"queued").unwrap();
        drop(prod);
        let mut cons = Ring::open_consumer(p.clone()).unwrap();
        assert_eq!(cons.recv().unwrap(), Some(b"queued".to_vec()));
        std::fs::remove_file(p).ok();
    }

    #[test]
    fn wraparound_preserves_order() {
        let (mut prod, mut cons, p) = pair("wrap", 64);
        for i in 0..40u32 {
            let msg = format!("m{:02}", i).into_bytes();
            // Keep the ring drained like a live consumer would.
            prod.send(&msg).unwrap();
            assert_eq!(cons.recv().unwrap(), Some(msg));
        }
        std::fs::remove_file(p).ok();
    }

    #[test]
    fn full_is_explicit_error_and_nothing_is_overwritten() {
        let (mut prod, mut cons, p) = pair("full", 64);
        // v2: 8-byte payloads = 16-byte records (4 len + 8 + 4 CRC);
        // 4 fill the 64-byte ring exactly.
        for i in 0..4u8 {
            prod.send(&[i; 8]).unwrap();
        }
        let r = prod.send(&[9u8; 8]);
        assert!(r.is_err());
        assert_eq!(r.unwrap_err().to_string(), "ring_full");
        // First message still intact — the failed send wrote nothing.
        assert_eq!(cons.recv().unwrap(), Some(vec![0u8; 8]));
        // Room freed by that recv: sending works again.
        prod.send(&[9u8; 8]).unwrap();
        std::fs::remove_file(p).ok();
    }

    #[test]
    fn bad_capacity_and_size_are_rejected() {
        let p = tp("bad");
        assert!(Ring::create(p.clone(), 0).is_err());
        assert!(Ring::create(p.clone(), 100).is_err()); // not power of two
        assert!(Ring::create(p.clone(), 32).is_err()); // below minimum
        let (mut prod, _cons, p2) = pair("size", 64);
        assert!(prod.send(b"").is_err());
        assert!(prod.send(&[0u8; 33]).is_err()); // > capacity/2
        std::fs::remove_file(p).ok();
        std::fs::remove_file(p2).ok();
    }

    #[test]
    fn wrong_role_and_bad_magic_are_errors() {
        let (mut prod, mut cons, p) = pair("role", 64);
        assert!(prod.recv().is_err());
        assert!(cons.send(b"x").is_err());

        let junk = tp("junk");
        std::fs::write(&junk, vec![7u8; 256]).unwrap();
        assert!(Ring::open_consumer(junk.clone()).is_err());
        std::fs::remove_file(junk).ok();
        std::fs::remove_file(p).ok();
    }

    // --- CRC-32 vectors + protocol v2 corruption behaviour. ---

    #[test]
    fn crc32_matches_published_vectors() {
        // Standard CRC-32/IEEE check values.
        assert_eq!(crc32(b""), 0x0000_0000);
        assert_eq!(crc32(b"123456789"), 0xCBF4_3926);
        assert_eq!(crc32(b"abc"), 0x3524_41C2);
        assert_eq!(
            crc32(b"The quick brown fox jumps over the lazy dog"),
            0x414F_A339
        );
    }

    /// Write raw bytes into the ring file behind the mappings' backs
    /// (same page cache, so the consumer mapping sees them) — the
    /// test stand-in for a torn/corrupted on-disk record.
    fn poke(path: &PathBuf, offset: u64, bytes: &[u8]) {
        use std::io::{Seek, SeekFrom, Write};
        let mut f = OpenOptions::new().write(true).open(path).unwrap();
        f.seek(SeekFrom::Start(offset)).unwrap();
        f.write_all(bytes).unwrap();
        f.flush().unwrap();
    }

    #[test]
    fn flipped_payload_byte_is_ring_corrupt_never_delivered() {
        let (mut prod, mut cons, p) = pair("corrupt", 256);
        prod.send(b"integrity").unwrap();
        // Flip the first payload byte (record starts at HEADER:
        // 4 length bytes, then payload).
        poke(&p, (HEADER + 4) as u64, &[b'X']);
        let e = cons.recv().unwrap_err().to_string();
        assert!(e.contains("ring_corrupt"), "got: {e}");
        assert!(e.contains("offset=0"), "got: {e}");
        // The tail did not advance and nothing was delivered: the
        // same corruption is reported again, and the state walk does
        // not count the record as a message.
        assert_eq!(cons.tail(), 0);
        let e = cons.recv().unwrap_err().to_string();
        assert!(e.contains("ring_corrupt"), "got: {e}");
        assert_eq!(cons.pending_counts().1, 0);
        std::fs::remove_file(p).ok();
    }

    #[test]
    fn torn_record_is_ring_corrupt_never_delivered() {
        let (mut prod, mut cons, p) = pair("torn", 256);
        prod.send(b"ping").unwrap(); // one whole 12-byte v2 record
        // Rewrite the length field to claim 8 more payload bytes
        // than were ever published: tail + record now extends past
        // head — a torn/partial record.
        poke(&p, HEADER as u64, &12u32.to_le_bytes());
        let e = cons.recv().unwrap_err().to_string();
        assert!(e.contains("ring_corrupt"), "got: {e}");
        assert!(e.contains("offset=0"), "got: {e}");
        assert_eq!(cons.tail(), 0);
        std::fs::remove_file(p).ok();
    }

    #[test]
    fn v1_magic_is_rejected_explicitly() {
        // A v1-format file (magic RGRB0001) must be refused, never
        // silently misread as v2.
        let p = tp("v1");
        let mut bytes = vec![0u8; 256];
        bytes[0..8].copy_from_slice(b"RGRB0001");
        std::fs::write(&p, bytes).unwrap();
        let e = Ring::open_consumer(p.clone())
            .err()
            .expect("v1 magic must be rejected")
            .to_string();
        assert!(e.contains("ring_bad_magic"), "got: {e}");
        std::fs::remove_file(p).ok();
    }

    // --- Daemon-wrapper (RingIpc) behaviour. ---

    #[test]
    fn disabled_ring_reports_disabled_and_errors_explicitly() {
        let r = RingIpc::disabled();
        assert!(!r.is_enabled());
        let s = r.state();
        assert!(!s.enabled);
        assert_eq!(s.capacity, 0);
        assert_eq!(s.pending_messages, 0);
        assert_eq!(r.send(b"x").err().unwrap(), "ring_disabled");
        assert_eq!(r.recv().err().unwrap(), "ring_disabled");
    }

    #[test]
    fn wrapper_roundtrip_and_state_counts_are_real() {
        let p = tp("wrap2");
        let r = RingIpc::open(p.to_str().unwrap(), 256).unwrap();
        assert!(r.is_enabled());
        assert_eq!(r.recv().unwrap(), None); // honest empty
        r.send(b"alpha").unwrap();
        r.send(b"beta").unwrap();
        let s = r.state();
        assert!(s.enabled);
        assert_eq!(s.capacity, 256);
        assert_eq!(s.pending_messages, 2);
        // v2 framing: "alpha" record = 4+5+4 = 13 bytes, "beta" =
        // 4+4+4 = 12: head advanced 25.
        assert_eq!(s.head, 25);
        assert_eq!(s.tail, 0);
        assert_eq!(s.pending_bytes, 25);
        assert_eq!(r.recv().unwrap(), Some(b"alpha".to_vec()));
        let s = r.state();
        assert_eq!(s.pending_messages, 1);
        assert_eq!(s.tail, 13);
        assert_eq!(r.recv().unwrap(), Some(b"beta".to_vec()));
        assert_eq!(r.recv().unwrap(), None);
        std::fs::remove_file(p).ok();
    }

    #[test]
    fn from_config_semantics() {
        // No ring_path -> disabled, even with a capacity present.
        let r = RingIpc::from_config(&serde_json::json!({})).unwrap();
        assert!(!r.is_enabled());
        let r = RingIpc::from_config(&serde_json::json!({ "ring_capacity": 256 })).unwrap();
        assert!(!r.is_enabled());

        // ring_path with no capacity -> explicit error, no default.
        let err = RingIpc::from_config(&serde_json::json!({ "ring_path": "/tmp/x.bin" }))
            .err()
            .expect("missing capacity must error");
        assert!(err.contains("ring_config_invalid"), "got: {err}");

        // ring_path with a non-power-of-two capacity -> explicit error.
        let err = RingIpc::from_config(
            &serde_json::json!({ "ring_path": "/tmp/x.bin", "ring_capacity": 100 }),
        )
        .err()
        .expect("bad capacity must error");
        assert!(err.contains("ring_config_invalid"), "got: {err}");

        // Unopenable path -> explicit ring_open_failed, no fallback.
        let err = RingIpc::from_config(
            &serde_json::json!({ "ring_path": "/no/such/dir/rga.bin", "ring_capacity": 256 }),
        )
        .err()
        .expect("unopenable path must error");
        assert!(err.contains("ring_open_failed"), "got: {err}");

        // A well-formed config opens a working ring.
        let p = tp("cfg");
        let r = RingIpc::from_config(
            &serde_json::json!({ "ring_path": p.to_str().unwrap(), "ring_capacity": 128 }),
        )
        .unwrap();
        assert!(r.is_enabled());
        r.send(b"cfg").unwrap();
        assert_eq!(r.recv().unwrap(), Some(b"cfg".to_vec()));
        std::fs::remove_file(p).ok();
    }
}
