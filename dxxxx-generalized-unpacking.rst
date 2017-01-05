====================================================
  Generalized Unpacking and Parameter Pack Slicing
====================================================

:Document:  Dxxxx
:Date:      2017-01-05
:Project:   ISO/IEC JTC1 SC22 WG21 Programming Language C++
:Audience:  Evolution Working Group
:Author:    Matthew Woehlke (mwoehlke.floss@gmail.com)

.. raw:: html

  <style>
    html { color: black; background: white; }
    table.docinfo { margin: 2em 0; }
    .lit { font-weight: bold; }
    .var { font-style: italic; }
    .var::before { font-style: normal; content: "<"; }
    .var::after { font-style: normal; content: ">"; }
    .optvar { font-style: italic; }
    .optvar::before { font-style: normal; content: "[<"; }
    .optvar::after { font-style: normal; content: ">]"; }
  </style>

.. role:: cpp(code)
   :language: c++

.. role:: lit(code)
    :class: lit

.. role:: var(code)
    :class: var

.. role:: optvar(code)
    :class: optvar

Abstract
========

This proposal introduces two new, related concepts: "generalized unpacking" (the conversion of product types to parameter packs) and parameter pack slicing. These concepts use the same syntax and may be employed concurrently.

.. contents::


Background
==========

There is an increasing push in C++ to add interoperability between values and value sequences, exemplified by the recent addition of "structured binding", :cpp:`std::apply`, and :cpp:`std::make_from_tuple` in C++17, and by proposals such as P0327_ that work toward expanding and clarifying the concept of value sequences (using the term "product type") and P0341_ which proposes certain mechanisms for using product types. Similar features have long been present in other languages, with Python frequently held up as a representative example. While we feel that these represent steps in the right direction, there remain problems to be solved.


Rationale
=========

Parameter pack slicing, particularly single valued slicing, solves a known problem when working with parameter packs. Several algorithms and ideas for working with parameter packs require the ability to select an item from a parameter pack by index.

Generalized unpacking greatly expands the ability to work with product types. Although :cpp:`std::apply` and :cpp:`std::make_from_tuple` attempt to fill some of these roles, their mere existence, and especially that they are two separate functions despite serving conceptually identical purposes, is indicative of the usefulness of a language feature. Moreover, these functions have significant limitations: they can only cover specific use cases, they cannot perform slicing operations on their own, and they cannot be readily used where the desired argument list *includes* but does not *solely consist of* a single product type.

Although we could attempt to solve these issues independently, we believe it is better to approach them together.


Proposal
========

We present our proposal in two parts. First, we present the proposed syntax and examine its function in the context of parameter packs. Second, we extend the application of the proposed syntax to also incorporate "concrete" product types.

Parameter Pack Slicing
----------------------

We propose to introduce a new prefix operator, :lit:`[`\ :var:`slicing_expression`\ :lit:`]`, which may be applied to an expression producing a parameter pack. The syntax of :var:`slicing_expression` shall be one of :var:`index` or :optvar:`index`\ :lit:`:`\ :optvar:`index`, where each :var:`index` is a :cpp:`constexpr` of integer type. For the purposes of the following specification, also let :var:`pack_expression` be the operand of the slicing expression.

The first form shall select a *single* element of a pack, and shall yield this value as a single value (i.e. not as a new pack). For example, the expression :cpp:`[1]pack` shall yield the second value of the parameter pack :cpp:`pack`. If the :var:`index` is negative, it shall first be added to :cpp:`sizeof...(`\ :var:`pack_expression`\ :cpp:`)`. If the index (after the preceding step, if applicable) is out of bounds, the expression shall be ill-formed.

The second form shall return a *variable* slice of the parameter pack, and shall yield this value as a new parameter pack. Both indices are optional and may be omitted. The first :var:`index` shall specify the index of the first pack element to yield. If omitted, the value :cpp:`0` shall be assumed. The second :var:`index` shall specify the *upper bound* on the indices to be yielded, meaning that the specified index is *not* included. If omitted, the value :cpp:`sizeof...(`\ :var:`pack_expression`\ :cpp:`)` shall be assumed. If either value is negative, it shall first be added to :cpp:`sizeof...(`\ :var:`pack_expression`\ :cpp:`)`. Each value shall then be clamped to the range [\ :cpp:`0`, :cpp:`sizeof...(`\ :var:`pack_expression`\ :cpp:`)`]. If, after normalization and clamping, the upper index is less than the lower index, an empty parameter pack shall be yielded. (Note that this means that a variable slice is never ill-formed due to out of bounds index values.)

This can be represented in pseudo-code::

  // let [lower:upper](pack) represent the complete slicing expression

  size = sizeof...(pack);

  if lower is unspecified:
    lower = 0;
  if upper is unspecified:
    upper = size;

  if lower < 0:
    lower = size + lower;
  if upper < 0:
    upper = size + upper;

  lower = bound(0, lower, size);
  upper = bound(0, upper, size);

  for (index = lower; index < upper; ++index)
    yield [index]pack;

Note that the expressions :cpp:`[:]pack` and :cpp:`pack` are equivalent; that is, a slicing expression which uses the defaults for both the lower and upper indices shall produce the same parameter pack.

Generalized Unpacking
---------------------

By presenting slicing first, we may consider generalized unpacking to be an extension of parameter pack operations to work on product types. Specifically, we propose that the above described slicing operator and :cpp:`sizeof...` be extended to accept product types as well as parameter packs. When used on a product type, the type is "unpacked" into a parameter pack.

For example, given a product type :cpp:`t` of size 3, :cpp:`sizeof...(t)` would be well formed and equal to 3, and the expression :cpp:`[:]t` would expand to a parameter pack equivalent to :cpp:`get<0>(t), get<1>(t), get<2>(t)`. (While we use :cpp:`get<N>` here for illustrative purposes, this proposal would reflect any changes made to product type access.)

Accordingly, :cpp:`[expr1]expr2` would be equivalent to :cpp:`get<expr1>(expr2)`; that is, a single value rather than a parameter pack.

Implementing this is straight forward; if a slicing operation or :cpp:`sizeof...` is used on an expression which is not a parameter pack, rather than being an error, the compiler shall attempt to proceed as if the expression produces a product type. (If this attempt also fails, then an error is raised, as usual.)

This makes possible uses like the following, which are not readily accomplished using library-only solutions:

.. code:: c++

  // let a1..a9 be single values
  // let t1, t2 be product types ("tuple-like")

  auto x = SomeType(a1, [:]t1..., [3:]t2..., a2);
  foo([1:]t1..., a3, [0]t1);

  // let v1, v2 be vector-like types of T that may or may not be an array, e.g.:
  //   std::array<int, N>
  //   Eigen::Vector3d
  //   QPoint
  //   struct Point { int x, y; }

  auto manhattan_length = std::abs([:]v1) + ...;
  auto manhattan_distance = std::abs([:]v1 - [:]v2) + ...;
  auto dot = ([:]v1 * [:]v2) + ...;

Note also an important implication of both the above code and many of the examples to follow; namely, that we assign the slicing/unpacking operator (prefix :cpp:`operator[]`) higher precedence than fold operator (postfix :cpp:`operator...`).


Additional Examples
===================

Heads and Tails
---------------

It should be obvious that this solves problems alluded to by P0478_:

.. code:: c++

  // Ugly and broken
  void signal(auto... args, auto last)
  {
    // pass first 5 arguments to callback; ignore the rest
    if constexpr (sizeof...(args) > 5)
      return signal(args...);
    else if constexpr (sizeof...(args) == 4)
      callback(args..., last);
    else
      callback(args...);
  }

  // Enormously better
  void signal(auto... args)
  {
    // pass first 5 arguments to callback; ignore the rest
    callback([:5]args...);
  }

Note also that the above "ugly" version of the function has several issues (which we have copied from its specification in P0478_\ R0):

- It cannot be invoked with zero arguments.
- When invoked recursively, there is a spurious :cpp:`return` statement.
- If fewer than 5 arguments are supplied to :cpp:`signal`, the last argument is unintentionally dropped.

The last point in particular is subtle and difficult to reason about, thus providing an excellent illustration of why needing to write code like this is bad. The version using our proposed feature is enormously cleaner and far easier to understand, and significantly reduces the chances of making such mistakes in the implementation. In addition, recursion is eliminated entirely (which, given that the example is accepting parameters by-value, could be critically important if some arguments have non-trivial copy constructors).

We can also improve the second example:

.. code:: c++

  // Mostly okay
  auto alternate_tuple(auto first, auto... middle, auto last)
  {
    if constexpr (sizeof...(items) <= 2)
      return std::tuple(first, last, middle...);
    else
      return std::tuple_cat(std::tuple(first, last),
                            alternate_tuple(middle...));
  }

  // Better
  auto alternate_tuple(auto... items)
  {
    if constexpr (sizeof...(items) < 3)
      return std::tuple{items...};
    else
      return std::tuple{[0]items, [-1]items,
                        [:]alternate_tuple([1:-1]items...)...};
  }

As with the previous example, our version solves a boundary case (in this instance, when fewer than two items are given) that is not handled by the version given in P0478_. In particular, without slicing, one must implement an overload to handle such boundary cases, potentially resulting in duplicated code and the attendant increase in maintenance burden. With slicing, we can trivially handle such boundary cases in the same function.

Divide-and-Conquer
------------------

The ability to slice parameter packs makes it possible to implement binary divide-and-conqueror algorithms on parameter packs, which would be difficult or impossible to achieve otherwise. Consider this example which selects the "best" element in a parameter pack:

.. code:: c++

  auto best(auto const& first, auto const&... remainder)
  {
    if constexpr (sizeof...(remainder) == 0)
      return first;
    else
      return better_of(first, best(remainder...);
  }

While this example is overly simplified, what if it was significantly more efficient if the function could be written to require only ``O(log N)`` recursion rather than ``O(N)`` recursion? With slicing, this can be accomplished easily:

.. code:: c++

  auto best(auto const&... args)
  {
    constexpr auto k = sizeof...(args);
    if constexpr (k == 1)
      return [0]args;
    else
      return better_of(best([:k/2]args...), best([k/2:]args...));
  }

Note also that the above code no longer needs to accept the first argument separately.

Unpacking and Fold Expressions
------------------------------

Let's consider now some additional examples of how generalized unpacking allows us to write fold expressions on the elements of product types:

.. code:: c++

  std::tuple<int> t1 { 1, 2, 3 };
  std::tuple<int,int> t2 { 4, 5, 6 };
  std::tuple<int,int,int> t3 { 7, 8, 9 };
  auto tt = std::make_tuple(t1, t2, t3); // a tuple of tuples

  f([:]tt ...);     // f(t1, t2, t3);
  f(g([:]tt) ...);  // f(g(t1), g(t2), g(t3));
  f(g([:]tt ...));  // f(g(t1, t2, t3));

  f(g([:][:]tt ...) ...); // ill-formed
  f(g([:][:]tt ... ...)); // ill-formed

Note that, due to the precedence we specified, the last two lines are ill-formed. In both cases, the second :cpp:`[:]` is redundant, resulting in an attempt to apply :cpp:`...` to something which is not a parameter pack. Note also that a consequence of this precedence is that :cpp:`[:]` cannot be used as the operator of a fold expression.

This leaves two relatively straight-forward cases that are not addressed purely by the proposed feature, but are nevertheless made significantly easier with it:

.. code:: c++

  // f(g(1,2,3), g(4,5,6), g(7,8,9));
  f(std::apply(g, [:]tt)...);

  // f(g(1, 2, 3, 4, 5, 6, 7, 8, 9));
  f(g([:]std::tuple_cat([:]tt...)...));
  f(std::apply(g, [:]tt...));

For the last example, we assume an extension to :cpp:`std::apply` to accept multiple product types which are "flattened" into the arguments for the specified function. We are not proposing this here, merely showing an example of how the task could be accomplished.

Although this is effective, at least for the above examples, pack generators would provide a better solution for this and other more complicated problems. See `Future Direction`_ for further discussion.

Slicing Product Types
---------------------

It's harder to imagine generic uses for slicing product types, since product types come in so very many varieties. However, we have already alluded to the case of rearranging elements in a product type as one possible use. Another likely use case deals with linear algebra and geometry, particularly operations dealing with homogeneous vectors. Let us consider the simple example of converting a homogeneous vector to a normalized vector. Such an operation would normally be written out "longhand", and would be difficult to adapt to vectors of arbitrary dimension. Our proposed feature allows us to write a simple and succinct implementation:

.. code:: c++

  template <typename T, size_t N>
  std::array<T, N-1> normalize(std::array<T, N> a)
  {
    return {[:-1]a / [-1]a...};
  }

Improving :cpp:`std::apply`
---------------------------

The previous example postulated an extension to :cpp:`std::apply` to accept multiple product types. While this can of course be achieved already using :cpp:`std::tuple_cat`, avoiding unnecessary copies and/or temporary objects is awkward at best. The postulated extension should be able to avoid these problems. Using our proposed feature, we can show (forwarding omitted for brevity) how this might be implemented:

.. code:: c++

  namespace std
  {
    template <int n, typename Func, typename Args...>
    auto apply_helper(Func func, Args... args)
    {
      // n is number of already-unpacked arguments
      constexpr auto r = sizeof...(args) - n; // remaining tuples
      if constexpr (r == 0)
        return func(args...);

      auto&& t = [n]args;
      auto k = sizeof...(t);
      return apply_helper<n + k>(func, [:n]args, [:]t..., [n+1:]args);
    }

    template <typename Func, typename Tuples...>
    auto apply(Func func, Tuples... tuples)
    {
      return apply_helper<0>(func, tuples);
    }
  }

Although this is feasible, and would ideally optimize down to a direct call of the specified function with all of the tuple values extracted directly, it is not meant to imply that this is the only possible solution, nor necessarily even the *best* solution. In particular, we would again note that pack generators would offer an even better solution to this specific problem. Rather, this example is intended to show how our proposed feature allows tail-recursive unpacking of multiple product types; in particular, without using a new tuple to wrap the values as they are unpacked.


Discussion
==========

What is a "product type"?
-------------------------

This is an excellent question which deserves its own paper. P0327_ makes a good start. When we get to the point of specifying wording, this will need to be addressed; ideally, this will have happened in parallel. Some "working definitions" which may be used to help with consideration of this proposal are "types which define :cpp:`tuple_size` and :cpp:`get`", or "types to which 'structured binding' / 'assignment unpacking' may be applied".

Why combine these features?
---------------------------

We prefer to think of this proposal as not two separate features (parameter pack slicing, generalized unpacking), but rather a single feature (product type slicing) that works on *both* "concrete" product types and parameter packs. Seen in this light, the case for the feature is strengthened, as it presents a single syntax that solves multiple problems.

Why choose prefix :cpp:`operator[]`?
------------------------------------

Other alternatives that have been proposed or considered:

- :cpp:`t.N`, :cpp:`t~N`

  While these work for at least the single value case, they are less conducive to slicing, nor are they as readily extended to generalized unpacking. The use of an integer in place of an identifier also seems unusual; worse, there is a potential conflict when using a :cpp:`constexpr` expression as the index (although this could be solved by enclosing the expression in ``()``\ s).

- :cpp:`t.[L:U]`, :cpp:`t~(L:U)`

  These support slicing, but the syntax is starting to look rather strange.

The exact syntax for these features could be debated. We prefer prefix :cpp:`operator[]` because C++ programmers are already familiar with :cpp:`operator[]` as an indexing operator, which is essentially what we are proposing (especially for the single value case), and because the proposed syntax is very similar to Python, which will already be familiar to some C++ programmers. At the same time, the choice of a prefix as opposed to postfix syntax makes it clear that the slicing operation |--| which we like to think of as *compile-time indexing* |--| is different from the usual *run-time indexing*.

Does this make :cpp:`std::apply` (and :cpp:`std::make_from_tuple`) obsolete?
----------------------------------------------------------------------------

No. There will almost certainly remain cases where :cpp:`std::apply` and/or :cpp:`std::make_from_tuple` are useful; for example, when using the operation as a functor that gets passed as an argument, or when expansions are nested. In fact, we use :cpp:`std::apply` in at least one of the preceding examples *in conjunction with* our proposed feature.

That said, we do expect that *most* uses of :cpp:`std::apply` and :cpp:`std::make_from_tuple` can be replaced with the use of this feature.

Are "dead" access to product type value elided?
-----------------------------------------------

Consider the following code:

.. code:: c++

  // let t be a product type ("tuple-like") of size 3
  auto x = [1]t;

What code is actually generated by the above?

.. code:: c++

  // option 1
  [[maybe_unused]] get<0>(t);
  auto x = get<1>(t);
  [[maybe_unused]] get<2>(t);

  // option 2
  auto x = get<1>(t);

In most cases, the question should be irrelevant; the compiler will eliminate the superfluous calls to :cpp:`get` as accomplishing nothing. However, if :cpp:`get` has side effects (however much we might be inclined to consider that poor design), this could matter.

Certainly in the above example, we believe that the compiler should elide the "superfluous" value accesses, as this feels like the most natural consequence of combining the unpacking and slicing operations. A more interesting question, which we believe should be open to committee input, is what to do if slicing and unpacking are explicitly separated, as in :cpp:`[1][:]t`. While our inclination is that this form should be exactly equivalent to :cpp:`[1]t`, an argument could be made that writing out the operations separately implies that the programmer intends for each value of :cpp:`t` to be accessed, with any resulting side effects incurred, before reducing the resulting parameter pack to only the value at index ``1``.

If we consider an initializer list to be a product type, conceivably a user desiring side effects could obtain them by writing :cpp:`[1]{[:]t...}`, which makes the intent to evaluate all values of :cpp:`t` prior to selecting a single value even more explicit.

What about ambiguity with lambda captures?
------------------------------------------

A lambda capture is required to be a variable in the current scope. As such, the compiler can determine if a :cpp:`[` starts a lambda capture or a slicing expression by parsing at most three additional tokens. If the first token following the :cpp:`[` is not a variable eligible for lambda capture (for example, an integer literal), then the :cpp:`[` starts a slicing expression. If the first token matches an in-scope (and :cpp:`constexpr`) variable name, and the second token is not a :cpp:`,`, then the :cpp:`[` starts a slicing expression. In all other cases, the :cpp:`[` shall be taken to start a lambda capture, as in current C++. (If the first token is :cpp:`&`, the preceding rules may be applied with the token counts shifted by 1. However, this assumes that there exists a case where unary :cpp:`operator&` is :cpp:`constexpr`. This may not be reasonable, in which case :cpp:`[&` would always indicate a lambda capture, and at most only two tokens following :cpp:`[` must be parsed.)

Consider the following example:

.. code:: c++

  constexpr int a = ...;
  [a]t;

By the above logic, this would be ill-formed. Although a slicing expression is intended, the compiler would be unable to disambiguate from a lambda until after the :cpp:`]`, and following the above logic, the statement is parsed as a lambda. Such an expression calls for disambiguation:

.. code:: c++

  constexpr int a = ...;
  [(a)]t;

The addition of parentheses does not change the intended meaning of the statement, but precludes the statement from being parsed as a lambda capture. We believe that this is an acceptable trade-off to prevent unreasonable complexity in selecting between a slicing expression and a lambda capture.

Note also:

.. code:: c++

  template <int n> auto get_and_apply(auto func, auto... items)
  {
    return func([n]args);
  }

Although this example appears at first to be the same as the preceding example, :cpp:`n` here is a template parameter and is not eligible for lambda capture, so the expression is parsed as a slicing expression instead (as intended). Again, this seems like a reasonable trade-off, but we would be amenable to requiring parentheses in all cases where the index-expression is just an identifier.

An alternative approach, albeit one requiring additional look-ahead, is to consider the token following the closing :cpp:`]`. If the token is not :cpp:`(`, then we have a slicing expression. If it is :cpp:`(` and the next token is *not* a type name, then we have a slicing expression. Otherwise, we have a lambda capture. This may be more robust, at the cost of being more difficult to implement in compilers.

Why choose trailing index?
--------------------------

The choice of the second value as a non-inclusive index, rather than a count, was made for consistency with existing convention (specifically, Python), because it is consistent with counting indices given a lower and upper bound, and because it simplifies the computation of the upper index when a negative value is given.

It is also worth noting that more complicated index expressions may be used to obtain a first-and-count slice using lower-until-upper notation or vice versa. More importantly, however, a first-and-count slice may be obtained like :cpp:`[:count][first:]pack`, but obtaining a lower-until-upper slice with first-and-count syntax is more verbose.

Why extend :cpp:`sizeof...`?
----------------------------

The short answer is "symmetry". It seems logical to us that if slicing works on both parameter packs and "concrete" product types that :cpp:`sizeof...` should do likewise. However, this modification could be dropped without significantly harming the proposal.

What alternatives were considered?
----------------------------------

There are at least three possible alternatives that could provide features similar to generalized unpacking, as proposed here. The first alternative is first class support for multiple return values, where such are treated as parameter packs. The second is modifying structured binding (which we prefer to call "assignment unpacking", for symmetry with "generalized unpacking") to support specifying a parameter pack as one of the unpacked values. The third is to introduce parameter pack generators.

- First class support for multiple return values (which is effectively proposed by P0341_) is an ambitious feature with assorted difficulties (see next question). Moreover, if FIXME_ is accepted, the need for true first class multiple return values would be significantly lessened.

- Modifying assignment unpacking (e.g. :cpp:`auto&& [x, p..., y] = t;`) is likewise a language change of similar caliber to what we propose, with the added drawback of requiring additional declarations for many use cases.

- Parameter pack generation is interesting (in fact, we would like to see parameter pack generation *in addition* to this proposal), but still requires the ability to extract a single element from a pack.

All of these would require greater verbosity for even simple use cases.

We believe that our proposal is the best solution, as it solves a crucial need not addressed by these alternatives (extracting a single value from a parameter pack) and further leverages that syntax to maximum versatility with minimal overhead compared to the minimum possible functionality.

How does this relate to P0341_?
-------------------------------

We would be remiss to not discuss P0341_, especially in light of our proposed generalized unpacking feature. Leaving aside various concerns as far as returning parameter packs (which are also discussed in FIXME_), generalized unpacking obviates a major use case for some of the features proposed by P0341_. In particular, P0341_ gives this example:

.. code:: c++

  <double, double> calculateTargetCoordinates();
  double distanceFromMe(double x, double y);

  void launch() {
    if(distanceFromMe(calculateTargetCoordinates()...))
      getOuttaHere();
  }

The utility of being able to invoke the postulated :cpp:`distanceFromMe` function taking two parameters is obvious. However, the solution proposed by P0341_ is strictly limited in that it requires that the function providing the input values |--| :cpp:`calculateTargetCoordinates` |--| must provide them as a parameter pack. Moreover, it is not obvious at the point of use that :cpp:`calculateTargetCoordinates` returns a parameter pack rather than a regular type.

Generalized unpacking provides a much better solution:

.. code:: c++

  std::tuple<double, double> calculateTargetCoordinates();
  double distanceFromMe(double x, double y);

  void launch() {
    if(distanceFromMe([:]calculateTargetCoordinates()...))
      getOuttaHere();
  }

The return type of :cpp:`calculateTargetCoordinates` is a regular type, and we can call :cpp:`distanceFromMe` on any product type value that can convert (or be sliced) to a pair of :cpp:`double`\ s.


Future Direction
================

This feature is not intended to solve all cases of value sequence compositions and decompositions by itself. We specifically are not attempting to provide a language mechanism for reversing a value sequence, selecting indices (e.g. every other item) from a value sequence, or interleaving value sequences. We believe that there is significant room for library features to bring added value to this area. Such features would likely leverage this feature under the covers. (Parameter pack generation, which as noted is a feature we would like to see, almost certainly would use at least single-value indexing into parameter packs.)


Acknowledgments
===============

We wish to thank everyone on the ``std-proposals`` forum that has contributed over the long period for which this has been marinating.


References
==========

.. _N4235: http://wg21.link/n4235

* N4235_ Selecting from Parameter Packs

  http://wg21.link/n4235

.. _P0222: http://wg21.link/p0222

* P0222_ Allowing Anonymous Structs as Return Values

  http://wg21.link/p0222

.. _P0311: http://wg21.link/p0311

* P0311_ A Unified Vision for Manipulating Tuple-like Objects

  http://wg21.link/p0311

.. _P0327: http://wg21.link/p0327

* P0327_ Product Types Access

  http://wg21.link/p0327

.. _P0341: http://wg21.link/p0341

* P0341_ Parameter Packs Outside of Templates

  http://wg21.link/p0341

.. _P0478: http://wg21.link/p0478

* P0478_ Template argument deduction for non-terminal function parameter packs

  http://wg21.link/p0478

.. FIXME link to p0222/p0224 successor

.. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ..

.. |--| unicode:: U+02014 .. em dash

.. kate: hl reStructuredText
