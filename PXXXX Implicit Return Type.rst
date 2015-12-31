========================
  Implicit Return Type
========================
~~~~~~~~~~~~~~~~~~~
 December 30, 2015
~~~~~~~~~~~~~~~~~~~

.. raw:: html

  <style>
    html { color: black; background: white; }
  </style>

.. role:: cpp(code)
   :language: c++


Abstract
========

This proposal recommends an enhancement to return type deduction to allow the return type of a function definition to be inferred from a previous declaration of the same.

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

The use of ``auto`` as the return type specifier, with no trailing return type, and for a function that has been previously declared with a known return type, shall instruct the compiler to define the function using the return type from the previous declaration. (Note that this works for *any* type, not just anonymous ``struct``\ s.)

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


Discussion
==========

An obvious follow-on question is, should we also lift the prohibition against types defined in parameter specifications? There have been suggestions floated to implement the much requested named parameters in something like this manner. However, there are significant (in our opinion) reasons to not address this, at least initially. First, it is widely contested that this is not an optimal solution to the problem (named parameters) in the first place. Second, it depends on named initializers, which is an area of ongoing work. Third, this proposal works largely because C++ forbids overloading on return type, which may be leveraged to eliminate any ambiguity as to the deduction of the actual type of ``auto``; this is not the case for parameters, and so permitting ``auto`` as a parameter type specifier would quickly run into issues that can be avoided for the return type case.

While we do not wish to categorically rule out future changes in this direction, we feel that it is not appropriate for this proposal to attempt to address these issues.

On a related note, it is not strictly necessary for the sake of the added utility of implied return type to relax [dcl.fct]/11. However, much of the benefit is lost with this prohibition in place. Conversely, simply relaxing the prohibition is of significantly less benefit without the proposed implied return type feature. Accordingly, while we considered splitting the two changes into separate proposals, we have decided for now to keep them together.


.. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. ..

.. _N4560: http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2015/n4560.pdf
.. _P0144: http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2015/p0144r0.pdf
.. _P0151: http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2015/p0151r0.pdf

.. |--| unicode:: U+02014 .. em dash
