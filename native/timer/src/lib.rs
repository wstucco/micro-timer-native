use std::thread::{self};
use std::time::Duration;

use std::io::Write;

use rustler::{Atom, Encoder, Env, LocalPid, OwnedEnv, Term};

use crossbeam_channel::{unbounded, Receiver, Sender};

#[macro_use]
extern crate lazy_static;

lazy_static! {
    static ref CHANNEL: (Sender<LocalPid>, Receiver<LocalPid>) = unbounded();
}

fn load(_env: Env, _: Term) -> bool {
    thread::spawn(move || loop {
        if let Ok(pid) = CHANNEL.1.recv() {
            signal(&pid);
        }
    });
    true
}

#[rustler::nif]
fn sleep(env: Env, nanoseconds: u64) -> Atom {
    let pid = env.pid().to_owned();

    thread::spawn(move || sleep_then_signal(nanoseconds, pid));

    return rustler::types::atom::ok();
}

fn sleep_then_signal(duration: u64, pid: LocalPid) -> () {
    do_sleep(Duration::from_nanos(duration));
    _ = CHANNEL.0.send(pid);
}

#[cfg(debug_assertions)]
fn do_sleep(duration: Duration) {
    use std::{io, time::Instant};

    let start = Instant::now();

    thread::sleep(duration);

    let elapsed = start.elapsed();
    let mut lck = io::stdout().lock();
    _ = writeln!(
        &mut lck,
        "time elapsed nano: {:?} micro: {:?} millis: {:?}\r",
        elapsed.as_nanos(),
        elapsed.as_micros(),
        elapsed.as_millis()
    );
}

#[cfg(not(debug_assertions))]
fn do_sleep(duration: Duration) {
    thread::sleep(duration);
}

fn signal(pid: &LocalPid) {
    let mut msg_env = OwnedEnv::new();
    let ok = rustler::types::atom::ok();
    msg_env.send_and_clear(pid, |env| (pid, ok).encode(env));
}

rustler::init!("Elixir.MicroTimer.Native", [sleep], load = load);
