# -*- tab-width: 4 -*-
{array, values, isStream} = require('../index')
{map, filter, drop, take, concatMap, zipWith} = require('../index')

resultEqual = (T, expected, s) ->
    T.ok(isStream(s))
    s.collect((res) -> T.deepEqual(expected, res); T.done())

plus = (a, b) -> a + b
plusOne = (n) -> n + 1
isEven = (n) -> n % 2 is 0
pair = (n) -> values(n, n*n)

# The basic stuff, using the objecty API

exports.testArray = (T) ->
    vals = [1, 2, 3, 4]
    resultEqual(T, vals, array(vals))

exports.testValues = (T) ->
    resultEqual(T, [1,2,3,4], values(1, 2, 3, 4))

exports.testDotMap = (T) ->
    a = values(1, 2, 3, 4)
    resultEqual(T, [2,3,4,5], a.map(plusOne))

exports.testDotFilter = (T) ->
    a = values(1,2,3,4,5)
    resultEqual(T, [2,4], a.filter(isEven))

exports.testDotTake = (T) ->
    a = values(1,2,3,4,5)
    resultEqual(T, [1,2,3], a.take(3))

exports.testDotDrop = (T) ->
    a = values(1,2,3,4,5)
    resultEqual(T, [4,5], a.drop(3))

exports.testDotConcatMap = (T) ->
    a = values(1,2,3)
    b = a.concatMap(pair)
    resultEqual(T, [1,1, 2,4, 3,9], b)

exports.testDotZipWith2 = (T) ->
    a = values(1,2,3,4)
    resultEqual(T, [2,4,6,8], a.zipWith(plus, a))

# Using the compositional API

exports.testMap = (T) ->
    a = values(1,2,3,4)
    resultEqual(T, [2,3,4,5], map((n) -> n+1).apply(a))

exports.testFilter = (T) ->
    a = values(1,2,3,4,5)
    resultEqual(T, [2,4], filter((n) -> n % 2 is 0).apply(a))

exports.testMapFilter = (T) ->
    a = values(1,2,3,4,5)
    resultEqual(T, [3,5], map(plusOne).filter(isEven).apply(a))

exports.testZipWith1 = (T) ->
    a = values(1,2,3,4)
    resultEqual(T, [2,4,6,8], zipWith(plus).apply(a, a))

exports.testZipWith2 = (T) ->
    a = values(1,2,3,4)
    resultEqual(T, [2,4,6,8], zipWith(plus, a).apply(a))

exports.testMapZipWith = (T) ->
    a = values(1,2,3,4)
    resultEqual(T, [3, 5, 7, 9], map(plusOne).zipWith(plus).apply(a,a))

exports.testFilterConcatmap = (T) ->
    a = values(1,2,3,4)
    resultEqual(T, [2,4,4,16], filter(isEven).concatMap(pair).apply(a))

exports.testTake = (T) ->
    a = values(1,2,3,4)
    resultEqual(T, [1,2], take(2) . apply(a))

exports.testDrop = (T) ->
    a = values(1,2,3,4)
    resultEqual(T, [3,4], drop(2) . apply(a))
