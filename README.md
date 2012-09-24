# Noodling around with sequences

Some coffee scripts with an encoding of sequences (streams, whatever)
and the accompanying combinators.

There's two kinds of sequences here, which I'll describe as
*demand-driven* (new values are calculated by need, like lazy
sequences in Clojure), and *producer-driven*, in which there's some
process adding values onto the tail of the sequence, while another
process chases the head of the sequence.

One can give them the same treatment given a careful encoding. The one
I've chosen is that a sequence is a function, which when given a
"menu' of `Cons` and `Nil` continuations (callbacks, if you prefer),
will either provide a head and tail to cons, or call nil to indicate
the end of the sequence. Because the continuations are reified we can
stow them away if we don't currently know the answer, which is why we
can encode producer-driven sequences. It also lets us define sequence
combinators (map, filter) rather simply.

There's an additional twist: writing certain combinators typically
requires some recursion, which in a language like JavaScript with no
constant-stack tail call will easily overflow the stack. For this
reason, an additional continuation -- `Skip` -- is introduced to the
menu, which is called when the computation needs to proceed without
considering an element (e.g., in filter).

## Sequences

    require('sequence')

Let's treat with demand-driven sequences first. With these, a value is
available every time you ask for one -- which means you can iterate
through values in a loop (`doSeq` does this), so long as there aren't
infinitely many.

### Constructors

**`NIL`** is the sequence with no values.

**`cons(head, tailfn)`** constructs a sequence with the `head` and the tail
yielded by the thunk `tailfn`. The tail is guarded this way so that one
may construct recursively-defined sequences. (These don't necessarily
make a lot of sense for JavaScript, outside of fun examples)

For example,

    alternate = cons(true, -> cons(false, -> alternate))

gives the sequence `true, false, true, false, ...`

**`unfold(seed, fn)`** generates an infinite sequence by applying fn,
first to seed, then to successive return values.

For example,

    unfold(0, (x) -> x + 1)

gives a sequence of the natural numbers.

**`fromArray(values)`** is a convenience for constructing a finite
 sequence of the values given. This is useful for writing tests (those
 tests there are) of course, but also for lifting results of "regular"
 procedures into sequences. See for example the implementation of
 `split`.

### Combinators

**`map(fn, seq)`** gives a sequence of the function `fn` applied to
 the values of `seq`.

**`filter(predicate, seq)`** gives a sequence of the values of `seq` for
 which `predicate` returns `true`.

**`concatMap(fn, seq)`** is like `map`, but expects `fn` to return a
 sequence; successive such values are concatenated to yield a "flat"
 sequence. Useful (possibly in conjunction with `fromArray`) for
 mapping a function which may return zero or more values.

**`zipWith(fn, a, b)`** gives a sequence that consists of `fn` applied
 to values of `a` and `b` point-wise. For example,

    zipWith(((x, y) -> x + y), a, b)

gives the sequence of the first value of a plus the first value of b,
then the second value of a plus the second value of b, and so
on. Either sequence ending will end the result.

**`lift`** takes a unary operation on values and gives an operation on
 streams; in other words,

    lift(fn) === (a) -> map(fn, a)

**`lift2`** takes a binary operation on values and gives a binary
 operation on streams.

    lift2(fn) === (a, b) -> zipWith(fn, a, b)

### Operations

**`take(n, seq)`** gives a sequence with only the first `n` values of
 `seq`, or fewer if `seq` has fewer than `n`.

**`drop(n, seq)`** gives `seq` after discarding `n` values.

**`tail(seq)`** discards the first value in `seq` and yields the
 remaining sequence. For simplicity a sequence with no values is
 treated as its own tail.

**`memoise(seq)`** gives a sequence which remembers values once they
 have been computed; this is sometimes necessary for avoiding
 exponential blowout in recursively-defined sequences. Since this
 forces the whole sequence to be kept in memory, it's a
 trade-off.

**`replace(a, b)`** yields a value of `b` for each value of `a`
 realised. This is useful when `a` is "driving" the computation, but
 it's the values of `b` you want; for example, if `a` is incoming
 events, and `b` is a count.

**`doSeq(proc, seq)`** applies the (typically side-effecting) procedure
 `proc` with each value of `seq`. For example,

    doSeq(console.log, take(100, unfold(0, (x) -> x + 1)))

`doSeq` spins in a while loop, and for this reason is only suitable
for demand-driven sequences, and finite ones at that; otherwise it'll
happily spin forever.

## Event streams

    require('events')

Event streams (for want of a better term) are producer-driven
sequences. This means you get both the sequence and the means of
injecting new values into it (and of ending it). The idea is that the
values come from I/O of some kind; for instance, a DOM event handler,
or a socket.

Event streams work with the combinators and operations above. Using
`doSeq` will spin because of the way it's written as a loop; a
replacement, `doEvents`, is given for event streams.

**`events()`** yields an object `{stream, inject, stop}`. `stream` is
 the initial sequence head; `inject` adds another value to the sequence
 tail; and `stop` ends the sequence.

**`doEvents(proc, seq)`** applies `proc` to each value of `seq`. This
 will recurse in the case of demand-driven sequences, so use only with
 event streams. It returns a promise which is resolved at the
 (possibly never-arriving) end of the stream.

## Strings

    require('chars')

**`split(seq, char)`** gives a sequence of the concatenation of values
  in `seq` (assuming they are strings), split into substrings at each
  instance of the character `char`.

For example,

    split(fromArray(['foo\nba', 'r\nbaz\n', 'boo']), '\n')

gives the sequence `'foo', 'bar', 'baz', 'boo'`.
