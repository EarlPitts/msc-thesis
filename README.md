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

- Success Typing
- PLT
- fallback to `any()` if typer fails

## IO

- Erlang message-passing
- Group leader
- Catching IO

# Parallel Programs

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
