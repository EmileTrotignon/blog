# Printing and OCaml

Printing values for debugging purposes is often presented as one of the big pains of the OCaml experience, and I agree with that sentiment. There is no
simple way to print most datatypes, it either requires some external dependecies
or writing a bit of code. One of the proposed solution for this is modular
implicits. In this post I will argue that while modular implicits would help with
printing a lot, they are not sufficient on their own, and it would be possible
to improve the printing experience a lot without them.

## Modular implicits

Modular implicits are a very powerful feature which requires a lot of research
and implementation work, and are not going to be available for a very long time.
It would allow us to do as following:

```ocaml
module type Printable = sig
  type t

  val print : t -> out_channel -> unit
end

(* Such constraints are not possible in OCaml for now *)
let print (M : Printable) (v : M.t) out_channel =
  M.print v out_channel

let () =
  (* Here is the implicit part : you do not need to give the module [Int], it is
     selected automatically because it fits the signature *)
  print 123
```

## Modular implicits are not enough

This is very cool, but having modular implicits on its own would not solve the
printing issue. You would also need `Int` to be printable, and currently it is not
and no module in the Stdlib is.

There are obviously functions to print many types, but none of them are in their
respective modules. You have `output_int`, `Format.pp_print_int`, but not
`Int.print`. More complex types like `'a list` only have function to print them
in `Format`, were they might be hard to find.
This may seems like a detail because adding such functions would be very easy
compared to implementing modular implicits, but I believe it is
a low-hanging fruit.

If such functions existed in every module in the Stdlib, we could say to
beginners something like:
- To print a value of type `M.t`, you do `M.print`.
That would be a whole lot better than to tell them that they have to handle it
themselves. And I would even go as far as to say that it is just as good as
modular **explicits**, that is a version of the above code where you have to specify
the module: `print Int 123` is not that different from `Int.print 123`.

That is to say, modular implicits give inference for printing, which is very
good, but a lot of langages that have a typeclass-like thing for printing do not
have very good type inference, and (almost) catching up with them would only
require small changes to the Stdlib.

In c++, you could write :

```c++
int x = 123;
cout << x;
```

and in Ocaml with the changes I talk about that would be
```ocaml
let x = 123 in
Int.print x
```

The explicit typing is done the same number of times, and I think they are both
equally reasonable ways to print.

There is also the case of types that have an abstract parameter like `'a list`.
In that case, you need an extra argument to the `print` function. The comparison
then becomes

```c++
vector<int> arr = {1; 2 ;3};
cout << arr;
```

```ocaml
let arr = [|1; 2; 3|] in
Array.print Int.print arr
```

Here ocaml is only slightly worse because you need to repeat `print`, but it is
still very much manageable, and it would be possible to write a small syntax
extension that removes this annoyance. It could look like that, and it does not
need to part of the stdlib:
```ocaml
let arr = [|1; 2; 3|] in
print_endline {%fmt|arr = %{arr : Array[Int]} |}
```

One thing that OCaml would still be bad at is printing value with abstract types.
In c++ you could do:

```c++
template<class T>
void f( vector<T> arr) {
  cout << arr;
  ...
}
```

whereas in ocaml, you would need to do the following:

```ocaml
let f (arr : 'a array) =
  Array.print ???.print arr
```

which is not possible.

But I still think that being able to say "printing is pain when you have
abstract type" is ten times better than having to admit that printing is a pain
most of the time.

## The standard issue

While adding the printing functions would not be very hard, deciding exactly
what to add may be harder:
What is the type of the `print` function? What exactly does it print?
This can be quite hard to decide, as it is a design question that does not have
a unique answer, but I think this discussion is worthwile. I will try to propose
design ideas in the future.
