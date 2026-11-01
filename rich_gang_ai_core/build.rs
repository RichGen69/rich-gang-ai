fn main() {
    let out = std::path::Path::new("include");
    std::fs::create_dir_all(out).expect("create include/");
    cbindgen::Builder::new()
        .with_crate(std::env::var("CARGO_MANIFEST_DIR").unwrap())
        .with_language(cbindgen::Language::C)
        .generate()
        .expect("cbindgen failed")
        .write_to_file(out.join("daemon.h"));
    println!("cargo:rerun-if-changed=include/");
    println!("cargo:rerun-if-changed=src/");
}
