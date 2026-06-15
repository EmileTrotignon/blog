# Subtyping and Variance

Subtyping is a powerful concept that feels very intuitive but has weird
consequences. These consequences are often referred to by the complicated terms
"covariance" and "contravariance". I will explain what this means below.

## Introduction: OCaml notations

I will use notations from the OCaml language. You may skip this section if you
are familiar with it.

- `val v : t` means that there is value `v` that has type `t`.
- `a -> b` is the type of functions that take an argument of type `a` and return
  a value of type `b`.
- `f a` is the application of the function `f` to the value `a`.
- A type `'a t` has a parameter `'a`. You can put any type in it, for instance
  `int t` or `string t` are both valid types.

## Basics

"`A` is a subtype of `B`" is written `A < B` and means that where we need a
value of type `B`, providing a value of type `A` instead is fine.

In OOP vocabulary, we would say that `A` inherits `B`, but there are other kinds
of subtyping than OOP-style inheritance: in OCaml, subtyping shows up with
classes but also polymorphic variants.

If `A < B`, then a value of type `A` can be considered to be a value of type `B`.

Let us consider the example of the types `square` and `rectangle`.
Naturally, we have `square < rectangle`.
If you have:

```ocaml
val f : rectangle -> int

val v : square
```

then `f v` is well-typed.
Depending on the language, some kind of explicit instruction to consider that
`v` is of type `Rectangle` may be needed.

## Covariance

Let's imagine that we have the following values:

```ocaml
val high1 : (int -> square) -> square

val high2 : (int -> rectangle) -> square

val f : int -> square

val g : int -> rectangle
```

If you are unfamiliar with this notation : `high1` takes a function as argument,
this function has to have type `int -> square`.

It is very clear that `high1 f` is well typed, and the same is true for `high2 g`.
The question is whether `high1 g` or `high2 f` are well typed.

Let's not try to resolve typing at first, and just study what will happen if we
actually run the code.

If we run `high1 g`, what will happen is that `high1` will be allowed to call
`g`, and consider its result as a `square`. However the result of `g` is not
necessarily a `square`, it may be any `rectangle`. Therefore `high1 g` is
ill-typed.

If we run `high2 f`, what will happen is that `high2` will be allowed to call
`f`, and consider its result as a `rectangle`. Since the results of `f` are
`square` and `square < rectangle`, this is well-typed.

This means that if `square < rectangle`, then
`(int -> square) < (int -> rectangle)`.

We call this situation covariance.

More precisely, the function type `a -> b` is covariant with `a`, because it
"varies" in the same direction as `a`.

Here, variation means "accepting a sub- or super-type", and the direction is
whether we are talking a sub-type or a super-type.

## Contravariance

Let's imagine that we have the following values:

```ocaml
val high1 : (square -> int) -> int

val high2 : (rectangle -> int) -> int

val f : square -> int

val g : rectangle -> int
```

Once again, it is very clear that `high1 f` is well typed, and the same is true for
`high2 g`. The question is whether `high1 g` or `high2 f` are well typed.

When we run `high2 f`, what will happen is that `high2` will be allowed to call
`g : square -> int` with an argument of type `rectangle`. This is an error.

When we run `high1 g`, what will happen is that `high1` will be allowed to call
`g : rectangle -> int` with an argument of type `square`. This is fine.

This means that if `square < rectangle`, then
`(rectangle -> int) < (square -> int)`, because a function with an argument of
type `(square -> int)` can be called with a value of type `(rectangle -> int)`.

We call this situation contravariance.

More precisely, the function type `a -> b` is contravariant with `b`, because it
"varies" in the opposite direction as `b`.

## Invariance

This time, we will ask the question of the type `ref`.

In OCaml, `t ref` designates a mutable variable of type `t`.

In essence, a mutable value is a pair of a setter function and a getter
function. We can write this the following way:

```ocaml
type 'a ref = {get: unit -> 'a; set: 'a -> unit}
```

What we want to know is, assuming `square < rectangle`, can we assert
`square ref < rectangle ref` or `rectangle ref < square ref`?

By applying the results of the two above paragraphs, we can already conclude
that the answer is no. Both assertions are false. Let's show it in a more
convincing way by example.

Let's assume the following environment:

```ocaml
val new_rectangle : unit -> rectangle
val new_square : unit -> square

val print_rectangle : rectangle -> unit
val print_square : square -> unit
```

We will now write the following function :

```ocaml
let set_to_new r =
  r.set (new_rectangle ())

let print_rectangle_ref r =
  print_rectangle (r.get ())

let print_square_ref r =
  print_square (r.get ())
```

These functions have the following types :

```ocaml
val set_to_new : rectangle ref -> unit

val print_rectangle_ref : rectangle ref -> unit
val print_square_ref : square ref -> unit
```

If we assume that `rectangle ref < square ref`, then we may pass an argument of
type `rectangle ref` to `print_square_ref`. This will obviously fail, the
printer for squares cannot print a rectangle. Therefore we do not have
`rectangle ref < square ref`.

If we assume that `square ref < rectangle ref`, then we may pass an argument of
type `square ref` to `set_to_new`. This breaks the typing, because then the
`square ref` will contain a rectangle obtained from `new_rectangle` that is not
necessarily a `square`. Therefore we do not have `square ref < rectangle ref`.

We have neither `rectangle ref < square ref` nor `square ref < rectangle ref`.
We say that the type `a ref` type is invariant with `a`, because if `a` "varies"
(that is accepts a super- or sub-type), then `a ref` does not.

Notice that any type `'a t` that contains a mutable field of type `'a` is going
to be invariant for the same reason. This is especially important for the type
`array`.

## Java

In this section, I will start rambling about how awful Java is.

Java consider its array type to be covariant. We saw earlier that it is in
fact invariant. This means that some typing errors will manifest themselves at
runtime.

For instance, if you have an array of squares, you may pass it to a function
expecting an array of rectangle. If the function tries to write a rectangle to
the array, an exception will be triggered. This is in my opinion a very bad
situation. Whether a function will write to an array or not is not necessarily
apparent from its interface, and it must happen quite often that unexpected
exceptions are raised, when a more powerful type system would have eliminated
them.

However, you do have proper handling of variance and covariance, just not for
array. The reason being that is was added later. The first version of java
supporting generics (we call that polymorphism in the functional world) was
released in 2004, 8 years after the first release of the language. There was of
course always a generic type, the array, but no other could be defined. And
contrary to Golang where common data structures were provided, here, if you
needed a hashmap, you had to accept losing type information or implementing a
new hashmap class for each type.

I do understand that in a language such as Java, where subtyping is really
pervasive (that is a mistake by itself in my opinion, but beyond the scope of
this discussion), you need to be able to use subtyping with arrays. Arrays being
invariant makes them "incompatible" with subtyping, and this is definitely an
issue that needed to be solved, and it was with what Java calls wildcards.

```java
<T> void fillList(List<? super T> list, T value) {
    for (int i = 0; i < list.size(); i++) list.set(i, value);
}
```

Here, `?` is what's called a wildcard. It is a kind of unnamed type variable that
is declared to be a supertype of `T`.

Adding an illegal read does get you a type error:
```java
static <T> T fillList2(List<? super T> list, T value) {
    T v = list.get(0);
    for (int i = 0; i < list.size(); i++) list.set(i, value);
    return v;
}
```

```
ERROR!
Main.java:10: error: incompatible types: CAP#1 cannot be converted to T
          T v = list.get(0);
                        ^
  where T is a type-variable:
    T extends Object declared in method <T>fillList2(List<? super T>,T)
  where CAP#1 is a fresh type-variable:
    CAP#1 extends Object super: T from capture of ? super T
1 error
```

If you want a function that does reads you can use `extends` instead of `super`:

```java
static <T> boolean eqFirstElt(List<? extends T> list, T value) {
    return value == list.get(0);
}
```

This is a reasonable system, it's just a bit puzzling that it wasn't designed
like that from the start and that the default array type does not have access to
it.