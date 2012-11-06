# -*- tab-width: 4 -*-
{array, values, isStream, asPromised} = require('../index')

resultEqual = (T, expected, s) ->
    T.ok(isStream(s))
    s.collect((res) -> T.deepEqual(expected, res); T.done())

exports.testArray = (T) ->
    vals = [1, 2, 3, 4]
    resultEqual(T, vals, array(vals))

exports.testValues = (T) ->
    resultEqual(T, [1,2,3,4], values(1, 2, 3, 4))

exports.testMap = (T) ->
    a = values(1, 2, 3, 4)
    resultEqual(T, [2,3,4,5], a.map((n) -> n + 1))

exports.testFilter = (T) ->
    a = values(1,2,3,4,5)
    resultEqual(T, [2,4], a.filter((n) -> n % 2 == 0))

exports.testTake = (T) ->
    a = values(1,2,3,4,5)
    resultEqual(T, [1,2,3], a.take(3))

exports.testDrop = (T) ->
    a = values(1,2,3,4,5)
    resultEqual(T, [4,5], a.drop(3))

exports.testConcatMap = (T) ->
    a = values(1,2,3)
    b = a.concatMap((n) -> values(n, n*n))
    resultEqual(T, [1,1, 2,4, 3,9], b)

exports.testZipWith = (T) ->
    a = values(1,2,3,4)
    resultEqual(T, [2,4,6,8], a.zipWith(((a, b) -> a + b), a))
