/// A simple counter, exercising hover docs, go-to-definition, and rename
/// across files (main.rs -> counter.rs).
#[derive(Debug)]
pub struct Counter {
    pub n: i32,
    pub name: String,
}

impl Counter {
    pub fn inc(&mut self) {
        self.n += 1;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn increments_by_one() {
        let mut c = Counter {
            n: 0,
            name: "test".to_string(),
        };
        c.inc();
        assert_eq!(c.n, 1);
    }
}
