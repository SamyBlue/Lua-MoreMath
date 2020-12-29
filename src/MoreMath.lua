--[[
			Expanded Math Library, https://github.com/SamyBlue/Lua-MoreMath
									
+ Equips ordinal arrays with metatables to allow for more flexible use in equations and Vector-like behavior
+ Ensure only ordinal arrays are used and that they are all of the same datatype
+ math.vectorfy() is important for setting a metatable on your array which allows for addition, subtraction, etc.

+ See: https://github.com/SamyBlue/Lua-MoreMath/blob/main/README.md for partial documentation

e.g. can do stuff like math.sin(2*array)^3.7  -  4*array2  +  array3  +  math.noise(array1, array2, 7.4)  +  1
or array[array(">", 0):And(array("<", 5.6))] = 10    ->    sets all values between 0 and 5.6 in array to 10
--]]

local function assertwarn(requirement: boolean, messageIfNotMet: string)
	if requirement == false then
		warn(messageIfNotMet)
	end
end

local function InheritAfromB(A, B) --Pass all of B's methods and metamethods to A (without replacing existing metamethods)
	if rawget(A, B) == true then
		return A
	end
	for k, v in pairs(B) do
		if rawget(A, k) == nil then
			rawset(A, k, v)
		end
	end
	rawset(A, B, true)
	return A
end

local function shallowCopyArray(array)
	local copy = {}

	for i = 1, #array do
		copy[i] = array[i]
	end

	return copy
end

local Vector = {__type = "vector"};  --Allows for flexible use in equations
local BoolVector = {__type = "boolvector"}; --Used in element-based comparisons. Inherits from Vector

-----------------------------------------------------------
-------------------- MATH FUNCTIONS -----------------------
-----------------------------------------------------------

--Note: forall works on tables without the Vector metatable. All input tables must be the same length
local function forall(func, ...) --Applys tuple of numbers and tables as inputs for func. E.g. forall(math.noise, array1, 4, array2)
	local output = {}
	local funcInputs = {...}
	local tableIndexes, tableValues = {}, {}

	for i, v in ipairs(funcInputs) do
		if type(v) == 'table' then
			local curr = #tableIndexes + 1
			tableIndexes[curr], tableValues[curr] = i, v
			assert(curr == 1 or #tableValues[curr - 1] == #v, "forall: Tables of different lengths not accepted.")
		end
	end

	if #tableIndexes == 0 then
		return func(...)
	end

	for i, v in ipairs(tableValues[1]) do
		for j = 1, #tableIndexes do
			funcInputs[tableIndexes[j]] = tableValues[j][i]
		end
		output[i] = func(unpack(funcInputs))
	end
	return setmetatable(output, Vector) --will be type: table if input contains a table, number otherwise
end

local function Enable_forall_ForLibrary(lib)
	local new = {}
	setmetatable(new, {
		__index = function(s, i)
			assert(lib[i] ~= nil, i .." doesn't exist in math")
			local result = function (...)
				return forall(lib[i], ...)
			end
			rawset(new, i, result)
			return result
		end,
		__newindex = function(s, i, v)
			rawset(new, i, v)
		end
	})
	return new
end

local math = Enable_forall_ForLibrary(math) --Makes all Lua math functions work with forall by default without needing to use math.forall()
math.forall = forall --See forall function definition above

math.vec = function (...) --Constructs a new ordinal array of given numbers with Vector metatable
	return setmetatable({...}, Vector)
end

math.vectorfy = function (array) --Supplies an array of numbers with Vector metatable
	return setmetatable(array, Vector)
end

math.range = function (start, stop, step) --Creates a new array with values ranging from start to stop
	step = step or 1
	start, stop = (stop ~= nil) and start or 1, stop or start --Allows you to do math.range(n) shorthand to define values 1 to n
	local newArr = {}
	for i = start, stop, step do
		newArr[#newArr + 1] = i
	end
	return math.vectorfy(newArr)
end

math.replicate = function (array, times) --Create a new array of replicated, concatenated copies of array [with Vector metatable]
	--[[
		Example usage:
		math.replicate({1, 4, 5}, 3) -> {1, 4, 5, 1, 4, 5, 1, 4, 5}
	--]]
	times = math.floor(times)
	local newArr = {}
	
	for i = 1, times do
		for _, v in ipairs(array) do
			newArr[#newArr + 1] = v
		end
	end
	return math.vectorfy(newArr)
end

math.sum = function (...) --Sums a tuple of numbers and arrays
	local total = 0
	for _, v in ipairs({...}) do
		if type(v) == 'table' then
			for _, number in ipairs(v) do
				total += number
			end
		else
			total += v
		end
	end
	return total
end

math.derivative = function (continuousFunc, subValues, times) --Returns new function, otherwise returns an array if subValues array supplied
	times = times or 1
	local h = 0.001
	
	local derivFunc = function (x)
		return 0.5 * (continuousFunc(x + h) - continuousFunc(x - h)) / h
	end
	
	if times > 1 then
		return math.derivative(derivFunc, subValues, times - 1) --some accuracy loss with repeat differentiation
	elseif subValues then
		return math.forall(derivFunc, subValues)
	end
	return derivFunc
end

local random = Random.new()

math.sample = function (array, size, replace: boolean, probabilityTable) --Obtain a random sample from array
	--[[
		size governs the size of the random sample
		replace governs if you want to be able to pick values again even if they've been picked already
		probabilityTable is an array of chance values (between 0 and 1) which should add up to 1
		you can use the probabilityTable to create higher chances of picking certain values in array
	--]]
	replace = replace == nil and true or replace
	local newArr = {}
	local size = size ~= nil and math.floor(size) or #array
	local probabilityTable = probabilityTable or math.replicate({1 / size}, size)
	assertwarn(math.abs(1 - math.sum(probabilityTable)) < 1e-6 and #probabilityTable == #array, 
		"sample: Improper probability table passed -> Some values may have 0 chance of being picked or function will error.")

	local cumulative = {}
	cumulative[1] = probabilityTable[1]

	for i = 2, #probabilityTable do
		cumulative[i] = cumulative[i - 1] + probabilityTable[i]
	end

	if replace then
		
		for i = 1, size do
			local rng = random:NextNumber()
			local chosenIndex
			for j, v in ipairs(cumulative) do
				if rng < v then
					chosenIndex = j
					break
				end
			end
			newArr[i] = array[chosenIndex]
		end
		
	else
		
		size = math.min(#array, size)
		local copy = shallowCopyArray(probabilityTable) --slow implementation -> Update with better algo below
		for i = 1, size do --Want to use reservoir sampling methods in future
			local rng = math.random()
			local chosenIndex

			for j, v in pairs(cumulative) do
				if rng < v and copy[j] > 0 then
					chosenIndex = j
					local total, weightSum = 0, 1 - copy[j]
					copy[j] = nil
					cumulative[j] = nil
					for k, w in pairs(copy) do
						local newV = w / weightSum
						copy[k] = newV
						total += newV
						cumulative[k] = total
					end
					break
				end
			end
			--print(concat(copy), "i == ", i, chosenIndex)
			if chosenIndex then
				newArr[i] = array[chosenIndex]
			end
		end
		
	end
	return math.vectorfy(newArr)
end

math.which = function (boolVec) --Gets the indexes of all true values
	--Example usage: math.which(array("<", 0)) -> Outputs an array of indexes where their corresponding values were negative
	--Remember that using the __call metamethod on array requires the Vector metatable -> Use math.vectorfy(array)
	local newArr = {}
	for i, v in ipairs(boolVec) do
		if v then
			newArr[#newArr + 1] = i
		end
	end
	return math.vectorfy(newArr)
end

math.whichIsnt = function (boolVec) --Gets the indexes of all false values
	local newArr = {}
	for i, v in ipairs(boolVec) do
		if not v then
			newArr[#newArr + 1] = i
		end
	end
	return math.vectorfy(newArr)
end

math.whichMax = function (array) --Gets the index of the max value within array
	local max, maxIndex = -math.huge, 0
	for i, v in ipairs(array) do
		if v > max then
			max, maxIndex = v, i
		end
	end
	return maxIndex
end

math.whichMin = function (array) --Gets the index of the min value within array
	local min, minIndex = math.huge, 0
	for i, v in ipairs(array) do
		if v < min then
			min, minIndex = v, i
		end
	end
	return minIndex
end

math.filterExcept = function (boolVec) --Gets the values which satisfy the internal statement
	--[[
		Example usage: math.filterExcept(array(">=", 0)) -> Removes all negative values from array
		Alt. notation: array[array(">=", 0)]
		
		NOTE: ORDER IS IMPORTANT HERE
		i.e. Both internal statements below are the same but give different results:
		math.filterExcept(array1(">", array2)) -> Gets all values in array1 which are greater than values of the same index in array2
		math.filterExcept(array2("<", array1)) -> Gets all values in array2 which are less than values of the same index in array1
	--]]
	assert(boolVec.FromVector ~= nil, "filterExcept: Unable to interpret internal statement.")
	return boolVec.FromVector[math.which(boolVec)] --I know this entire function was a bit pointless but I really wanted it :(
end

math.filter = function (boolVec) --Gets all values which do not satisfy the internal statement
	assert(boolVec.FromVector ~= nil, "filter: Unable to interpret internal statement.")
	return boolVec.FromVector[math.whichisnt(boolVec)]
end

math.boolvec = function (...) --Constructs a new ordinal array of given booleans with BoolVector metatable
	return setmetatable({...}, BoolVector)
end

math.boolvectorfy = function (array) --Supplies an array of booleans with BoolVector metatable
	return setmetatable(array, BoolVector)
end

-----------------------------------------------------------
-------------------- VECTOR METAMETHODS -------------------
-----------------------------------------------------------

function Vector.__index(array, index) --Returns array of values indexed by elements of the table: index
	if type(index) == 'table' then
		if index.__type == "boolvector" then
			return math.filterExcept(index)
		else
			local newArr = {}
			for i, v in ipairs(index) do
				newArr[i] = array[v]
			end
			return math.vectorfy(newArr)
		end
	end
	return Vector[index]
end

function BoolVector.__index(array, index) --Returns array of values indexed by elements of the table: index
	if type(index) == 'table' then
		if index.__type == "boolvector" then
			return math.filterExcept(index)
		else
			local newArr = {}
			for i, v in ipairs(index) do
				newArr[i] = array[v]
			end
			return math.boolvectorfy(newArr)
		end
	end
	return BoolVector[index]
end

function Vector.__newindex(array, index, value) --Assign elements of the array via the table: index to a single value or an array of values
	--Can do stuff like array[array(">", 0):And(array("<", 5.6))] = 10  ->  all values between 0 and 5.6 set to 10
	
	if type(index) == 'table' then
		local isTable = type(value) == 'table'
		index = index.__type == "boolvector" and math.which(index) or index
		for i, v in ipairs(index) do
			array[v] = isTable and value[i] or value
		end
		return
	end
	rawset(array, index, value)
end

function Vector.__call(array, operator, compareTo) --Returns array of booleans by comparing with compareTo based on a given relational operator
	local newArr = {}
	assertwarn(compareTo ~= nil, "call: Table compared with nil")
	local isTable = type(compareTo) == 'table'
	assertwarn(not isTable or #array == #compareTo, "call: Table compared with different length table")
	
	if operator == "==" then
		for i, v in ipairs(array) do
			newArr[i] = v == (isTable and compareTo[i] or compareTo)
		end
	elseif operator == "~=" then
		for i, v in ipairs(array) do
			newArr[i] = v ~= (isTable and compareTo[i] or compareTo)
		end
	elseif operator == "<" then
		for i, v in ipairs(array) do
			newArr[i] = v < (isTable and compareTo[i] or compareTo)
		end
	elseif operator == ">=" then
		for i, v in ipairs(array) do
			newArr[i] = v >= (isTable and compareTo[i] or compareTo)
		end
	elseif operator == "<=" then
		for i, v in ipairs(array) do
			newArr[i] = v <= (isTable and compareTo[i] or compareTo)
		end
	elseif operator == ">" then
		for i, v in ipairs(array) do
			newArr[i] = v > (isTable and compareTo[i] or compareTo)
		end
	else
		error("call: Unknown operator used")
	end
	
	newArr.FromVector = array --for use in the math.filter() function
	
	return math.boolvectorfy(newArr)
end

function Vector.__concat(array, value) --Appends array with either value or another array
	local newArr = {}
	if type(array) == 'table' and type(value) == 'table' then
		for i = 1, #array + #value do
			newArr[i] = i <= #array and array[i] or value[i - #array]
		end
	elseif type(array) == 'table' then
		for i = 1, #array do
			newArr[i] = array[i]
		end
		newArr[#newArr + 1] = value
	else
		newArr[1] = array
		for i = 1, #value do
			newArr[#newArr + 1] = value[i]
		end
	end
	return array.__type == "vector" and math.vectorfy(newArr) or math.boolvectorfy(newArr)
end

function Vector.__unm(array) --Allows negation of array in equations
	local newArr = {}
	for i, v in ipairs(array) do
		newArr[i] = -v
	end
	return math.vectorfy(newArr)
end

function Vector.__add(array, value) --Allows addition of single values with each element Or addition of two arrays
	local newArr = {}
	if type(array) == 'table' and type(value) == 'table' then
		assertwarn(#array == #value, "add: Addition of tables was performed with different table lengths.")
		if #array > #value then
			for i, v in ipairs(array) do
				newArr[i] = v + (value[i] or 0)
			end
		else
			for i, v in ipairs(value) do
				newArr[i] = (array[i] or 0) + v
			end
		end
	elseif type(value) == 'number' then
		for i, v in ipairs(array) do
			newArr[i] = v + value
		end
	elseif type(array) == 'number' then
		for i, v in ipairs(value) do
			newArr[i] = array + v
		end
	else
		error("add: Cannot add " ..type(array) .." with " ..type(value))
	end
	return math.vectorfy(newArr)
end

function Vector.__sub(array, value) --Allows subtraction of single values from each element Or subtraction of two arrays
	local newArr = {}
	if type(array) == 'table' and type(value) == 'table' then
		assertwarn(#array == #value, "sub: Subtraction of tables was performed with different table lengths.")
		if #array > #value then
			for i, v in ipairs(array) do
				newArr[i] = v - (value[i] or 0)
			end
		else
			for i, v in ipairs(value) do
				newArr[i] = (array[i] or 0) - v
			end
		end
	elseif type(value) == 'number' then
		for i, v in ipairs(array) do
			newArr[i] = v - value
		end
	elseif type(array) == 'number' then
		for i, v in ipairs(value) do
			newArr[i] = array - v
		end
	else
		error("sub: Cannot subtract " ..type(array) .." with " ..type(value))
	end
	return math.vectorfy(newArr)
end

function Vector.__mul(array, value) --Allows multiplication of single values with each element Or multiplication of two arrays
	local newArr = {}
	if type(array) == 'table' and type(value) == 'table' then
		assertwarn(#array == #value, "mul: Multiplication of tables was performed with different table lengths.")
		if #array > #value then
			for i, v in ipairs(array) do
				newArr[i] = v * (value[i] or 1)
			end
		else
			for i, v in ipairs(value) do
				newArr[i] = (array[i] or 1) * v
			end
		end
	elseif type(value) == 'number' then
		for i, v in ipairs(array) do
			newArr[i] = v * value
		end
	elseif type(array) == 'number' then
		for i, v in ipairs(value) do
			newArr[i] = array * v
		end
	else
		error("mul: Cannot multiply " ..type(array) .." with " ..type(value))
	end
	return math.vectorfy(newArr)
end

function Vector.__div(array, value) --Allows division of single values with each element Or division of two arrays
	local newArr = {}
	if type(array) == 'table' and type(value) == 'table' then
		assertwarn(#array == #value, "div: Division of tables was performed with different table lengths.")
		if #array > #value then
			for i, v in ipairs(array) do
				newArr[i] = v / (value[i] or 1)
			end
		else
			for i, v in ipairs(value) do
				newArr[i] = (array[i] or 0) / v
			end
		end
	elseif type(value) == 'number' then
		for i, v in ipairs(array) do
			newArr[i] = v / value
		end
	elseif type(array) == 'number' then
		for i, v in ipairs(value) do
			newArr[i] = array / v
		end
	else
		error("div: Cannot divide " ..type(array) .." with " ..type(value))
	end
	return math.vectorfy(newArr)
end

function Vector.__mod(array, value) --Allows modulus of single values with each element Or modulus of two arrays
	local newArr = {}
	if type(array) == 'table' and type(value) == 'table' then
		assertwarn(#array == #value, "mod: Modulus of tables was performed with different table lengths.")
		if #array > #value then
			for i, v in ipairs(array) do
				newArr[i] = v % (value[i] or 1)
			end
		else
			for i, v in ipairs(value) do
				newArr[i] = (array[i] or 0) % v
			end
		end
	elseif type(value) == 'number' then
		for i, v in ipairs(array) do
			newArr[i] = v % value
		end
	elseif type(array) == 'number' then
		for i, v in ipairs(value) do
			newArr[i] = array % v
		end
	else
		error("mod: Cannot modulus " ..type(array) .." with " ..type(value))
	end
	return math.vectorfy(newArr)
end

function Vector.__pow(array, value) --Allows exponentiation of single values from each element Or exponentiation of two arrays
	local newArr = {}
	if type(array) == 'table' and type(value) == 'table' then
		assertwarn(#array == #value, "pow: Exponentiation of tables was performed with different table lengths.")
		if #array > #value then
			for i, v in ipairs(array) do
				newArr[i] = v ^ (value[i] or 0)
			end
		else
			for i, v in ipairs(value) do
				newArr[i] = (array[i] or 1) ^ v
			end
		end
	elseif type(value) == 'number' then
		for i, v in ipairs(array) do
			newArr[i] = v ^ value
		end
	elseif type(array) == 'number' then
		for i, v in ipairs(value) do
			newArr[i] = array ^ v
		end
	else
		error("pow: Cannot perform exponentiation with " ..type(array) .." and " ..type(value))
	end
	return math.vectorfy(newArr)
end

function Vector.__tostring(array)
	return table.concat(array, ", ")
end

function BoolVector.__tostring(array)
	local str = ""
	for i = 1, #array do
		str = str ..(array[i] and "true, " or "false, ")
	end
	return str:sub(1, #str - 2)
end

--I chose to not do the below methods with __eq, __lt, __le metamethods to allow for single-value comparisons
--And to ensure you could still check if two tables (vectors) do not have the same table address

function Vector:AllEquals(value) --Tests for element-wise equality
	local isTable = type(value) == 'table'
	
	if isTable and #self ~= #value then
		return false
	end

	for i, v in ipairs(self) do
		if v ~= (isTable and value[i] or value) then
			return false
		end
	end
	return true
end

function Vector:AllLessThan(value) --Tests if each element is less than corresponding value(s)
	local isTable = type(value) == 'table'

	if isTable and #self ~= #value then
		return false
	end

	for i, v in ipairs(self) do
		if v >= (isTable and value[i] or value) then
			return false
		end
	end
	return true
end

function Vector:AllLessThanOrEqual(value) --Tests if each element is less than or equal to corresponding value(s)
	local isTable = type(value) == 'table'

	if isTable and #self ~= #value then
		return false
	end

	for i, v in ipairs(self) do
		if v > (isTable and value[i] or value) then
			return false
		end
	end
	return true
end

function Vector:NotAllEquals(value)
	return not Vector:AllEquals(value)
end

function Vector:AllMoreThanOrEqual(value)
	return not Vector:AllLessThan(value)
end

function Vector:AllMoreThan(value)
	return not Vector:AllLessThanOrEqual(value)
end

function BoolVector.__unm(array) --Applies a logical NOT to all elements
	local newArr = {}
	for i, v in ipairs(array) do
		newArr[i] = not v
	end
	newArr.FromVector = array.FromVector --for use in the math.filter() function
	return math.boolvectorfy(newArr)
end

function BoolVector.__add(array, value) --Applies a logical OR between elements of the same index
	local newArr = {}
	if type(array) == 'table' and type(value) == 'table' then
		assertwarn(#array == #value, "add: Logical OR was performed between different table lengths.")
		if #array > #value then
			for i, v in ipairs(array) do
				newArr[i] = value[i] or v
			end
		else
			for i, v in ipairs(value) do
				newArr[i] = array[i] or v
			end
		end
	elseif type(value) == 'boolean' then
		for i, v in ipairs(array) do
			newArr[i] = v or value
		end
	elseif type(array) == 'boolean' then
		for i, v in ipairs(value) do
			newArr[i] = array or v
		end
	else
		error("add: Cannot perform logical OR between " ..type(array) .." and " ..type(value))
	end
	newArr.FromVector = array.FromVector --for use in the math.filter() function
	return math.boolvectorfy(newArr)
end

function BoolVector.__mul(array, value) --Applies a logical AND between elements of the same index
	local newArr = {}
	if type(array) == 'table' and type(value) == 'table' then
		assertwarn(#array == #value, "mul: Logical AND was performed between different table lengths.")
		if #array > #value then
			for i, v in ipairs(array) do
				newArr[i] = (value[i] or false) and v --handles when value[i] == nil
			end
		else
			for i, v in ipairs(value) do
				newArr[i] = (array[i] or false) and v
			end
		end
	elseif type(value) == 'boolean' then
		for i, v in ipairs(array) do
			newArr[i] = v and value
		end
	elseif type(array) == 'boolean' then
		for i, v in ipairs(value) do
			newArr[i] = array and v
		end
	else
		error("mul: Cannot perform logical AND between " ..type(array) .." and " ..type(value))
	end
	newArr.FromVector = array.FromVector --for use in the math.filter() function
	return math.boolvectorfy(newArr)
end

function BoolVector:Negate() --More readable option (but more parentheses cluster)
	return -BoolVector
end

function BoolVector:Or(array) --More readable option (but more parentheses cluster)
	return BoolVector + array
end

function BoolVector:And(array) --More readable option (but more parentheses cluster)
	return BoolVector * array
end

function Vector:Between(start, stop, step) --Returns array between start and stop indexes
	step = step or 1
	start, stop = (stop ~= nil) and start or 1, stop or start --Allows you to do array:Between(n) shorthand to get indexes 1 to n
	local newArr = {}
	for i = start, stop, step do
		newArr[#newArr + 1] = self[i]
	end
	return math.vectorfy(newArr)
end

InheritAfromB(BoolVector, Vector) --must go at end of module

return math
