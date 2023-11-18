# Contents

- [Introduction](#introduction)
- [Sequential Programs](#sequential-programs)
    - [Property-Based Testing](#property-based-testing)
    - [Diffing](#diffing)
    - [Slicing](#slicing)
    - [Module Path](#module-path)
    - [Type Inference](#type-inference)
    - [IO](#io)
- [Parallel Programs](#parallel-programs)
    - [Parse Transform](#parse-transform)
    - [Comparison of Messages](#comparison-of-messages)
- [Results](#results)
- [References](#references)

# Introduction

# Sequential Programs

## Property-Based Testing

- Proper
- Property used for checking equivalence

## Diffing

- Different representations of source files

## Slicing

- Caller/callee
- Function interface
- Determining the narrowest set of functions to test:
    - Transitive dependencies
- Iteratively expanding the set of functions
- On-demand compilation

## Module Path

## Type Inference

Erlang is a dynamically typed language, meaning that the types of values are only known at runtime.
It also supports type annotations, provided by the user, but as the Erlang runtime has no type checking in itself, and nothing enforces correct annotations, these are frequently omitted.
Preferably, we would like to know the type of data a specific function accepts, so we can generate input that will result in normal values.
Randomly generating arguments usually leads to runtime errors (type mismatch, pattern matching failing, etc...), which, although it can indicate inequivalence, is usually TODO
The ratio of erroneous and successful function evaluations depend on the size of the function's domain, TODO

We want to maximize the number of evaluations that result in normal execution, giving us values we can compare for equivalence.

*Success typing* is a constraint-based type inference algorithm.
It starts with the type of every possible term, then successively narrows it down, based on constraints from the term's context.

We use a working implementation of success typing called *Typer*, which can work on individual source files, although it requires already evisting type information generated by Dialyzer.

- Success Typing
- PLT
- fallback to `any()` if typer fails

## IO

Up until now, we were only considering the equivalence of programs without side-effects.
Although Erlang is considered as a functional language, nothing stops the user from reading from, or writing to the standard output, to the disk, or to some socket.
Apart from some special cases, IO is allowed anywhere in Erlang programs, and there are generally no indications, either conventional (like function names ending in '!' for lisps), or forced by the compiler (like monadic IO in languages like Haskell), that a given function has side-effects.
To extend the notion of equivalence to include side-effects, we can keep track of any effects that a spcefic function had on its execution environment, while still taking note of the value it returned.
To check if the two functions are equivalent, we compare the effects, together with the return value.

Because we cannot know beforehand if a function will do IO when evaluated, we have to treat every function as one that can potentially have side-effects, and observe these effects for the purposes of checking the equivalence.

- Group leader
- Catching IO

# Parallel Programs

- Erlang message-passing

## Parse Transform

- `Pid ! Msg` -> `Pid ! (print Msg, Msg)`
- `receive` -> `self() ! RandomData, receive`

## Comparison of Messages

- PIDs

# Results

- EquivchekEr

# References

- [PEQtest](https://link.springer.com/chapter/10.1007/978-3-030-99429-7_11)
- [PEQcheck](https://arxiv.org/abs/2101.09042)
- [TypEr paper](https://user.it.uu.se/~tobiasl/publications/typer.pdf)
