===================
  Class Namespace
===================
~~~~~~~~~~~~~~~~~~~
 November 19, 2015
~~~~~~~~~~~~~~~~~~~

This proposal provides a new language feature, "class namespace", as a shortcut for providing a series of definitions belonging to a class scope, similar to the manner in which a traditional namespace can provide a series of definitions belonging to a namespace scope.


Rationale
=========

`Don't Repeat Yourself <https://en.wikipedia.org/wiki/Don't_repeat_yourself>`_ (DRY) is a well known principle of software design. However, there are certain instances when providing definitions of class members that can fall prey to repetition, to the detriment of readability and maintainability.

We will present, as a particularly egregious example, a complicated template class::

  template <typename CharType, typename Traits, typename Allocator>
  class MyString { ... };

There are strong reasons why method definitions should not be inline. For starters, they inhibit readability; it is difficult to quickly parse the interface |--| especially the public interface |--| as declarations and definitions are necessarily interleaved. Additionally, they are *inline*, which results in all manner of compile time and cross-version compatibility issues. Even for template classes, it is sometimes preferred to keep definitions in a separate TU (e.g. extern templates with only specific, exported explicit instantiations).

The problem that arises is the necessity to repeat a long prefix for all definitions provided outside of the class definition. For example::

  template <typename CharType, typename Traits, typename Allocator>
  MyString<CharType, Traits, Allocator>::MyString
  { ... }

This is a real, extant problem. Presumably as a result of this overhead, some authors will use only inline definitions of methods, which can make it difficult to separate implementation details |--| which are often unnecessary noise for a user trying to understand a class |--| from a class's interface. Other authors may resort to separating return types, template parameters, class names, and method names, placing each on separate lines, resulting in method headers that are four lines long even before the argument list is considered. In the latter case, the need to repeat the class prefix is frustrating and, in the author's opinion, unnecessary.

(See https://groups.google.com/a/isocpp.org/forum/#!topic/std-proposals/e0_ceXFQX-A for additional discussion.)


Proposal
========

This proposal is to eliminate the redundancy by introducing a new "class scope" syntax, as follows::

  template <...> // optional; only used for template classes
  namespace class Name
  {
    // definitions of class members
  }

The effect of this scope is to treat each member definition (variable or method) as if it were prefixed by the class template specification and name. Specifically, these two codes would be exactly equivalent::

  // Declarations
  class A { ... };

  template <typename T> class B { ... };

  // Existing syntax
  A::A(...) { ... }
  void A::foo(...) { ... }

  template <typename T> B<T>::B(...) { ... }
  template <typename T> B<T>& B<T>::operator=(B<T> const& other) { ... }
  template <typename T> void B<T>::bar(...) { ... }

  // Proposed syntax
  namespace class A {
    A(...) { ... }
    void foo() { ... }
  }

  template <typename T>
  namespace class B<T> {
    B(...) { ... }
    B<T>& operator=(B<T> const& other) { ... }
    void bar(...) { ... }
  }

Additionally, ``namespace struct`` and ``namespace class`` shall be equivalent and interchangeable.


Discussion
==========

The proposed syntax for introducing the scope is open for debate. Alternative suggestions include:

#. ``class namespace <name>``
#. ``namespace <classname>``
#. Introduction of a new keyword.

The author considers #1 to be equally as good as the suggested syntax. #2 is nearly as good, although it risks confusion, as the reader must know a priori if the named scope is a class. The #2 syntax would only introduce a class name scope if the identifier following the ``namespace`` keyword is an already declared class-type. #3 has the advantage of maximum possible clarity, but introducing new keywords without breaking existing code is always tricky. Additionally, the author was unable to come up with any ideas for new keywords that seemed a significant improvement over the other suggestions.


Possible Additions
==================

A potential addition to the proposal in the case of template classes would be to assume the same template parameters when the class name appears without a template argument list. For example::

  template <typename T>
  namespace class B<T> {
    B& operator=(B const& other) { ... }
  }

Using only the above rules, this would be equivalent to::

  template <typename T> B& B<T>::operator=(B const& other) { ... } // error

...which is illegal because the template type ``B`` is used without an argument list. This is currently an issue because the use of ``B`` specifying the context of the member function follows the use of ``B`` as a return type. Since the typical use is to use the same arguments as the member context, and since the member context has been declared as the enclosing scope, it becomes much more practical to treat a use of the class name without a template argument list as having the same template arguments as the enclosing scope. (Cases where this is not correct would be able to provide a template argument list as usual.)

However, the use of trailing and inferred return types already mitigates this significantly::

  template <typename T> auto B<T>::operator=(B const& other) -> B& {  } // okay in C++11 or later

The author feels that a decision whether or not to include this definition should be based mainly on a "principle of least surprise" given code such as the first example in this section.


Acknowledgments
===============

The original suggestion that spawned this proposal comes from John Yates. Other contemporary participants include Larry Evans, Russell Greene, Evan Teran and Andrew Tomazos. (The author also acknowledges prior discussion of a very similar feature: see https://groups.google.com/a/isocpp.org/d/msg/std-proposals/xukd1mgd21I/uHjx6YR_EnQJ and https://groups.google.com/a/isocpp.org/d/msg/std-proposals/xukd1mgd21I/gh5W0KS856oJ.)

.. |--| unicode:: U+02014 .. em dash
