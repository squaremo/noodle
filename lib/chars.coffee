# Operators on streams of strings.  Often the approach is to look at
# (e.g.) a file as a sequence of characters, and reconstitute
# strings/byte-arrays on the way out. However, that's going to be
# pretty inefficient here given the consing generated, so instead I'll
# implement some basic transformations on streams of strings instead.

seq = require('./sequence')

split = (char, stream) ->
    splitStrings1 = (remainder, s) ->
        (Cons, Nil, Skip) ->
            s(((v, r) ->
                words = (remainder + v).split(char)
                rem = words.pop()
                if words.length > 0
                    Cons(words, splitStrings1(rem, r))
                else
                    Skip(splitStrings1(rem, r))),
              (() -> Cons(remainder, seq.NIL)),
              ((r) -> splitStrings1(remainder, r)))
    seq.concatMap(seq.fromArray, splitStrings1("", stream))

exports = (exports ? this)

exports.split = split
# Just because it's so common ..
exports.lines = (s) -> split('\n', s)
