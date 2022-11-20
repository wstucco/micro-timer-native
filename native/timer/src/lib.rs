use std::thread;
use std::time::{Duration, Instant};

fn main() {
    let start = Instant::now();

    let duration = Duration::from_micros(200);
    thread::sleep(duration);

    let duration = start.elapsed();

    println!("Time elapsed in expensive_function() is: {:?}", duration);

    thread::spawn(move || loop {
        thread::sleep(Duration::from_secs(1));
        // println!("slept for 1 second");
        println!("{:?}", start.elapsed().as_micros());
    });

    let _ = thread::spawn(|| loop {
        thread::sleep(Duration::from_secs(2));
        println!("Slept for 2 seconds!")
    })
    .join();
}
