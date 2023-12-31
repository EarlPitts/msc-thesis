# Introduction

Refactorings are program transformations that preserve the semantic meaning of the original program.
The purpose of refactoring is to improve the structure of already existing source code, based on some criteria (usually readability).
This thesis presents a way for checking if refactorings do in fact preserve the functional equivalence of programs before and after some refactoring transformation, without introducing bugs.
We also provide an implementation with some promising results, although more work is needed for it to be used in real-world applications.

## Motivation

Refactoring the source code of a program can either be done manually, or using some kind of refactoring tool, that automatically does the refactoring for us.
Manual refactoring is usually a tedious and error-prone process, and there is a high chance of bugs will be introduced.
It's also very mechanical in its nature, and it's this property of being relatively easy to automate in most cases is what refactoring software tools take advantage of.
Unfortunately these tools can also have bugs, leading to incorrect refactorings, and they are also constrained in the set of available refactorings that can be done by them.
For transformations that are unsupported by these tools, manual refactoring is our only option.
For these reasons, it would be nice to have some way for checking if the refactoring was correct, in a sense that no bugs were introduced (or removed) by the refactoring, and two programs (the original and the refactored one) are functionally equivalent.
In real-world software development projects, this is usually done by running some already existing test-suite, hoping that it will catch any new errors introduced by the refactoring.
Although this could seem at first as a reasonable way to deal with this problem, it's not perfect for two reasons: test coverage for most software application is not complete, meaning that we can't guarantee that the relevant parts of the codebase will be exercised by the test-suite, and running all tests for some localized refactoring can be extremely inefficient (e.g.: renaming a single local variable).
In the worst case, it's possible that the test-suite takes a significant amount of time and resources to execute, while completely missing the parts of the program that were affected by the refactoring.
What would be ideal is some more sensible way that specifically targets code that was changed (either directly or indirectly) by the refactoring, and automatically tests these parts with generated data.
This "more sensible way" is what the present thesis tries to elaborate on.

## Outline

Chapter $\ref{background}$ contains a general overview of the various techniques and tools used.
In Chapter $\ref{sequential-programs}$, we elaborate on our approach for testing the equivalence of refactored programs that contain no language features related to concurrency.
Then in Chapter $\ref{concurrent-programs}$, we extend the range of refactored programs to also include ones with concurrent features.
This partitioning is due to the fact that introducing concurrency into the programs in question leads to a whole new set of problems related to functional equivalence.
We close by summarizing our results in Chapter $\ref{results}$, discussing how we evaluated our implementation in Chapter $\ref{evaluation}$, and in Chapter $\ref{future-work}$, we give some recommendations for further work.

# Background

The aim of this chapter is to familiarize the reader with the different tools and techniques used.
Section $\ref{erlang}$ describes Erlang.
Section $\ref{refactoring}$ is about the concept of refactoring, it's relation to other kinds of program transformations, and it's main properties.
In section $\ref{semantic-equivalence}$, we define what we mean by program equivalence.
Section $\ref{property-based-testing}$ introduces property-based testing and PropEr, a testing tool based on these principles.
Section $\ref{slicing}$ describes program slicing by giving a simple example of it.
Section $\ref{parse-transformation}$ is about an Erlang specific feature called parse transformation.

## Erlang

Erlang $\cite{erlang}$ is a functional, strict, dynamically typed, general-purpose programming language.
It was developed by Ericsson, specifically for implementing telecommunication services.
As telecommunication services require high levels of fault-tolerancy, hot-swapping (replacing code in running systems), and distributed systems, Erlang took these traits, and incorporated them into its core design.
For the purposes of this thesis, what turned out to be the main difficulty was Erlang's dynamic type-system, as we will see later.

## Refactoring

"Refactoring is the process of changing a software system in such a way that it does not alter the
external behavior of the code yet improves its internal structure. It is a disciplined way to clean up
code that minimizes the chances of introducing bugs. In essence when you refactor you are
improving the design of the code after it has been written." $\cite{refactoring}$

The main difference between refactoring and other kinds of program transformations is that while syntactically the structure of the program changes, the semantic meaning is meant to remain intact.
There are other kinds of program transformations (e.g.: optimization) that preserve the semantic meaning, but while in the case of optimization, our goal is to make the structure of the program "easier to read" for the computer it runs on, refactoring usually tries to make the source easier to read for the programmer.
What's important to emphasize is that no bugs should be introduced in the process of refactoring.

Refactoring can be done manually or with refactoring tools like Wrangler $\cite{wrangler}$.
Tool-assisted refactoring is usually done by the user first selecting the part of the source they wish to refactor, then specifying the type of refactoring they want.
For example, consider this code snippet:

\lstset{caption={Fibonacci sequence in Erlang}, label=src:erlang}
\begin{lstlisting}[language={Erlang}]
fib(0) -> 1;
fib(1) -> 1;
fib(X) -> fib(X-1) + fib(X-2).
\end{lstlisting}

This is an implementation of the well-known Fibonacci sequence.
If we want to rename the X variable to, for example, Y, we would select the variable in the source, and tell Wrangler to rename it to Y, which would result in the source being changed to:

\lstset{caption={Fibonacci with renamed variables}, label=src:erlang}
\begin{lstlisting}[language={Erlang}]
fib(0) -> 1;
fib(1) -> 1;
fib(Y) -> fib(Y-1) + fib(Y-2).
\end{lstlisting}

This change clearly doesn't affect the behavior of the program in any way.
It's always possible to change the name of some bound variable, provided we do it in way that respects capture-avoidance.

In the previous example, the refactoring is trivially correct, but there are examples of refactorings that are way more involved.
In general, the refactoring tool has to check a number of *side-conditions*, such as avoiding capture.
These conditions ensure that the refactoring can be done in a way that preserves behavioural equivalence.

The way Wrangler works is that it first builds a *semantic graph* of the refactored program.
The semantic graph is basically the Abstract Syntax Tree (AST) of the program, annotated by additional information that helps Wrangler in the refactoring.
After the semantic graph is created, Wrangler checks the side-conditions to see if the requested refactoring is possible.
If it is, the refactoring is applied to the semantic graph, which is then translated back to the AST, and the original source is replaced by the refactored one.

## Semantic Equivalence

Semantic equivalence is a relation between two programs, that expresses whether they behave in the same way when executed in the same context.
(Although it's important to note that this notion of equivalence completely ignores the question of efficiency, which can be easily seen by considering optimizations, which themselves are a form of program transformation that preserve semantic equivalence.)
The semantic equivalence of two programs can be established by considering their output for each input in given context.
For pure functions (meaning subroutines without side-effects), this property is precisely the one of *eta-equivalence* of functions.
For functions with side-effects, we also have to check if any external-facing effects done by the two functions are the same.
Erlang is not a pure language, and it's easy to have arbitrary side-effects anywhere in the program.

Rice's theorem states that all non-trivial semantic properties of programs are undecidable.
Unfortunately, semantic equivalence is far from being trivial, so it's also generally undecidable.
To get around this problem, we have two options: either we only consider cases where semantic equivalence can be decided, and thus formally proved, or we approximate by running a large number of tests, and try to prove that the two programs are nonequivalent.
Our approach focused on the latter one.

When considering this approach, the main questions were the following:

- How to generate well-typed data for evaluating the functions?
It's easy to see that generating input data in a completely random fashion would result in most if not all the execution leading to runtime errors, which provide little information when we are considering the equivalence of the functions.
This problem would be trivial in a language with a stricter typing discipline, like Haskell, but Erlang is unfortunately (for us) a dynamically typed language.

- What if the generated data, although well-typed, is still not specific enough?
It's possible that even if we generate well-typed data, it's data that the function is not prepared to handle, resulting in runtime errors.
Take for example a function that pattern-matches on a single integer input, but only does meaningful computation if the input is 42.
All other values lead to an exception for trying to pattern match on an undefined case.
Our chances are slim that we stumble upon this single value by chance.

- How to recreate the same context for the two functions?
Functions are usually run in some context.
Even if we only consider pure functions, we have to be able to refer to unbound variables, and we need some context where we can find these.
When we consider functions with side-effects and concurrency, it's even more important to be able to provide some controlled environment for the function, where we can observe its behaviour.

- How to compare functions with side-effects?
This problem is related to the previous one in the sense that we need to consider the function together with the context it's evaluated in.

- What about non-terminating functions?
Not all functions terminate, and this is especially true in the context of distributed telecommunication services.
How should we check the equivalence of functions that don't have return values we can compare?

There are cases where this approach can decide that two functions are equivalent (e.g.: functions with a finite domain, like a single boolean value), but generally we can only say that we failed to show otherwise.

## Property-Based Testing

There are two different approaches when we are talking about proving program properties: formal proofs and testing.
While testing is not considered as giving a proof in a strict sense, nevertheless it can still provide some evidence that the properties we want to prove hold, which can be made arbitrarily strong by making the number of test cases higher.
Testing can also disprove properties by finding a counterexample, when it is not in fact provable.
It also has the advantage of requiring less expertise, and being easier to automate.

Property-based testing is a technique that combines traditional unit tests with the ability to generate test data automatically.
One implementation of this technique is `PropEr` $\cite{proper}$, an open-source tool we used for this purpose.
The reason we chose PropEr, instead of the more mature QuickCheck is because QuickCheck is a commercial software, while PropEr is a free, open-source alternative.
PropEr allows the user to state program properties in Erlang source code, which will then be checked by generating random data using *generators*.
These generators are provided for the primitive types, but it's also possible to extend PropEr by implementing our own generators.

Take for example the functor laws, which can be stated by the following properties with PropEr:

\lstset{caption={Functor law properties}, label=src:erlang}
\begin{lstlisting}[language={Erlang}]
prop_functor_id() ->
    ?FORALL(L, list(int()), lists:map(fun(X) -> X end, L) =:= L).

% Provided that f and g are valid int() -> int() functions
prop_functor_composition() ->
    ?FORALL(L, list(int()),
        lists:map(fun(X) -> f(g(X)), L) =:= lists:map(fun f/1, lists:map(fun g/1, L)).
\end{lstlisting}

In this example, we use the `list(int())` generator to randomly generate lists of integers, and we check the property that the two resulting lists are equal, using Erlang's built-in equivalence operator.
PropEr generates 100 cases by default (if no counterexample is found sooner), but this behaviour can be modified.
When an example is found, for which the property doesn't hold, PropEr first tries to *shrink* the counterexample, meaning that it attempts to reduce the counterexample it found to the most trivial one that still invalidates the given property.

## Slicing

The technique of taking some subset of a program, based on some property we are interested in, is called *program slicing* $\cite{slicing}$ in the literature.
It has multiple applications in the context of static analysis, where it can be used for dependency analysis, dead code elimination or program optimization, among other things.

The subset of the program is called the *slice*, and the property is usually called the *slicing criterion*.
One such criterion, that is relevant for our purposes, is the one that selects a path from the *callgraph* of the program.
The callgraph is a directed graph, where each node represents a function, and the edges between nodes indicate a caller/callee relation, where the edge points from the caller to the callee.

\begin{figure}[H]
	\centering
	\includegraphics[width=0.9\textwidth,height=300px]{callgraph}
	\caption{A callgraph (nodes represent functions, edges represent calling relationships)}
	\label{fig:example-2}
\end{figure}

Take for example the following program:

\lstset{caption={Example caller/callee relations}, label=src:erlang}
\begin{lstlisting}[language={Erlang}]
f() -> g().

g() -> h().

h() -> ok.

j() -> i().

i() -> ok.
\end{lstlisting}

If we select the criterion to be the transitive closure of the relation of calling `h` explicitly, or calling a function that is already part of the closure, then the slice we get contains `f`, `g` and `h`.

The function `i` and `j` are not in this slice, because they don't call `h`, or any other function that transitively calls `h`.

## Parse Transformation

Parse transformation is a feature of the Erlang compiler, which allows the user to apply arbitrary transformations to the AST in the compilation phase, as long as the resulting AST consists of valid Erlang syntax.
Parse transformations can be invoked using the `-compile({parse_transform, Module})` compiler option, where `Module` is the module where the parse transformation is implemented.

When the `parse_transform` option is specified, the compiler will first parse the source code, then it uses the specified module to do the transformation, and it compiles the newly created AST to bytecode.

An example for a simple parse transformation that modifies the original code by adding a new clause to every function, can be seen here:

\lstset{caption={Example parse transformation, adding a clause to functions}, label=src:erlang}
\begin{lstlisting}[language={Erlang}]
-module(add_clause).
-export([parse_transform/2]).

parse_transform(Forms, _Options) ->
   lists:map(fun add_clause/1, Forms).

add_clause({function, Line, Name, Arity, Clauses}) ->
   NewClauses = Clauses ++ [{clause, Line, [], [], [{atom, Line, ok}]}],
   {function, Line, Name, Arity, NewClauses};
add_clause(Other) ->
   Other.
\end{lstlisting}

The added clause matches any input, and gives back the atom `ok`.
This transformation will recursively traverse the whole AST, and apply the `add_clause/1` function for each term in it.
If the given term represents a function, then the new clause is added by appending it to the end of the original ones.
In every other case the term is returned without any modification.
