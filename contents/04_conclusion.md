# Results

The main result of this thesis is an open-source tool, which we named EquivcheckEr $\cite{equivchecker}$.
This tool can still be considered as a proof-of-concept, and more work is needed for it to be feasible in practice, but it already shows promising results.

As one of the main goals of this project was to provide a tool that can be adopted by the Erlang community, we had to make sure that its usage is sufficiently straightforward from a user's point of view.
In accordance with this, with made sure that the tool has a low barrier of entry, and can be used by non-experts.
We tried to provide sane default configurations, but enable the user to change these if needed.

In addition to the command-line tool that constitutes the majority of EquivcheckEr, we created an interface for it inside the Visual Studio Code (VSCode) $\cite{vscode}$ editor.
In this way, it's possible to use EquivcheckEr during the development phase by running it inside the editor, but it can also be part of automated software pipelines, increasing software quality standards.

Our hope is that EquivcheckEr will be adopted by the Erlang community, and it will be integrated seamlessly into the workflow of Erlang developers.

## EquivcheckEr

In this section, we briefly present EquivcheckEr, its main use-cases, the command-line and VSCode interfaces and the existing configuration options.

### Installation

Currently the only way to install EquivcheckEr is to manually compile it from the source code, which can be found on GitHub $\cite{equivchecker}$.
We used Rebar3 $\cite{rebar}$, a build tool for Erlang, so libraries that EquivcheckEr depends on will be automatically downloaded.
Further details can be found on EquivcheckEr's $\href{https://github.com/harp-project/EquivcheckEr}{GitHub\ page}$.

EquivcheckEr only supports UNIX-like systems.
While its possible that this will change in the future, we do not consider support for other platforms as a priority.

### Command-Line Interface

The main way to use EquivcheckEr is through its command-line interface, but we also started working on a VSCode plugin that integrates it into the editor itself, which is described in the next section.

The currently supported options can be seen in the generated help text:

TODO  Pics

As one of our main goals was to make the tool user-friendly, we prioritized integration with other tools used by most software developers, so new users wouldn't be expected to fundamentally change their familiar workflows.
In accordance with this, EquivcheckEr is aware of existing Git $\cite{git}$ source repositories.
This makes it possible to compare different versions of the same codebase using the commits made in Git.
Commits can be specified using the `--commit` flag.

TODO Pics

It's also possible to compare folders containing the source code when the flag is omitted, or mix the two methods (i.e.: compare a commit made in a respository to a folder).

TODO Pics

The default mode, which gets invoked when no source and target is specified, is to compare the current folder with the latest commit (assuming the current folder is also a Git repository).

There are also two options that modify the output: `--json` and `--statistics`.

When the `--statistics` flag is used, the output will also contain information about the number of failed check and the average number of tests needed before finding a counterexample.

- TODO Pics

When the `--json` flag is used, EquivcheckEr will format its output as JSON.
This can be useful in the case automation, when the output will be consumed by other programs.
This is also what we used for providing the Visual Studio Code interface, that we will now describe.

After running the tool with valid parameters, the output will contain all the functions that it found to be semantically different after the refactoring, if any.
It also provides the counterexamples for each.

### Visual Studio Code Interface

While we tried to make the command-line interface as user-friendly and convinient as possible, we also realize that most software developers are more familiar with GUI applications and modern IDEs, and are sometimes hesitant to use more traditional, text-based interfaces.
If automation is not needed, a GUI interface could be a perfectly viable way to use the tool.
To cater to the needs of both groups, we started working on an editor integration that can be used without the need to issue commands on the command-line.

We chose the VSCode editor as our target platform, as it probably has the most users among modern editors/IDEs.
VSCode is built with Electron $\cite{electron}$, a cross-platform GUI framework based on web technologies.

VSCode can be extended by developing extensions for it, written in TypeScript $\cite{typescript}$.
It has a fairly extensive extension API, that gives control over most aspects of the editor.
VSCode also has the *Visual Studio Marketplace*, where extensions can be published for other users.
The EquivcheckEr VSCode integration is currently in a very early phase, and not available on the marketplace, but we are intending to make it availabe once it's ready for use.

After installing the extension, a button for EquivcheckEr will appear in the statusbar:

TODO Picture of the button

When the user clicks the button, EquivcheckEr will be started as an external process.
Fow now, only the default behaviour of the CLI tool is supported, which compares the current state of the working directory to the latest commit in version control.
An notification will also be displayed to the user, indicating that the equivalence checking has started:

TODO Picture of the notification

When the checking is finished, the output of the process, formatted as JSON, is parsed and presented to the user in a new window as a simple Markdown text buffer:

TODO Picture of the output

Although the specifics of this behaviour is subject to change, the basic workflow will probably remain the same, only with more customizability.

### Configuration

The tool currently has rudimentary configuration capabilities.
It tries to locate the configuration file inside the `XDG_CONFIG_HOME` folder, as speficied by freedesktop.org $\cite{freedesktop}$.
This currently limits usage to UNIX-like systems, where the XDG Base Directory Specification is used.

At time of writing this theses, the only configurable option is the location of the persistent lookup table, used for type inference.
Normally the tool uses the default location of the PLT, but if needed, the user can override this behaviour by specifying a custom location for it.

# Evaluation

During the project, we tested the tool on a number of different refactorings.
We started by checking the correctness of function renamings, then we gradually broadened our scope.

Our approach was to create fairly small and simple examples, introduce errors into their refactoring, and see if the tool could find the error.
This has resulted in a rather tight feedback loop, where we could readily see the effects of implementing a feature or fixing some bug had on the output.

Later during the project we started experimenting with larger codebases downloaded from GitHub.
We made some refactoring changes to them, either correct or incorrect, and examined the output.
This approach also provided valuable feedback regarding the feasibility of the tool.

One such feedback was the time it took for the checking to finish.
Initially our implementation was sequential, meaning that comparisons of functions was done one-by-one.
Although this wasn't a problem at smaller examples, it proved to be a bottleneck when we considered larger codebases.

After doing some analysis of running times, we decided on redesigning our architecture to make use of the BEAM's concurrency capabilities.
Using a CPU with 8 cores, we could run the comparisons in parallel.
This made the checks run much faster, making the tool more usable overall.

As the last step, we wanted to test the tool on a large codebase, using a known refactoring.
We chose the reworking of the `regexp` module in the standard library, containing regular expression related functions, as our target.
The `regexp` module was replaced by `re` in OTP R13, while `regexp` itself was deprecated, and later removed from the standard library.

This necessitated the replacement of the usage of the module `regexp` by `re` everywhere it was used in the standard library.
The API of `re` remained similar, although it had some easy-to-miss changes, like changing the way indexing workes (starting from 0 instead of 1).
Even so, upgrading to the newer module usually meant a simple refactoring, replacing a function used from the `regexp` module with a function having the same or similar name, but coming from `re` instead, with some slight modifications.

An example of such refactoring, taken from the `xref_utils` module, can be seen here:

\lstset{caption={xref\_utils, before refactoring}, label=src:erlang}
\begin{lstlisting}[language={Erlang}]
match_list(L, RExpr) ->                                            
    {ok, Expr} = regexp:parse(RExpr),                              
    filter(fun(E) -> match(E, Expr) end, L).                       
                                                                   
match_one(VarL, Con, Col) ->                                       
    select_each(VarL, fun(E) -> Con =:= element(Col, E) end).      
                                                                   
match_many(VarL, RExpr, Col) ->                                    
    {ok, Expr} = regexp:parse(RExpr),                              
    select_each(VarL, fun(E) -> match(element(Col, E), Expr) end). 
                                                                   
match(I, Expr) when is_integer(I) ->                               
    S = integer_to_list(I),                                        
    {match, 1, length(S)} =:= regexp:first_match(S, Expr);         
match(A, Expr) when is_atom(A) ->                                  
    S = atom_to_list(A),                                           
    {match, 1, length(S)} =:= regexp:first_match(S, Expr).         
\end{lstlisting}
    
\lstset{caption={xref\_utils, after refactoring}, label=src:erlang}
\begin{lstlisting}[language={Erlang}]
match_list(L, RExpr) ->
    {ok, Expr} = re:compile(RExpr),
    filter(fun(E) -> match(E, Expr) end, L).

match_one(VarL, Con, Col) ->
    select_each(VarL, fun(E) -> Con =:= element(Col, E) end).

match_many(VarL, RExpr, Col) ->
    {ok, Expr} = re:compile(RExpr),
    select_each(VarL, fun(E) -> match(element(Col, E), Expr) end).

match(I, Expr) when is_integer(I) ->
    S = integer_to_list(I),
    {match, [{0,length(S)}]} =:= re:run(S, Expr, [{capture, first}]);
match(A, Expr) when is_atom(A) ->
    S = atom_to_list(A),
    {match, [{0,length(S)}]} =:= re:run(S, Expr, [{capture, first}]).
\end{lstlisting}

Note the change from `regexp:parse` to `re:compile`, the change of 1s to 0s (related to where indexing starts from) and the way `regexp:first_match` was made unnecessary by requiring the user to specify which match is needed by an argument for `re:run`.

By running the tool on commits related to these changes, we were able to identify functions that do in fact behave differently as a result of this refactoring.
Unfortunately, all of these functions were internal, not exported from the module, and all of them were called in a way that prevented these differences to manifest and cause unwanted behavour.
Most of these problems resulted from discrepancies between the way `regexp` and `re` handle erroneous inputs.
While `regexp` usually gave back some value even for meaningless input, `re` threw an error in these cases, making their behaviour differ.

We also found that running the tool on repositories like OTP, which consists of many other subrepositores, can ofthen cause problems, like includes not being found.
Although it's important to mention that OTP is somewhat of an outlier in this regard, not resembling the average Erlang project structure of a single repository.

We also found that running the tool on projects as large as OTP necessitates the use of on-demand compilation, alluded to in earlier sections, without which its necessary to compile the whole codebase twice before the checking could start, once for each version.
This could have a disastrous effect on efficiency, even for somewhat smaller projects, which would make the tool effectively unusable for most people.

Despite all of this, we think that these results show that our approach is feasible, and it has practical value.
We are confident that EquivcheckEr could become a viable tool, but for this to happen, additional work is needed.
This is the theme of the next chapter.

# Future Work

Although the tool is in a working state now, that doesn't mean it's also easy to use.
There is still a lot of work to be done before it can be considered user-friendly.
This chapter is a collection of improvements we think would make EquivcheckEr better, each with a short summary of the details.

The project has an issue tracker, which can be found on $\href{https://github.com/harp-project/EquivcheckEr/issues}{GitHub}.
Some of these items are already present as bugreports or feature requests on it.

## Packaging

Currently the source code is on GitHub, and it requires manual compilation.
For easier access, the software will need to be packaged, and these packages will need to be made public where people can download and install them.
There is also a general lack of documentation that needs to be addressed.
The editor integration will also need to be made available, preferably somewhere visible, like the Visual Studio Code Marketplace.

## Better Visual Interface

In its current state, the VSCode integration only have one way to present its findings to the user, in the form of an editor buffer, containing Markdown text.
While this provides all the necessary information for the user, it's not hard to imagine better ways to present the output.
One such way could be to use VSCode's already existing Git integration to show the user a spit view of the diff, where they can see all of the problematic changes.

Another useful feature would be to show that a function has failed the tests, and the counterexamples found in a tooltip if the user hover above it with the cursor.
Functions that failed the check could also be underlined, or indicated by some visual mean, so the user would know where the problem is while looking at the source code itself.

## Customization

It would also be nice to give more control to the user by providing a broader range of configurable options.
These could be things like the location of includes, the number of data points generated by PropEr, the amount of time before an evaluation times out, etc...

## Other Kinds of Communication

It could also be improved by considering other types of inter-process communication.
Currently we are only checking on the messages sent and received by processes, but it's also possible for processes to communicate by sending signals.

## On-Demand Compilation

On-demand compilation would avoid the need to compile the whole project, by only compiling the modules that are tested, right before they are needed.
This, we think, would result in a considerable improvement in the case of larger codebases, where the number of modules can be in the thousands, but we only need to consider a couple of modules when checking for equivalence.

## Comparing Side-Effect on Timeout

When function evaluation times out, we conclude that establishing nonequivalence is not possible.
This behaviour could be improved by still comparing their side-effects.
In this way, even though the return value is unknown, we can clearly state that the functions are semantically different, if their side-effects are different.

## Platform Support

While developing the tool, we were mainly targeting UNIX-like systems.
While it would be nice to support other platforms, we believe that most users will probably use some UNIX-like platform.
For Windows, it's possible that the Windows Subsystem for Linux (WSL) feature is sufficient for running EquivcheckEr, although we hadn't investigated this possibility.
