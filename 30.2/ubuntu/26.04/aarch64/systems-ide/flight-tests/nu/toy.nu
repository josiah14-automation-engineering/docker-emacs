#!/usr/bin/env nu

# Toy script for exercising the systems-ide nushell integration:
# syntax highlighting, LSP (hover, goto-def, completion, diagnostics),
# flycheck, and the localleader execute-region/execute-buffer bindings
# (SPC m e e / SPC m e b).

def greet [name: string] {
  $"Hello, ($name)!"
}

def fib [n: int] {
  if $n <= 1 {
    $n
  } else {
    (fib ($n - 1)) + (fib ($n - 2))
  }
}

def main [] {
  print (greet "nushell")

  let numbers = [1 2 3 4 5 6 7 8 9 10]
  let more_numbers = $numbers ++ [11 12 13 14 15]

  let evens = $numbers | where { |n| $n mod 2 == 0 }
  let more_evens = $more_numbers | where { |num| $num mod 2 == 0 }
  print $"Evens: ($evens)"

  let squared = $numbers | each { |n| $n * $n }
  print $"Squares: ($squared)"

  print $"fib(10) = (fib 10)"

  ls | where size > 1kb | sort-by size
}
