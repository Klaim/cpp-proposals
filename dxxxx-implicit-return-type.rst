========================
  Implicit Return Type
========================

:Document:  DXXXX (TBD)
:Date:      2015-12-31
:Project:   ISO/IEC JTC1 SC22 WG21 Programming Language C++
:Audience:  Evolution Working Group
:Author:    Matthew Woehlke (mwoehlke.floss@gmail.com)

.. raw:: html

  <style>
    html { color: black; background: white; }
    table.docinfo { margin: 2em 0; }
    .literal-block { background: #eee; border: 1px solid #ddd; padding: 0.5em; }
    .addition { color: #2c2; text-decoration: underline; }
    .removal { color: #e22; text-decoration: line-through; }
    .literal-block .literal-block { background: none; border: none; }
    .block-addition { background: #cfc; text-decoration: underline; }
  </style>

.. role:: add
    :class: addition

.. role:: del
    :class: removal

Abstract
========

This proposal recommends an enhancement to return type deduction to allow the return type of a function definition to be inferred from a previous declaration of the same.

(Note: references made to the existing draft standard are made against N4567_.)

.. contents::


Rationale
=========

The concept of multiple return values is well known. At present, however, C++ lacks a good mechanism for implementing the same. ``std::tuple`` is considered clunky by many and, critically, creates sub-optimal API by virtue of the returned values being unnamed, forcing developers to rely on supplemental documentation to explain their purpose. Aggregates represent an improvement, being self-documenting, but the need to provide external definitions of the same is awkward and, worse, pollutes their corresponding namespace with entities that may be single use. Proposals such as N4560_ present a complicated mechanism for providing tagged (self-documenting) tuple-like types, which may be necessary in some cases, but still represent a non-trivial amount of complexity that ideally should not be required.

Proposals such as P0144_ (or its competitor P0151_) in particular would represent a significant step toward support of multiple return values as first class citizens. These proposals and other current directions show an encouraging movement away from the traditional ``std::pair`` and ``std::tuple`` towards comparable concepts without requiring the explicit types. (We expect, however, that these will remain useful for algorithms where the identity of the elements is unimportant, while it *is* important to be able to name at least the outer, if not complete, type. In that respect, we hypothesize that we may in the future see the ability to construct a ``std::tuple`` from any tuple-like.) On their own, however, these proposals risk exacerbating the problem that this proposal aims to address.

It has been suggested on multiple occasions that the optimal solution to the above issues is to return an anonymous ``struct``. This solves the problems of clutter and self-documentation, but runs afoul of a much worse issue; because the ``struct`` is *anonymous*, it can be difficult to impossible to give its name a second time in order to separate the declaration and definition of the function that wishes to use it.

However, in C++, functions cannot be overloaded by their return value. This leads to an obvious question: **why is it necessary to repeat the return value at all?**

Even in the case of return types that can be named, it may be that repeating the type name is excessively verbose or otherwise undesirable. Some might even call this a violation of the `Don't Repeat Yourself <https://en.wikipedia.org/wiki/Don't_repeat_yourself>`_ principle, similar to some of the issues that ``auto`` for variable declaration was introduced to solve. (On the flip side, one could see the ability to elide the return type as subject to many abuses, again in much the manner of ``auto``. However, many language features can be abused; this should not prevent the addition of a feature that would provide an important benefit when used correctly.)

We would be remiss not to note that this is already possible in simple cases using ``decltype`` and a sample invocation of the function. However, while this may be adequate in simple cases, it is nevertheless needlessly verbose, and as the argument list grows longer, and/or gains arguments for which providing a legal value is non-trivial, it can quickly become unwieldy and unfeasible.


Proposal
========

Recent changes to the language have progressively relaxed the requirements for how return types are specified. We began with trailing return type specification, and have progressed to inferred return types in certain cases.

This proposal is to continue this direction by adding an additional use of ``auto`` as a return specifier, meaning "use the return type seen when this function was previously declared". This provides an optimal solution to the following problem:

.. code:: c++

  // foo.h
  struct { int id; double value; } foo();

How does one now provide an external definition for ``foo()``? We propose:

.. code:: c++

  // foo.cpp
  auto foo()
  {
    ...
    return { id, value };
  }

The use of ``auto`` as the return type specifier, with no trailing return type, and for a function that has been previously declared with a known return type, shall instruct the compiler to define the function using the return type from the previous declaration.

Note that this works for *any* type, not just anonymous ``struct``\ s. In particular, it is equally usable for long and cumbersome template types, or even simple types (see earlier comments regarding DRY).

Naturally, "previous declaration" here means a declaration having the same name and argument list. This, for example, would remain illegal:

.. code:: c++

  struct { int id; int value; } foo(int);
  struct { int id; float value; } foo(float);

  auto foo(double input) // does not match any previous declaration
  {
    ...
    return { id, result };
  }

Additionally, and for obvious reasons, we propose to remove the prohibition ([dcl.fct]/11) against defining types in return type specifications. We additionally note that this prohibition is already not enforced by at least one major compiler (MSVC). We further believe this prohibition to be outdated; it made sense in C++98, but with recent changes such as the addition of ``decltype`` and the ability to omit the type name in a ``return`` statement returning an in-place constructed class, the reasons for the prohibition have been greatly mitigated. This other part of this proposal would largely remove any remaining motivation for the prohibition.


Proposed Wording
================

(Proposed changes are specified relative N4567_.)

Add a new section to [dcl.spec.auto] (7.1.6.4) as follows:

.. compound::
  :class: literal-block block-addition

  When a function is declared or defined using ``auto`` for the return type, and a previous declaration or definition having a concrete return type exists, the return type shall be inferred to be the previously seen concrete type.
  [*Example:*

  .. parsed-literal::

    std::string f();
    auto f(); // OK, return type is std::string

  |--| *end example*]

Add a new section to [dcl.spec.auto] (7.1.6.4) as follows:

.. compound::
  :class: literal-block block-addition

  A template function redeclaration or specialization having a return type of ``auto`` shall match a previous declaration (or definition) if the first such declaration had a concrete return type. If the first such declaration also had a return type of ``auto``, the declaration using return type deduction shall be matched instead.
  [*Example:*

  .. parsed-literal::

    template <typename T> T g(T t) { return t; } // #1
    template auto g(float); // matches #1

    template <typename T> auto g(T t) { return t; } // #2
    template <typename T> T g(T t) { return t; }
    template auto g(float); // matches #2

  |--| *end example*]

Change [dcl.fct]/11 (8.3.5.11) as follows:

.. compound::
  :class: literal-block

  Types shall not be defined in :del:`return or` parameter types.


Discussion
==========

What about template return types?
---------------------------------

In C++14, the following code is legal and produces two distinct templates:

.. code:: c++

  template <class T> int foo();
  template <class T> auto foo();

This obviously conflicts with the proposed feature. After discussion on ``std-proposals``, it was decided that the proposed feature should take precedence in this case. It should also be noted that it is unclear how, or even if, the second function can be invoked according to the current rules of the language. (To this end, it may be desirable to simply forbid the opposite ordering. However, we feel that this would be better addressed separately, perhaps even as a DR.)

Must the declaration providing the concrete type be the first declaration?
--------------------------------------------------------------------------

This question was originally brought up by Bengt Gustafsson. Specifically, for the sake of symmetry, it seems initially desirable to allow:

.. code:: c++

  int foo(); // specified return type
  auto foo() { return 42; } // return type inferred from prior declaration

  auto bar(); // forward declaration, type not yet known
  int bar(); // specify the return type as 'int'
  auto bar() { return 0; } // return type inferred from prior declaration

To that end, earlier drafts of the proposal included the following proposed change to [dcl.spec.auto]/13 (7.1.6.4.13):

.. compound::
  :class: literal-block

  Redeclarations or specializations of a function or function template with a declared return type that uses a placeholder type shall :del:`also use that placeholder` :add:`use either that placeholder or a compatible concrete type`, not a deduced type. :add:`If the return type has previously been deduced, a declaration using a concrete type shall use the deduced type.`
  [*Example:*

  .. parsed-literal::

    auto f();
    auto f() { return 42; } // return type is int
    auto f(); // OK
    :del:`int f(); // error, cannot be overloaded with auto f()`
    :add:`int f(); // OK, deduced type is also int`
    decltype(auto) f(); // error, auto and decltype(auto) don't match

    :add:`auto f(int);`
    :add:`int f(int); // OK, return type of f(int) is now int`
    :add:`float f(int); // error, redeclared with different return type`

However, upon further discussion, reservations were expressed, and the general consensus seems to be that it is okay for the first declaration to "set in stone" if the return type will be known (and possibly later inferred), or deduced. Accordingly, absent the above change:

.. code:: c++

  auto bar();
  int bar(); // error, violates [dcl.spec.auto]/13
  auto bar() { return 0; } // okay, but return type is deduced, not inferred

What about defining types in function pointer types?
----------------------------------------------------

An obvious consequence of relaxing [dcl.fct]/11 is the desire to permit function pointers which return an anonymous struct. For example:

.. code:: c++

  // Declare a function pointer type which returns an anonymous struct
  using ReturnsAnonymousStruct = struct { int result; } (*)();

  // Define a function using the same
  int bar(ReturnsAnonymousStruct f) { return ((*f)()).result; }

  // Provide a mechanism to obtain the return type of a function
  template <typename T> struct ReturnType;

  template <typename T, typename... Args>
  struct ReturnType<T (*)(Args...)>
  {
      using result_t = T;
  };

  // Declare a function that is a ReturnsAnonymousStruct
  ReturnType<ReturnsAnonymousStruct>::result_t foo() { return {0}; }

  // Use the function
  int main()
  {
      return bar(&foo);
  }

It is our opinion that the proposed changes are sufficient to allow the above. (In fact, this example is already accepted by both GCC and ICC (in C++11 mode even!), although it is rejected by clang per [dcl.fct]/11.) Accordingly, we feel that this proposal should be understood as intending to allow the above example and that additional wording changes to specify this behavior are not required at this time.

What about defining types in parameter types?
---------------------------------------------

An obvious follow-on question is, should we also lift the prohibition against types defined in parameter specifications? There have been suggestions floated to implement the much requested named parameters in something like this manner. However, there are significant (in our opinion) reasons to not address this, at least initially. First, it is widely contested that this is not an optimal solution to the problem (named parameters) in the first place. Second, it depends on named initializers, which is an area of ongoing work. Third, this proposal works largely because C++ forbids overloading on return type, which may be leveraged to eliminate any ambiguity as to the deduction of the actual type of ``auto``; this is not the case for parameters, and so permitting ``auto`` as a parameter type specifier would quickly run into issues that can be avoided for the return type case.

While we do not wish to categorically rule out future changes in this direction, we feel that it is not appropriate for this proposal to attempt to address these issues.

On a related note, it is not strictly necessary for the sake of the added utility of implied return type to relax [dcl.fct]/11. However, much of the benefit is lost with this prohibition in place. Conversely, simply relaxing the prohibition is of significantly less benefit without the proposed implied return type feature. Accordingly, while we considered splitting the two changes into separate proposals, we have decided for now to keep them together.

Another question that has come up is if something like this should be allowed:

.. code:: c++

  struct { int result; } foo() { ... }
  struct { int result; } bar()
  {
    return foo();
  }

Under the current rules (plus relaxed [dcl.fct]/11), these two definitions have different return types which are not convertible. It is our opinion that the rules making these types different are in fact correct and desirable, and this proposal specifically does *not* include any changes which would make the types compatible. We would, however, encourage a future (orthogonal) proposal which would allow something like this:

.. code:: c++

  struct { int result; } bar()
  {
    // The '[*]' operator here causes the compiler to store the input as a
    // temporary and generate an expression list from the unpacked members of
    // the same; it can be used anywhere an expression list is accepted
    return { [*]foo() };
  }

Conflicts with future "true" multiple return values?
----------------------------------------------------

There has been some discussion of "true" multiple return values, in particular with respect to RVO and similar issues. No doubt unpacking, if accepted, will play a part. A point that bears consideration is if moving down the path of using anonymous (or not) structs for multiple return values will "paint us into a corner" where future optimization potential is prematurely eliminated.

It is our hope that these issues can be addressed with existing compound types (which will have further reaching benefit), and that it is accordingly not necessary to hold back the features here proposed in the hope of something better coming along. As is often said, perfect is the enemy of good.


Future Directions
=================

In the Discussion_ section above, we presented a utility for extracting the return type from a function pointer type. The facility as presented has significant limitations; namely, it does not work on member functions and the several variations (e.g. CV-qualification) which apply to the same. We do not here propose a standard library implementation of this facility, which presumably would cover these cases, however there is room to imagine that such a facility could be useful, especially if the proposals we present here are adopted. (David Krauss points out that ``std::reference_wrapper`` can be used to similar effect... on *some* compilers. However, imperfect portability and the disparity between intended function and use for this result suggest that this is not the optimal facility for the problem.)

Another consideration that seems likely to come up is if we should further simplify the syntax for returning multiple values (conceivably, this could apply to both anonymous structs and to ``std::pair`` / ``std::tuple``). Some have suggested allowing that the ``struct`` keyword may be omitted. In light of P0151_, we can conceive that allowing the syntax ``<int x, double y> foo()`` might be interesting. At this time, we prefer to focus on the two features here presented rather than risk overextending the reach of this proposal. However, if this proposal is accepted, it represents an obvious first step to considering such features in the future.


Acknowledgments
===============

We wish to thank everyone on the ``std-proposals`` forum, especially Bengt Gustafsson and Tim Song, for their valuable feedback and insights.


References
==========

.. _N4567: http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2015/n4567.pdf

* N4567_ Working Draft, Standard for Programming Language C++

  http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2015/n4567.pdf

.. _N4560: http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2015/n4560.pdf

* N4560_ Extensions for Ranges

  http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2015/n4560.pdf

.. _P0144: http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2015/p0144r0.pdf

* P0144_ Structured Bindings

  http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2015/p0144r0.pdf

.. _P0151: http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2015/p0151r0.pdf

* P0151_ Proposal of Multi-Declarators (aka Structured Bindings)

  http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2015/p0151r0.pdf

.. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ..

.. |--| unicode:: U+02014 .. em dash
