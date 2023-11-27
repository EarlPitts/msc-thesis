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

- https://www.sciencedirect.com/science/article/pii/S2352220823000111 : tagabb:
    - Leirja, hogy a naiv ekvivalencia miert nem eleg
- https://link.springer.com/chapter/10.1007/978-3-030-57761-2_7
- https://dl.acm.org/doi/abs/10.1145/3406085.3409008 : legrelevansabb
- fuggveny eredmenynel mi a helyzet?
- konkurrens: https://www.diva-portal.org/smash/get/diva2:8988/FULLTEXT01.pdf 3.2.6:
    - biszimulacio

# Sequential Programs

## Term Equivalence

- Two peer nodes with their own module path
- Term equivality:
    - Judgement
    - Equivalence on normal forms
- What is function equivalence:
    - Extensionality

## Property-Based Testing

There are two different approaches when we are talking about proving program properties: formal proofs and testing.
While testing is not considered as giving a proof in a strict sense, nevertheless it can still provide some evidence that the properties we want to prove hold, which can be made arbitrarily strong by making the number of test cases higher.
Testing also has the advantage of requiring less expertise, and being easier to automate.

- Difference between formal verification and testing:
    - forall -> random probing
- Proper
- Property used for checking equivalence

## Diffing

- Different representations of source files

## Slicing

Evaluating the whole application after each refactoring would take a considerable amount of time, which would be unfeasible in practice.
This problem is painfully obvious when the refactoring has only affected a very small portion of the codebase (e.g.: renaming some local variable).
Such localised changes shouldn't require the execution of the whole application.

There is also another, more fundamental problem with this naive approach, namely the possibility of non-terminating programs.
Erlang is not a total language, and most erlang applications are non-terminating programs, like web or telecommunication services.
While it's possible to have a notion of equivalence of functions that do not terminate, due to erlang's ability to have uncontrolled side-effects, we are only considering functions that do in fact terminate, and we also have a constraint on the time it can take before we stop its evaluation.

To avoid these problems, we need some other, more principled way to separate the parts of the program that were affected by the refactoring, and focus only on these.
In the literature, this is called *program slicing*.
We take a subset of the program (the slice), according to some *slicing criterion*, which in our case is everything that in any way was affected by the changes.
To determine this subset, we use a number of different static analysis tecniques.

First we compare the textual representation of the program to locate all the changes.
Then we use the source files and the abstract syntax tree to identify each function definition that was altered by the change.
This subset of functions is the initial slice that we start with.
These are the functions that were directly affected by the refactoring, but that doesn't mean that we don't have to check other functions.
TODO

Another important feature, for which we unfortunately didn't have the time to implement, would be to compile modules on-demand.
This would avoid the need to compile the whole project, by only compiling the modules that are tested, right before they are needed.
This, we think, would result in a considerable improvement in the case of larger codebases, where the number of modules can be in the thousands, but we only need to consider a couple of modules when checking for equivalence.

- callgraph

- Caller/callee
- Function interface
- Determining the narrowest set of functions to test:
    - Transitive dependencies
- Iteratively expanding the set of functions
- On-demand compilation

## Module Path

When a function is called, the beam first have to find the corresponding bytecode for it.
It does this by looking for modules that may contain it from a list called the *module path*.
The module path is an ordered list of directories, where bytecode may reside.
The beam will always load the first matching module.
This can lead to problems in the case of modules with the same name, by loading the wrong module.
An example for this problem would be the case when we try to check the refactoring of some standard library function.
In this case, we have to make sure that the module in question is loaded before its standard library counterpart.

To achieve this, we have to explicitly set the right module path.
The `code` module, which is part of the standard library, contains functions that can modify the load path of an already running beam instance.

- Namespace collisions
- Sticky path

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
We solve this problem by implementing our own *group leader* process, which is responsible for capturing any output.
The group leader is the process that manages anything IO-related, by receiving and sending messages to other processes.
Each time a process wants to write to the standard output, an `io_request` message is sent to the group leader, which will process this message, and execute the requested operation.
It's possible to replace this process with out own, overriding the behaviour of IO.
TODO sending back the request to the process that does the comparison

- Group leader
- Catching IO

# Parallel Programs

- Erlang message-passing
- Lightweight processes
- Actor model
- Mailboxes

## Parse Transform

When parallelism and message-passing is taken into consideration, examining the behaviour of some isolated part of a broader system becomes TODO
Take for example the case of a function that receives a message, and based on its content, does some computation.
Without the context it depends on, this function will never terminate, because the process will block the first time it tries to read from its empty mailbox.
Processes can also send messages, and while sending a message always succeeds, even if it will never be received, so non-termination is not a problem, we would ideally take these messages into consideration when deciding if the functions behave the same.

To solve these problems we used a technique called *parse transform*.
Parse transform allows us to make arbitrary modifications to the program in the compilation phase.
TODO

To solve the problem of receiving messages, we need to fill up the mailbox, before the process tries to read from it.
As we did before for function arguments, we can use PropEr again to generate random messages.
Another important thing to realize is that nothing stops a process from sending messages to itself.
What we need to do is to modify the function to generate random data with PropEr, send these messages to itself, so it's mailbox won't be empty, and then go on with its original implementation: `receive` -> `self() ! RandomData, receive`.
TODO wrong kind of data, no match

For solving the problem of sending messages, we can reuse what we already did to capture IO.
In this way, the only thing needed is to modify the program, so that every time it sends a message, it will also print it to the standard output: `Pid ! Msg` -> `Pid ! (print Msg, Msg)`.
The group leader that captures the output will take care of this message, so it will be included when the equivalence is checked.

## Comparison of Messages

Messages can contain data that can vary based on the context, but we would ideally exclude them when checking equivalence.
An example for this is the process id (PID).
Processes often send their PID, so the receiving process knows where to send a reply if needed.
For our purposes, the PID can be considered as a unique ID, which changes every time the process is created.
As PIDs are unique, they would make any message containing them differ.
We solve this problem by traversing each message sent, and replacing any occurrences of PIDs with an atom.
TODO there could be other similar things, further work needed

# Results

- EquivchekEr

# Future Work

- not only messages, but also signals:
    - https://www.erlang.org/doc/reference_manual/processes.html

# References

- [PEQtest](https://link.springer.com/chapter/10.1007/978-3-030-99429-7_11)
- [PEQcheck](https://arxiv.org/abs/2101.09042)
- [TypEr paper](https://user.it.uu.se/~tobiasl/publications/typer.pdf)
