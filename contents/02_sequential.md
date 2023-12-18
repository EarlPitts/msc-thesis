# Sequential Programs

Taking the whole language with all of its features would lead to a much bigger problem than necessary. 
To avoid this complexity, we applied a more iterative approach, by taking only a subset of the language at first, and gradually increasing our scope to include bigger and bigger subsets.

First, we wanted to examine the subset of the language without any features related to concurrent behaviour.
This meant that the programs we examined can only have one single process at any time, with anything related to starting or stopping processes and communication with processes explicitly disallowed.
This makes the problem of checking semantic equivalence considerably easier.

To further decrease complexity, we started by first examining simpler refactorings, like function renaming.
This allowed us to have a working proof of concept at every stage of the project, and use the data we gathered by observing the current solution to further improve upon our design.

This chapter elaborates on the main problems we had to solve when considering only sequential programs, and our proposed solutions for these problems.

## Determining the Parts to Test

Evaluating the whole application after each refactoring would take a considerable amount of time, which would be unfeasible in practice.
This problem is painfully obvious when the refactoring has only affected a very small portion of the codebase (e.g.: renaming some local variable).
Such localised changes shouldn't require the execution of the whole application.

There is also another, more fundamental problem with this naive approach, namely the possibility of non-terminating programs.
Erlang is not a total language, and most Erlang applications are non-terminating programs, like web or telecommunication services.

While in the case of terminating functions it's easy to check their return values and their effects on the environment when deciding if they are equivalent, in the case of functions that do not terminate, our only option is to examine their effects before we eventually stop their evaluation.
In this way, it's possible to prove their nonequivalence in a finite amount of time, but
establising their equivalence is theoretically impossible, because their behaviour could differ at any point in time, so we can never stop the comparison.

To avoid these problems, we need some other, more principled way to separate the parts of the program that were affected by the refactoring, and focus only on these, and we also need some way to deal with non-termination.
The latter we solved simply by imposing a time limit, after which we stop the evaluation of the function, and conclude that we don't have enough information to decide if they are equivalent or not.
We think it's possible to use this strategy while also comparing the effects of the functions, making it possible to disprove equivalence (but never to prove it), which is described in the further work section.
For separating the part that's relevant for us, we take a subset of the program (the slice), according to some *slicing criterion*, which in our case are those parts that were affected in any way by the changes.
To determine this subset, we use a number of different static analysis tecniques.

First we compare the textual representation of the program to locate all the changes.
We do this by the UNIX `diff` utility, which finds the discrepancies between given text files.
Then we use the source files and the abstract syntax tree to identify each function definition that was altered by the change.
This subset of functions is the initial slice that we start with.
These are the functions that were directly affected by the refactoring, but that doesn't mean that we don't have to check other functions.
These functions are possibly called by other functions, and ideally we would like to know about all functions that don't work as expected.

To do this, we separate the functions into two separate groups: those that have the same function signature as the original one (same name, same number and type of parameters), and those that had their signature changed by the refactoring.
The reason for this categorization is that it's possible that a function with its signature modified has callers that haven't accomodated this change.
Take function renaming for example, which changes the function's signature by replacing its name.
Renaming a function doesn't alter its behaviour, but it can have unwanted effects in the broader context of functions that call it.
It's possible that some of the callers haven't been modified by the refactoring, and they still refer to the function by its original name.

Consider the following example:

\lstset{caption={Original source}, label=src:erlang}
\begin{lstlisting}[language={Erlang}]
g(X) -> f(X,X).

h(X) -> f(X,X+2).

f(X,Y) -> X + Y.
\end{lstlisting}

\lstset{caption={Wrong refactoring}, label=src:erlang}
\begin{lstlisting}[language={Erlang}]
g(X) -> i(X,X).

h(X) -> f(X,X+2).

i(X,Y) -> X + Y.
\end{lstlisting}

In this example, we have a function named `f`, which adds its two arguments together.
We also have two other functions, `g` and `h` calling `f`.
We refactor this code by renaming `f` to `i`, but we forget to accomodate this change in `h`, so it still refers to `f`.
This change doesn't affect the behaviour of `f` (or now `i`), but running the program after this refactoring would probably lead to unwanted behaviour.

To get the callers of a function, we use Wrangler, which can generate the whole callgraph for a given codebase.
The callgraph represents the caller/callee relations between the functions in program.

Its possible that some callers also have their signature changed.
In this case, we iteratively expand the set of functions to test.

Another important feature, for which we unfortunately didn't have the time to implement, would be to compile modules on-demand.
This point will be described later in the section on opportunities for further work.

## Module Path

When a function is called, the BEAM Erlang runtime first have to find the corresponding bytecode for it.
It does this by looking for modules that may contain it from a list called the *module path*.
The module path is an ordered list of directories, where bytecode may reside.
The BEAM will always load the first matching module.

By modifying the module path, we can control the way in which a node finds the modules to run.
This is how we assure that each node executes the right version of the program.

To achieve this, we have to explicitly set the right module path.
The `code` module, which is part of the standard library, contains functions that can modify the load path of an already running BEAM instance.

This can also lead to problems in the case of modules with the same name, by loading the wrong module.
An example for this problem would be the case when we try to check the refactoring of some standard library function.
In this case, we have to make sure that the module in question is loaded before its standard library counterpart.

During our experiments with modifying the reload path, we also stumbled upon a feature called the *sticky path*.
The purpose of the sticky path is to prevent accidental reloading of modules related to more basic parts of the runtime, like the standard library, the kernel, the compiler, etc...
To reload these modules, we had to explicitly "unstick" them first, which can be done with the `code:unstic_dir/1` function.
(*While writing this thesis, I realized that it's also possible to turn off this feature by using the `-nostick` flag when starting the runtime.
An issue for further investigation was promptly created.*)

## Type Inference

Erlang is a dynamically typed language, meaning that the types of values are only known at runtime.
It also supports type annotations, provided by the user, but as the Erlang runtime has no type checking in itself, and nothing enforces correct annotations, these are frequently omitted.
Preferably, we would like to know the type of data a specific function accepts, so we can generate input that will result in normal values.
Randomly generating arguments usually leads to runtime errors (type mismatch, pattern matching failing, etc...), which, although it can indicate nonequivalence, is most of the time not enough information to make a definitive decision.

Erlang doesn't forbid defining partial functions (it couldn't check partialness even in principle, due to its dynamic typing), so it's possible to define functions that can handle only a few elements of their domain, resulting in runtime errors otherwise.
The ratio of erroneous and successful function evaluations depend on the size of the function's domain, and the number of elements it can handle from that domain.

We want to maximize the number of evaluations that result in normal execution, giving us values we can compare for equivalence.

*Success typing* $\cite{success_typing}$ is a constraint-based type inference algorithm.
It starts with the type of every possible term, then successively narrows it down, based on constraints from the term's context.

We use a working implementation of success typing called *Typer* $\cite{typer}$, which can work on individual source files, although it requires already evisting type information generated by Dialyzer $\cite{dialyzer}$.

Dialyzer works by first generating a so called Persistent Lookup Table (PLT), which contains the results of its preliminary analysis.
The PLT then can be used later for various kinds of static analysis.
TypEr uses the generated PLT to infer the type of functions.

In cases where success typing fails to find a specific type, we fall back to the `any()` type.
`any()` is the top type of Erlang, so it's inhabited by every possible term in the language.
By using `any()` as the fallback, it's possible to still generate data, even in the lack of type information, although in most cases this will result in runtime errors.

## IO

Up until now, we were only considering the equivalence of programs without side-effects.
Although Erlang is considered as a functional language, nothing stops the user from reading from, or writing to the standard output, to the disk, to some socket, or having any other kind of uncontrolled side-effect.
Apart from some special cases (like guards), IO is allowed anywhere in Erlang programs, and there are generally no indications, either conventional (like function names ending in '!' for lisps), or forced by the compiler (like monadic IO in languages like Haskell), that a given function has side-effects.
To extend the notion of equivalence to include side-effects, we can keep track of any effects that a spcefic function had on its execution environment, while still taking note of the value it returned.
To check if the two functions are equivalent, we compare the effects, together with the return value.

Because we cannot know beforehand if a function will do IO when evaluated, we have to treat every function as one that can potentially have side-effects, and observe these effects for the purposes of checking the equivalence.
We solve this problem by implementing our own *group leader* process, which is responsible for capturing any output.
The group leader is the process that manages anything IO-related, by receiving and sending messages to other processes.
It's possible to replace this process with our own, overriding the way in which IO works.

Each time a process wants to write to an IO device, an `io_request` message is sent to the group leader, which will process this message, and execute the requested operation.
When our modified group leader gets this request, it simply finds the exact string the process wanted to be written to IO device, and sends it to the process that evaluates the function.

For functions requesting input from standard input, or from any other source, the group leader simply replies with an error message, stopping the evaluation of the function.
The reason we decided against generating random data for input is the fact that strings have very little structure, their space is infinite, and the chance of generating relevant data is negligible in most cases.
 
\lstset{caption={Custom group leader for handling IO}, label=src:erlang}
\begin{lstlisting}[language={Erlang}]
% Custom group leader for sending all io_request to specified process
% and ignoring any input
capture_group_leader(Pid) ->
    receive
        {io_request, From, ReplyAs, O} when element(1,O) =:= 'put_chars' ->
            From ! {io_reply, ReplyAs, ok},
            Pid ! {io, O},
            group_leader(self(), self()),
            capture_group_leader(Pid);
        {io_request, From, ReplyAs, _} ->
            From ! {io_reply, ReplyAs, {error, 'input'}},
            capture_group_leader(Pid)
    end.
\end{lstlisting}

## Semantic Equivalence Property

The property we use for checking function equivalence is simply the equivalence of the effects of the functions, together with their return value.
The comparison uses the Erlang's equivalence operator (`=:=`), that works on primitive data types in the usual sense of equivalence, and compares the whole structure for composite types.
Effects are collected into a list, in order, so they can be checked by comparing these lists in a similar manner.

\lstset{caption={Property used for establishing function equivalence}, label=src:erlang}
\begin{lstlisting}[language={Erlang}]
proper:quickcheck(?FORALL(Xs, Type, prop_same_output(OrigNode, RefacNode, M, F, Xs))).

% Spawns a process on each node that evaluates the function and
% sends back the result to this process
prop_same_output(OrigNode, RefacNode, M, F, A) ->
    {Val1,IO1} = peer:call(OrigNode, testing, eval_proc, [M, F, A], ?PEER_TIMEOUT),
    {Val2,IO2} = peer:call(RefacNode, testing, eval_proc, [M, F, A], ?PEER_TIMEOUT),

    Out1 = {Val1,IO1},
    Out2 = {Val2,IO2},

    Out1 =:= Out2.
\end{lstlisting}

In this way, semantic equivalence of functions can be checked, with the caveat that we generally cannot prove, only disprove it.

Testing is done by PropEr, which by default generates 100 test cases before it concludes that the property couldn't be disproved, although this number can be increased as needed.
When PropEr finds a test case for which the results are not equivalent, it automatically tries to shrink it to the simplest case.

When the counterexample is found, we know that the two functions are not semantically equivalent, and based on whether the function signature has also changed, we either stop the process, or we increase our scope to include the caller functions too.
