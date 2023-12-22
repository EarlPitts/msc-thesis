# Concurrent Programs

Up until this point, we have only considered sequential programs when checking equivalence.
Arguably, Erlang's main advantage, compared to other languages is its ability to express massively concurrent systems without much effort on the part of the user.
Compared to most other languages, where language features for expressing concurrency were incorporated into the language after the fact, Erlang made these part of the core language from the start.
The way in which considerations regarding multiple threads of execution drove design decisions, resulted in simple and elegant ways for expressing concurrency.
The most prominent result of these decisions is that systems written in Erlang are notoriously robust and highly fault-tolerant.

The BEAM, the virtual machine that Erlang programs run on, implements concurrency using the *actor model*.
In contrast to shared-memory concurrency, where each thread of execution can mutate a shared, global state, actors are not allowed to directly access the memory of other actors.
Each actor has its own, private memory, and communication between actors is accomplished by *message-passing*.
(There are some other channels of communication that doesn't make use of message-passing in this sense. This point is described in more details in the further work chapter.)
Actors have their own *mailbox*, which can be thought of as a queue, which stores incoming messages.
Any actor can send a message to another one if it "knows" its unique id.

This compartmentalization of actors to their own memory space makes each computation done by the actor localized, in the sense that actors cannot invalidate some invariant of other actors by accidentally modifying their memory space with incorrect data.
This independence of actors from each other is the very reason that makes Erlang programs exceptionally robust.
If an actor malfunctions, it can simply be restarted, without affecting the other parts of the system.

It's also important to mention that unlike most other runtimes that use the operating system to create new threads, the BEAM has its own scheduler, and it creates its own processes.
These lightweight processes have much smaller overhead and memory footprint compared to OS threads, and its not uncommon for applications running on the BEAM to have thousands or even hundreds of thousands of processes running concurrently.
This level of concurrency would not only be extremely hard to manage with shared-memory, but due to the need of locking, it would also be very inefficient.

Because of this ease, with which one can create programs that are highly concurrent in their nature, most programs written in Erlang at least some kind of concurrent behaviour.
As our goal is to provide a way to check refactorings of any Erlang program, it was necessary to widen our scope to the language constructs that create these concurrent behaviours.

This chapter first describes how we used parse transformation, introduced in $\ref{parse-transformation}$, to create the necessary context that processes expect.
Then we go over some problems related to certain types of messages being slightly different based on the sending process, and our proposed solution for these issues.

## Setting Up The Context

When concurrency and message-passing is taken into consideration, examining the behaviour of some isolated part of a broader system becomes insufficient.
Take for example the case of a function that receives a message, and based on its content, does some computation.
Without the context it depends on, this function will never terminate, because the process will block the first time it tries to read from its empty mailbox.
Processes can also send messages, and while sending a message always succeeds, even if it will never be received, so non-termination is not a problem, we would ideally take these messages into consideration when deciding if the functions behave the same.

To solve these problems we used a technique called *parse transform* (see $\ref{parse-transformation}$).
Parse transformation allows us to make arbitrary modifications to the program in the compilation phase.
This allowed us to modify the behaviour of the program when tested, setting up the necessary context and altering the semantics of communication between processes.

While using parse transformation gives us nearly limitless flexibility and freedom to make arbitrary modifications to programs, it's exactly this expressiveness that makes it easy to misuse.
By itself, the Erlang standard library only provides very basic tools for implementing parse transformations, so we decided to use a third-party library called `parse_trans` $\cite{parse_trans}$ to make the implementation of parse transformations easier.

For receiving messages, we need the mailbox to already contain some messages, so the process won't block while trying to read from it and finding it empty.
As we did before for function arguments, we can use PropEr again to generate random messages.
Another important thing to realize is that nothing stops a process from sending messages to itself.
We can use this fact to our advantage, and modify the function to generate random data with PropEr, send these messages to itself, so it's mailbox won't be empty, and then go on with its original implementation: $\lstinline{receive} \rightarrow \lstinline{self() ! RandomData, receive}$.

It's also important that the two functions get the same messages put into their mailbox before they are evaluated.
The default behaviour of PropEr is to generate random data by first seeding the generator with a timestamp taken from the operating system.
This seed can also be specified in the form of a function argument.
By using the same seed when generating data for filling up the mailboxes, we can make sure that the functions will receive the same messages in the same order.

While this method can work, it doesn't cover all the possibilities.
When a process tries to read from its mailbox, it can optionally match on the structure of the message, and guards can also be used to decide if a message will be consumed or not.

\lstset{caption={Receive syntax}, label=src:erlang}
\begin{lstlisting}[language={Erlang}]
receive
    Pattern1 [when GuardSeq1] ->
        Body1;
    ...;
    PatternN [when GuardSeqN] ->
        BodyN
end
\end{lstlisting}

The naive way of generating completely random data can easily result in cases where none of the generated messages match the given structure and predicate.
When this happens, the function evaluation will be stopped, and their behaviour will be considered equivalent, as we don't have enough information to say otherwise.
A better solution would be to analyse the `receive` block, and only generate data that conforms to the expected form.
This could improve accuracy by eliminating false negatives.
Unfortunately we didn't have enough time to explore this possibility.
Currently random data is generated by PropEr using the `any()` type, which doesn't add any constraints for the shape of the generated data.

For solving the problem of sending messages, we can reuse what we already did to capture IO.
In this way, the only thing needed is to modify the program, so that every time it sends a message, it will also print it to the standard output: $\lstinline{Pid ! Msg} \rightarrow \lstinline{Pid ! (print Msg, Msg)}$.
The group leader that captures the output will take care of this message, so it will be included when the equivalence is checked.
Messages with a non-existent target are simply ignored by the runtime.

## Comparison of Messages

Messages may also contain data that can vary based on the context, but we would ideally exclude them when checking equivalence.
An example for this is the process id (PID).
Processes often send their PID, so the receiving process knows where to send a reply if needed.
For our purposes, the PID can be considered as a unique ID, which changes every time the process is created.

The problem is that when we evaluate the two versions of a function, each of them is given a PID that's unique for the node it runs on.
Although it's possible that the two processes get the same PID assigned to them by their runtime, we cannot expect this to happen every time.
If the function is implemented in a way that it sends its PID to some other process, then the messages we compare will likely be different, even though their observable behaviour will be indistinguishable.
We solve this problem by traversing each message sent, and replacing any occurrences of PIDs with the same atom (`pid`).

Although we provided a solution in the case of process IDs, there could be other kinds of context-dependent data, that can be considered irrelevant for the purposes of equivalence checking.
We would ideally like to eliminate any source of non-determinism that could lead to false positive findings.
Even things like generating pseudo-random numbers or creating a timestamps could lead to incorrectly concluding that two functions behave differently.

Due to the limited time we had, we couldn't investigate this problem further, but we strongly suspect that more work will be needed to identify other similar cases.
