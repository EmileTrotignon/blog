# Monad

A monad in OCaml is a module with the following signature :

```ocaml
module type Monad = sig
  type 'a t

  val return : 'a -> 'a t

  val bind : 'a t -> ('a -> 'b t) -> 'b t

  val map : ('a -> 'b) -> 'a t -> 'b t
  (* Different argument order than bind : this is a meaningless convention *)
end
```

In this blog post, I will try to explain two important things around monads :

- Why let operators make sense ?
- Why is this signature named, in what sense is it special ?

What I will not try to explain is how to use them. For that I believe that the
signature is enough, you just need to play with a concrete monad like `Result`
or `Lwt` for long enough. The explainations bellow are certainly not necessary
to use monads.


## Monad Laws

For a module to be a monad, it also needs to behave properly, that is according
to the following laws :

```ocaml
bind (return a) f = f a

bind m return = m

bind (bind m g) h = bind m (fun x -> bind (g x) h)
```

I believe this is not really important to understand, it just means that the
functions are going to behave like you would expect them to. Its not very
relevant to my explainations bellow.

Its is still probably worth it as a small exercise to try and prove that it is
true for common monads with simple implementations like `Result`.

## Let operators

Let operators are a fancy syntax to use monads. It is quite easy to use them,
but what is less widely understood is why they make sense.

To try and get there, we will look at a regular let expression

```ocaml
let <pattern> = <expr1> in
<expr2>
```

Lets name the type of `expr1` `'a` and the type of `expr2` `'b`. `expr2` has a a
free-variable bound to `<pattern>`. That free variable is of type `'a`. This can
be interpreted as `<pattern>` and `expr2` together being of type `'a -> 'b`.

If we indeed chose to look at things this way, we can get this as the type of
the let itself :

```ocaml
'a -> ('a -> 'b) -> 'b
```

We can then define a function that has this type :

```ocaml
let impractical_let (v : 'a) (f : 'a -> 'b) : 'b =
    f v
```

And use it as you would a let statement :

```ocaml
impractical_let <expr1> (fun <pattern> -> <expr2>)
```

In OCaml, this has approximately the same behavior, but the real let notation is
just way better. Still, there is something interesting here :
`impractical_let`'s type look a lot like the signature of `map` or `bind` in a
monad. The only difference is that `bind` and `map` have extra `t`s in the
signature, and that the only syntax available for them is the impractical one :

```ocaml
bind <expr1> (fun <pattern> -> <expr2>)
```

So we can define a new syntax to use `bind` or `map` as if it was a regular let
binding. In OCaml this is done with the let-operators syntax :

```ocaml
let ( let* ) v f = bind v f
let ( let+ ) v f = map f v (* map usually has reverse order arguments. *)
```

Then,

```ocaml
let* <pattern> = <expr1> in <expr2>
```

is parsed to `(let*) expr1 (fun <pattern> -> <expr2>)`, that is
`bind expr1 (fun <pattern> -> <expr2>)`.

We can see by using this this that it works very well, but this still does not
explain everything : why this signature ? What happens if you have `map` and not
`bind` ?

## Why monads ?


Here we will explain why the monad signature is important and its meaning.

First we can notice that `map` is not strictly necessary because you can
implement it with `bind` and `return` :

```ocaml
let map f m = bind m (fun v -> return (f v))
```

We will explain later in english what this means.

To explain what a monad is, we will look at its `'a t` in a other way. Most of
the time, we look at a type `'a t` as a `t` that contains an `'a`. That make
a lot of sense for `'a list`.

In the case of a monad we need to look at it as a way to compute an `'a`. This
make sense for common monads :

- `'a Lwt.t` is a way to compute an `'a` asynchronously.
- `'a Option.t` is a way to compute an `'a` that may fail.

It would not make sense to state that an `'a Lwt.t` contains an `'a` : it might
not "contain" it just yet. Likewise for an `'a Option.t`, there might not be a
single `'a` in here.

Even `'a list` can be seen a way to compute an `'a` that may have multiple
results. We can call this a "non deterministic computation" as its results are
multiple or none and "the result" is not determined.

We will use this monad in the following explanation. For lists, `map`
is well known, but `bind` less so. `bind` is actually the same as
`concat_map : 'a list -> ('a -> 'b list) -> 'b list`.


When we view things this way, `map`'s arguments are :

- `'a -> 'b` a regular computation that depends on another regular computation
- `'a t` a computation of an `'a` that returned multiple results

So `map` itself is a way to make a regular computation that depends on a
non-deterministic computation. The final result is non-deterministic, as it
should be.

Lets look at bind :

- `'a t` is a non-deterministic computation.
- `'a -> 'b t` is a non-deterministic computation that depends on a regular one.

So `bind` is a way to make a non-deterministic computation that depends on
another non-deterministic computation.

Understanding `return` is even simpler : it turns a regular compution into
a non-determistic one. It is a bit artificial : it is going to give only
one possible result.

## Example : Sudoku

Lets look a real use-case of non-deterministic computation : solving a sudoku.
When you solve a sudoku, you have a set legals digits to put in each cells, but
choosing the wrong one may block you later.

We are going to place ourselves in a very abstract sudoku :

- Empty cells are represented by ints from `0` to `n_cells`.
- A digit `i` in cell `cell` is legal if `legal_move ~cells ~cell i` returns
  true. `cells` is a list of size `i - 1` with the digits put in the previous
  cells. This `legal` function exists for one instance of a sudoku problem.

We can solve the sudoku with the following code :

```ocaml
let digits = [1; 2; 3; 4; 5; 6; 7; 8; 9] in
(* [digit] is one element of [digits], we do not know which one. The bellow code
   is going to run once for each possible value of [digit] *)
let* digit = digits in
let* cell_0 =
  if is_legal ~cells:[] ~cell:0 digit then
    return digit
  else
    (* If this branch is executed, the execution stops here : [concat_map f []]
       does not call [f] *)
    []
in
let* digit = digits in
let* cell_1 =
  if is_legal ~cells:[cell_0] ~cell:1 digit then
    return digit
  else []
in
...
let* digit = digits in
let+ cell_n =
  if is_legal ~cells:[cell_0; cell_1, ...,  cell_n-1] ~cell:n digit then
    return digit
  else []
in
[cell_0; cell_1; ...; cell_n]
```

A working version can be found in [sudoku_monad.ml](sudoku_monad.ml)

The above code has type `int list list`, which make sense because a solution is
a list of digits to put in cells, and there can be multiple solution to a
sudoku.

You can notice that we use `let+`/`map` only once. The reason for that is that
every cell depends on non-deterministic computations : the choice of the digit,
and the previous cells. The last cell does not have a non-deterministic
computation that depends on it : we just return the list of cells afterwards.

You can find exercices on the non-deterministic monad by Francois Pottier
[here](https://ocaml-sf.org/learn-ocaml-public/exercise.html#id=fpottier/nondet_monad_seq).

Be aware that the exercise do not use the `let*`/`let+` syntax, but an infix one.
This syntax used to be very common in the OCaml ecosystem before let operators
were available. They also try and make the non-determinism usable in reality,
by caring about performance.

## What if you do not have bind ?

The following signature is called a functor :

```ocaml
module type Functor = sig
  type 'a t

  val return : 'a -> 'a t

  val map : ('a -> 'b) -> 'a t -> 'b t
end
```
It is not to be confused with the language feature of the same name and is a
monad that lacks bind. As we saw earlier `bind` allows to do a special
computation that depends on another special computation. `map` does a regular
computation that depends on a special one. Therefore if you only have `map` you
cannot chain special computations. This can be useful to model certain things.

For instance, in the OCaml environnement; Cmdliner works like that. Cmdliner is
a library to specify command line interfaces. I will explain a simplified
version of this library. You can express command line option declaratively,
which returns an `'a Arg.t`. The `'a` of the `'a t` is the value associated with
the command line argument. For a simple flag it would be `bool`, but you can
have more complex arguments that take values. We can view `'a Arg.t` as a
special way to compute an `'a` : The user will input it on the command line.
There is however a limitation : There is a `let+`/`map` function, but not a
`let*`/`bind` one, because you cannot declare a command line argument that
depend on the result of another one. This make sense because allowing this would
permit some very weird interfaces like the following :

```
cmd --my_option=<text_1> --<text_2> ...
```

where the command is valid only if `text_1` is equal to `text_2`.

If there was a `let*`/`bind` function in Cmdliner, you would program the above
command line interface like this :

```
let* option = option_string "my_option" in
let* option_flag = flag option in
...
```

If you replace every `let*`/`bind` by a `let+`/`map`, it will return you an `'a
t t` instead of an `'a t`, that is a command line argument that returns a
command line argument that returns an `'a`, and there is no way to run that in
Cmdliner, for the reason of such command-line interfaces being indesirable.

We can view this in terms of parsing; Cmdliner parses command line argument : a
monad would allow to parse a context-sensitive grammar, where a functor
restricts possible grammars to context-free ones.

To be more precise, `Cmdliner` is actually an applicative functor, which is
slightly more powerful than the presented functor, but still does not have bind,
and also only allows to parse context-free grammar.

## Conclusion

To sum things up, a monad is in interface that provide a way to make special
computations that can depend on other special computations of the same kind.
Computations are nicely expressed by let-bindings instead of anonymous
functions, and in OCaml we have them even for special computations.
