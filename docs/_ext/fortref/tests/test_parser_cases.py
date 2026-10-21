"""Synthetic fixtures, one per parser case."""

import textwrap

from fortref import cpp, parser


def model(src, macros=None, path='t.F90', profile='test'):
    lines = textwrap.dedent(src).lstrip('\n').split('\n')
    if lines and lines[-1] == '':
        lines.pop()
    return parser.build_from_lines(path, lines, 'sha', profile, macros or {})


def units(m):
    return [(u.qualname, u.kind, u.start, u.end) for u in m.units]


def test_interface_bodies_are_declarations_not_units():
    m = model("""
        module m
          interface
            function f(x)
              real :: f, x
            end function f
            subroutine s(y)
              real :: y
            end subroutine s
          end interface
          interface operator(+)
            module procedure add
          end interface
        contains
          function add(a, b)
            real :: add, a, b
            add = a + b
          end function add
        end module m
        """)
    assert m.errors == []
    assert units(m) == [('m', 'module', 1, 18), ('m/add', 'function', 14, 17)]
    assert m.declarations == [('f', 3), ('s', 6)]


def test_bang_inside_strings():
    m = model("""
        subroutine s()
          print*, "not a comment ! end subroutine s"
          print*, 'it''s ! still a string'; x = 1 ! a comment; end
          print*, "a string with ! and ; that continues &
               &onto the next line ! still inside"; y = 2
        end subroutine s
        """)
    assert m.errors == []
    assert units(m) == [('s', 'subroutine', 1, 6)]
    texts = [st.text for st in m.stmts]
    assert texts[2] == "print*, 'it''s ! still a string'"
    assert texts[3] == 'x = 1'
    assert texts[4].startswith('print*, "a string with ! and ; that continues ')
    assert texts[4].endswith('onto the next line ! still inside"')
    assert (m.stmts[4].first, m.stmts[4].last) == (4, 5)
    assert texts[5] == 'y = 2'


def test_continued_headers():
    m = model("""
        recursive &
           subroutine first(a, &
        ! a comment between continuation lines
                            & b)
          integer :: a, b
        end subroutine first

        real(kind=8) &
             function second(x) &
             result(r)
          real(kind=8) :: x, r
          r = x
        end function second
        """)
    assert m.errors == []
    assert units(m) == [('first', 'subroutine', 1, 6), ('second', 'function', 8, 13)]


def test_semicolons_split_statements():
    m = model("""
        subroutine a(); x = 1; end subroutine a
        subroutine b()
          y = 1; z = 2
        end subroutine b
        """)
    assert m.errors == []
    assert units(m) == [('a', 'subroutine', 1, 1), ('b', 'subroutine', 2, 4)]
    assert [st.text for st in m.stmts if st.first == 3] == ['y = 1', 'z = 2']


def test_bare_end_enddo_endif():
    m = model("""
        FUNCTION F(N)
        INTEGER N, F, I
        F = 0
        DO I = 1, N
          IF (I > 2) THEN
            F = F + I
          ENDIF
        ENDDO
        END
        SUBROUTINE G
        CALL H
        END SUBROUTINE
        subroutine h()
        endsubroutine h
        """)
    assert m.errors == []
    assert units(m) == [('F', 'function', 1, 9), ('G', 'subroutine', 10, 12),
                        ('h', 'subroutine', 13, 14)]
    do = next(i for i, st in enumerate(m.stmts) if st.text.startswith('DO'))
    assert m.stmts[m.closer[do]].text == 'ENDDO'


def test_typed_and_result_functions():
    m = model("""
        module m
          type vector
            real :: x
          end type vector
        contains
          real(kind=8) function a(x)
            real(kind=8) :: x
            a = x
          end function a
          integer function b(n) result(r)
            integer :: n, r
            r = n
          end function b
          elemental real function c(x)
            real, intent(in) :: x
            c = x
          end function c
          type(vector) function d(v)
            type(vector) :: v
            d = v
          end function d
          double precision function e(x)
            double precision :: x
            e = x
          end function e
          recursive integer function fact(n) result(res)
            integer :: n, res
            res = 1
            if (n > 1) res = n * fact(n - 1)
          end function fact
          logical pure function p()
            p = .true.
          end function p
        end module m
        """)
    assert m.errors == []
    assert [u.qualname for u in m.units] == ['m', 'm/a', 'm/b', 'm/c', 'm/d', 'm/e', 'm/fact', 'm/p']


SWITCH = """
    #ifdef A
    subroutine one()
    #elif B
    subroutine two()
    #elif defined(C) && !defined(D)
    subroutine three()
    #else
    subroutine four()
    #endif
      x = 1
    end subroutine
    """


def test_ifdef_elif_else_with_bare_macro_elif():
    pick = lambda macros: [u.name for u in model(SWITCH, macros).units]  # noqa: E731
    assert pick({'A': '1', 'B': '1'}) == ['one']
    assert pick({'B': '1'}) == ['two']           # bare-macro #elif, defined as 1
    assert pick({'B': '0'}) == ['four']          # defined as 0 is false
    assert pick({'C': '1'}) == ['three']
    assert pick({'C': '1', 'D': '1'}) == ['four']
    assert pick({}) == ['four']
    m = model(SWITCH, {'B': '1'})
    # lines are marked, never removed
    assert m.nlines == 11 and m.active == [True, False, True, True, True, False, True,
                                           False, True, True, True]
    assert m.directive[:9] == [True, False, True, False, True, False, True, False, True]
    assert m.cpp_closer == {0: 8} and m.cpp_sibling == {0: 2, 2: 4, 4: 6, 6: 8}


def test_nested_and_ifndef():
    m = model("""
        #ifndef X
        #if CRATTENUATION == 1
        subroutine a()
        #elif CRATTENUATION == 2
        subroutine b()
        #endif
        #endif
        subroutine c()
        end subroutine c
        """, {'CRATTENUATION': '2'})
    assert [u.name for u in m.units] == ['b', 'c'] and m.errors[0][1].startswith('subroutine b')


def test_crlf_lines(tmp_path):
    f = tmp_path / 'crlf.f90'
    f.write_bytes(b'module m\r\ncontains\r\n  subroutine s()\r\n    x = 1 ! c\r\n'
                  b'  end subroutine s\r\nend module m\r\n')
    lines, sha = parser.read_lines(str(f))
    assert len(lines) == 6 and lines[0] == 'module m\r'
    m = parser.build_from_lines('crlf.f90', lines, sha, 'p', {})
    assert m.errors == []
    assert units(m) == [('m', 'module', 1, 6), ('m/s', 'subroutine', 3, 5)]


def test_form_feed():
    m = model('module m\n\f\ncontains\n\f  subroutine s()\n  end subroutine s\n\fend module m\n')
    assert m.errors == []
    assert units(m) == [('m', 'module', 1, 6), ('m/s', 'subroutine', 4, 5)]
    assert m.is_blank(2)


def test_mismatched_and_unclosed_units_are_errors():
    m = model("""
        module m
        contains
          subroutine s()
          end subroutine t
        end module m
        subroutine u()
        """)
    msgs = [e[1] for e in parser.unit_errors(m)]
    assert any('does not match the open subroutine s' in x for x in msgs)
    assert any('subroutine u is never closed' in x for x in msgs)


def test_constructs_siblings_and_labels():
    m = model("""
        subroutine s(n)
          outer: do i = 1, n
            select case (n)
            case (1)
              a = 1
            case default
              a = 2
            end select
          end do outer
          do 10 j = 1, n
            b = j
        10 continue
          where (x > 0) y = 1
          where (x > 0)
            y = 2
          elsewhere
            y = 3
          end where
        end subroutine s
        """)
    assert m.errors == []
    first = {st.first: i for i, st in enumerate(m.stmts)}
    assert m.stmts[m.closer[first[2]]].first == 9            # named do
    assert m.stmts[m.sibling[first[4]]].first == 6           # case -> next case
    assert m.stmts[m.sibling[first[6]]].first == 8           # case default -> end select
    assert m.stmts[m.closer[first[10]]].first == 12          # labelled do -> its label
    assert first[13] not in m.closer                        # one-line where
    assert m.stmts[m.closer[first[14]]].first == 18


def test_c_functions_and_braces():
    m = model("""
        #include <stdio.h>
        static int helper(int x);
        /* a comment { with a brace */
        int calc_(double *a,
                  int *n)
        {
          if (*n > 0) {
            a[0] = 1.0; /* } */
          }
          return 0;
        }
        static int table[2] = {1, 2};
        static int helper(int x)
        {
          return x;
        }
        """, path='t.c')
    assert m.errors == []
    assert [(u.name, u.start, u.end) for u in m.units] == [('calc_', 4, 11), ('helper', 13, 16)]
    assert m.braces[7] == 9


def test_cpp_expressions():
    ev = cpp.eval_expr
    assert ev('defined(A) && !defined(B)', {'A': '1'}) == 1
    assert ev('defined A || defined B', {}) == 0
    assert ev('X == 1', {}) == 0
    assert ev('X == 2', {'X': '2'}) == 1
    assert ev('(1 + 2) * 3 > 8', {}) == 1
    assert ev('PREFIX', {'PREFIX': '"/usr/local"'}) == 0
