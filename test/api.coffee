# -*- tab-width: 4 -*-
{array, values, asPromised, iota, unfold, isStream} = require('../index')
{map, filter, drop, take, concatMap, zipWith} = require('../index')

resultEqual = (T, expected, s) ->
    T.ok(isStream(s))
    s.collect((res) -> T.deepEqual(expected, res); T.done())

plus = (a, b) -> a + b
plusOne = (n) -> n + 1
isEven = (n) -> n % 2 is 0
pair = (n) -> values(n, n*n)
nats = unfold(0, (-> false), ((n) -> n + 1))

promise = (s) ->
    {then: (cb) -> setTimeout((-> cb(s)), 0)}

# The basic stuff, using the objecty API

exports.testArrayConstructor = (T) ->
    vals = [1, 2, 3, 4]
    resultEqual(T, vals, array(vals))

exports.testValuesConstructor = (T) ->
    resultEqual(T, [1,2,3,4], values(1, 2, 3, 4))

exports.testPromiseConstructor = (T) ->
    resultEqual(T, [1,2,3,4], asPromised(promise(values(1,2,3,4))))

exports.testIota = (T) ->
    resultEqual(T, [1,2,3,4], iota(1, 1, 4))

exports.testUnfold = (T) ->
    resultEqual(T, [1,2,3,4], take(4, drop(1, nats)))

suite = (constructor) ->
    exports = {}
    exports.setUp = (cb) => @s = constructor(); cb()
    
    exports.testDotMap = (T) =>
        resultEqual(T, [2,3,4,5], @s.map(plusOne))

    exports.testDotFilter = (T) =>
        resultEqual(T, [2,4], @s.filter(isEven))

    exports.testDotTake = (T) =>
        resultEqual(T, [1,2,3], @s.take(3))

    exports.testDotDrop = (T) =>
        resultEqual(T, [4], @s.drop(3))

    exports.testDotFilterConcapMap = (T) =>
        resultEqual(T, [2,4, 4,16], @s.filter(isEven).concatMap(pair))

    exports.testDotConcatMap = (T) =>
        resultEqual(T, [1,1, 2,4, 3,9, 4,16], @s.concatMap(pair))

    exports.testDotZipWith2 = (T) =>
        resultEqual(T, [2,4,6,8], @s.zipWith(plus, @s))

# Using the compositional API

    exports.testMap = (T) =>
        resultEqual(T, [2,3,4,5], map(plusOne).apply(@s))

    exports.testFilter = (T) =>
        resultEqual(T, [2,4], filter(isEven).apply(@s))

    exports.testMapFilter = (T) =>
        resultEqual(T, [3,5], map(plusOne).filter(isEven).apply(@s))

    exports.testZipWith1 = (T) =>
        resultEqual(T, [2,4,6,8], zipWith(plus).apply(@s, @s))

    exports.testZipWith2 = (T) =>
        resultEqual(T, [2,4,6,8], zipWith(plus, @s).apply(@s))

    exports.testMapZipWith = (T) =>
        resultEqual(T, [3,5,7,9], map(plusOne).zipWith(plus).apply(@s,@s))

    exports.testFilterConcatmap = (T) =>
        resultEqual(T, [2,4,4,16], filter(isEven).concatMap(pair).apply(@s))

    exports.testTake = (T) =>
        resultEqual(T, [1,2], take(2) . apply(@s))

    exports.testDrop = (T) =>
        resultEqual(T, [3,4], drop(2) . apply(@s))

    exports

exports.values = suite(-> values(1,2,3,4))
exports.array = suite(-> array([1,2,3,4]))
exports.promise = suite(-> asPromised(promise(values(1,2,3,4))))
exports.iota = suite(-> iota(1, 1, 4))
exports.tail = suite(-> values(0, 1,2,3,4).drop(1))
