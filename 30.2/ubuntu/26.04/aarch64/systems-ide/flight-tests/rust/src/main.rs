//! Flight-test for systems-ide's Rust IDE tier. Mirrors flight-tests/go's
//! shape: a small program with a struct, a method, and a deliberately
//! commented-out compile error for exercising diagnostics.

mod counter;

use counter::Counter;

fn main() {
    let message = "Hello";
    println!("{message}");

    let mut c = Counter {
        n: 0,
        name: "test".to_string(),
    };
    c.inc();
    println!("{c:?}");

    // let _: i32 = "not an int"; // uncomment to trigger a diagnostic

    for i in 0..10 {
        println!("{i}");
    }
}
