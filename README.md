# Lua-MoreMath
Emulates some basic features seen in R. Expands on the base math library for Lua and creates a new class called Vector (and BoolVector which inherits from Vector) with operator overloading features.

# API

| Function | Description | Input(s) : Type |
| -------- | ----------- | ----------- |
| math.forall | Applys tuple of numbers and tables as inputs for func. E.g. forall(math.noise, array1, 4, array2) | func : function, ... : <tuple: number, array> |
| math.vec | Constructs a new ordinal array of given numbers with Vector metatable | ... : <tuple: number> |
| math.vectorfy | Supplies an array of numbers with Vector metatable | array : array |
| math.range | Creates a new array [with Vector metatable] with values ranging from start to stop | start : number, stop : number, step : number |
| math.replicate | Create a new array of replicated, concatenated copies of array [with Vector metatable] | array : array, times : number |
| math.sum | Sums a tuple of numbers and arrays | ... : <tuple: number, array> |
| math.derivative | Returns derivative function, otherwise returns an array if subValues array supplied | continuousFunc : function, subValues : array, times : number |
| math.sample | Obtain a random sample from array with or without replacement | array : array, size : number, replace : boolean, probabilityTable : array |
| math.which | Gets the indexes of all true values. E.g. math.which(array("<", 0)) -> Outputs an array of indexes where their corresponding values were negative | boolVec : BoolVector |
| math.whichIsnt | Gets the indexes of all false values | boolVec : BoolVector |
| math.whichMax | Gets the index of the max value within array | array : array |
| math.whichMin | Gets the index of the min value within array | array : array |
| math.filterExcept | Gets the values which satisfy the internal statement. E.g. math.filterExcept(array(">=", 0)) -> Removes all negative values from array | boolVec : BoolVector |
| math.filter | Gets all values which do not satisfy the internal statement | boolVec : BoolVector |
| math.boolvec | Constructs a new ordinal array of given booleans with BoolVector metatable | ... : <tuple: boolean> |
| math.boolvectorfy | Supplies an array of booleans with BoolVector metatable | array : array |

Additionally, see MoreMath.lua for comments on what each metamethod does for Vector (and BoolVector) classes [below VECTOR METAMETHODS section]
