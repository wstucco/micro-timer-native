use std::panic;
use std::thread::{self};
use std::time::{Duration, Instant};

use rustler::{Atom, Encoder, Env, LocalPid, OwnedEnv};
use safina_threadpool::ThreadPool;

// use scoped_thread_pool::Pool;

#[macro_use]
extern crate lazy_static;

lazy_static! {
    // static ref POOL2: Pool = Pool::new(100);
    static ref POOL: ThreadPool = ThreadPool::new("waiter", 16).unwrap();
}

#[rustler::nif]
fn sleep(env: Env, nanoseconds: u64) -> Atom {
    let pid = env.pid().to_owned();

    match panic::catch_unwind(|| {
        // let _ = POOL.try_schedule(move || sleep_then_signal(nanoseconds, pid));
        match POOL.try_schedule(move || sleep_then_signal(nanoseconds, pid)) {
            Ok(_) => (),
            Err(_) => {
                println!("try_schedule failed, spawning a regular thread\r");
                // thread::spawn(move || sleep_then_signal(nanoseconds, pid));
            }
        };
    }) {
        Ok(_) => (),
        Err(error) => {
            println!("everything failed {:?}\r", error);
            // thread::spawn(move || sleep_then_signal(nanoseconds, pid));
        }
    }

    return rustler::types::atom::ok();
}

fn sleep_then_signal(duration: u64, pid: LocalPid) -> () {
    do_sleep(Duration::from_nanos(duration));
    signal(&pid);
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

fn signal(pid: &LocalPid) {
    let mut msg_env = OwnedEnv::new();
    let ok = rustler::types::atom::ok();
    msg_env.send_and_clear(pid, |env| (pid, ok).encode(env));
}

rustler::init!("Elixir.MicroTimer.Native", [sleep]);
