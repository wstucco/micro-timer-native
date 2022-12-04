use std::thread::spawn;
use std::time::Duration;

use std::sync::Mutex;

use rustler::{Atom, Encoder, Env, LocalPid, OwnedEnv, ResourceArc, Term};

use crossbeam_channel::{bounded, select, tick, Sender};
use Message::{Cancel, Tick};

mod atoms {
    rustler::atoms! {
        ok,
        tick,
        cancel,
    }
}

enum Message {
    Tick(LocalPid),
    Cancel(LocalPid),
}

struct SenderResource {
    pub sender: Mutex<Sender<Message>>,
    pub pid: Mutex<LocalPid>,
}

impl SenderResource {
    pub fn new(sender: Sender<Message>, pid: LocalPid) -> ResourceArc<SenderResource> {
        ResourceArc::new(SenderResource {
            sender: Mutex::new(sender),
            pid: Mutex::new(pid),
        })
    }
}

fn load(env: Env, _: Term) -> bool {
    rustler::resource!(SenderResource, env);
    true
}

#[rustler::nif]
fn sleep(duration: u64, pid: LocalPid) -> Atom {
    spawn(move || {
        if let Ok(_) = tick(ns(duration)).recv() {
            send_ok(&pid);
        };
    });

    return atoms::ok();
}

#[rustler::nif]
fn interval(duration: u64, pid: LocalPid, times: i32) -> Result<ResourceArc<SenderResource>, ()> {
    let (s, r) = bounded::<Message>(0);

    let resource = SenderResource::new(s.clone(), pid.clone());

    spawn(move || {
        let ticker = tick(ns(duration));
        let (s2, r2) = bounded(0);

        spawn(move || {
            let mut c = 0;
            loop {
                select! {
                    // a tick has been received
                    recv(ticker) -> _ => {
                        s.send(Tick(pid)).unwrap();

                        c += 1;
                        if times > 0 && c == times {
                            // if we loop `times` times, break it
                            s.send(Message::Cancel(pid)).unwrap();
                        };
                    },
                    // a cancel message has just arrived
                    recv(r2) -> msg => {
                        if let Ok(Cancel(_)) = msg {
                            break;
                        }
                    },
                }
            }
        });

        loop {
            match r.recv() {
                // send a {pid, :tick} message to the Elixir rocess on every tick
                Ok(Tick(pid)) => send_tick(&pid),
                Ok(Cancel(pid)) => {
                    // signal the Elixir process that we are about to exit by
                    // sending a {pid, :cancel} message
                    send_cancel(&pid);
                    // also signal the looping thread above
                    s2.send(Cancel(pid)).unwrap();
                    break;
                }
                _ => {}
            }
        }
    });

    Ok(resource)
}

#[rustler::nif]
fn cancel(res: ResourceArc<SenderResource>) -> Atom {
    let sender = res.sender.try_lock().unwrap();
    let pid = res.pid.try_lock().unwrap();

    let _ = sender.send(Message::Cancel(*pid));

    atoms::ok()
}

fn ns(duration: u64) -> Duration {
    Duration::from_nanos(duration)
}

fn send_ok(pid: &LocalPid) {
    send(pid, atoms::ok());
}

fn send_tick(pid: &LocalPid) {
    send(pid, atoms::tick());
}

fn send_cancel(pid: &LocalPid) {
    send(pid, atoms::cancel());
}

fn send(pid: &LocalPid, atom: Atom) {
    let mut env = OwnedEnv::new();
    env.send_and_clear(pid, |env| (pid, atom).encode(env));
}

rustler::init!(
    "Elixir.MicroTimer.Native",
    [sleep, interval, cancel],
    load = load
);
