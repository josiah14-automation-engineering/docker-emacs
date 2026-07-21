package main
//go:generate echo "generate ran"

import (
	"fmt"
)

func main() {
	var message string = "Hello"
	fmt.Println(message)
	c := Counter{
		n: 0,
	}
	fmt.Println(c)

	// var _ int = "not an int"
	// var _ string = 5
	for i := range 10 { // uncomment this and change go in go.mod to 1.21 - if you get an error it's using the older go version
		fmt.Println(i)
	}

}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

type Counter struct {
	n    int
	Name string
}

func (c *Counter) Inc() {
	c.n++
}
