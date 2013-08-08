REPLCompletions.jl
==================

Tab completion for your Julia REPL.

# The interface

The interface is very simple. There are two exported methods provided:

```julia
	completions(string,pos)
	shell_completions(string,pos)
```

The former provides completion of julia expression while the latter provides completion 
of julia shell syntax (`;` at the standard REPL or inside backticks).

Both functions have the same return format:

```julia
	results, range = completions(string,pos)
```

The first return value is an array of possible completions, while the second return value 
is a range specifying the part of the string that was matched. In particular this means
that to execute a completion, you should replace `string[range]` by `completion[i]` for some `i`.

