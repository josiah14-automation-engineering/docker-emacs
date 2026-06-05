package main

import "testing"

func TestInc(t *testing.T) {
	t.Run("increments by one", func(t *testing.T) {
		c := Counter{
			n: 0,
			Name: "test counter",
		}
		c.Inc()
		if c.n != 1 {
			t.Errorf("expected 1, got %d", c.n)
		}
	})
}

func BenchmarkInc(b *testing.B) {
	c := Counter{}
	for b.Loop() {
		c.Inc()
	}
}

 
