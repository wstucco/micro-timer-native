use std::thread::{self, spawn};
use std::time::{Duration, Instant};

use rustler::{Atom, Encoder, Env, LocalPid, OwnedEnv};

#[rustler::nif]
fn sleep(env: Env, nanoseconds: u64) -> Atom {
    let pid = env.pid().to_owned();

    let _ = spawn(move || {
        do_sleep(Duration::from_nanos(nanoseconds));
        signal_sleep_done_to_pid(&pid);
    });

    return rustler::types::atom::ok();
}

#[cfg(debug_assertions)]
fn do_sleep(duration: Duration) {
    let start = Instant::now();

    thread::sleep(duration);

    let elapsed = start.elapsed();
    println!(
        "time elapsed nano: {:?} micro: {:?} millis: {:?}\r",
        elapsed.as_nanos(),
        elapsed.as_micros(),
        elapsed.as_millis()
    );
}

#[cfg(not(debug_assertions))]
fn do_sleep(duration: Duration) {
    println!("Debugging disabled");
    thread::sleep(duration);
}

fn signal_sleep_done_to_pid(pid: &LocalPid) {
    let mut msg_env = OwnedEnv::new();
    let ok = rustler::types::atom::ok();
    msg_env.send_and_clear(pid, |env| (pid, ok).encode(env));
}

rustler::init!("Elixir.MicroTimer.Native", [sleep]);
