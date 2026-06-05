package main

import (
	"testing"
)

func TestInc(t *testing.T) {
	t.Run("increments by one", func(t *testing.T) {
		c := Counter{
			n:    0,
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

func TestCounter_Inc(t *testing.T) {
	type fields struct {
		n    int
		Name string
	}
	tests := []struct {
		name   string
		fields fields
	}{
		// TODO: Add test cases.
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			c := &Counter{
				n:    tt.fields.n,
				Name: tt.fields.Name,
			}
			c.Inc()
		})
	}
}
