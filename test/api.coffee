# -*- tab-width: 4 -*-
{array, isStream, asPromised} = require('../index')

exports.testArray = (T) ->
    vals = [1, 2, 3, 4]
    a = array(vals)
    a.collect((res) -> T.deepEqual(vals, res); T.done())
