--Basic package mainly motivated by wanting to create the math.guessPattern() function at the end

local math = require(script.MoreMath)

local function shallowCopyArray(array)
	local copy = {}

	for i = 1, #array do
		copy[i] = array[i]
	end

	return copy
end

math.mean = function (array) --Outputs mean average value
	assert(#array > 0, "mean: Empty array passed")
	return math.sum(array) / #array
end

math.E = math.mean

math.variance = function (X) --Outputs sample variance value
	return (math.E(X^2) - math.E(X)^2)*#X / (#X - 1)
end

math.diff = function(X, count)
	if not count or count <= 1 then
		return X[math.range(#X)+1] - X[math.range(#X - 1)]
	else
		return math.diff(X[math.range(#X)+1] - X[math.range(#X - 1)], count - 1)
	end
end

math.ACF = function (X) --Outputs autocorrelation function
  
	local N = #X
	local Mean = math.mean(X)
	local MyACF = math.range(N)


	for k = 0, N-1 do 
		local Sum = 0
		for t = k+1, N do
			Sum = Sum + (X[t] - Mean)*(X[t-k] - Mean)
		end

		MyACF[k+1] = Sum/(N-0.5*k) --Custom bias
	end

	return (MyACF / math.variance(X))
end

math.median = function (array) --Outputs median value
	local arrLength = #array
	local temp = shallowCopyArray(array)
	table.sort(temp)

	if arrLength % 2 == 0 then
		return (temp[arrLength / 2] + temp[arrLength / 2 + 1]) / 2
	else
		return temp[math.ceil(arrLength / 2)]
	end
end

math.estimateSeasonality = function (X) --Estimates seasonality: https://en.wikipedia.org/wiki/Seasonality
	local ac = math.ACF(X)
	local pksArgs = math.which(math.diff(math.sign(math.diff(ac)))("<", 0)) --Find all crests
	local pksArgs = pksArgs[math.which(ac[pksArgs+1](">", 0))] --Remove negative crests (want lags with positive correlation)
	
	local firstPk = pksArgs[1] --Want to pick smallest periodicity that works
	if firstPk == nil then
		print("estimateSeasonality: No pattern of seasonality found")
		return 0
	end
	
	return firstPk
end

math.linearRegression = function (X, Y) --Outputs constants of a linear regression on X, Y
	--Formula: https://en.wikipedia.org/wiki/Simple_linear_regression
	local xMean, yMean = math.mean(X), math.mean(Y)
	local denominator = math.sum((X - xMean)^2)
	local beta = denominator ~= 0 and math.sum((X - xMean)*(Y - yMean)) / denominator or 0
	local alpha = yMean - beta*xMean
	return alpha, beta --y = alpha + beta*x
end

math.guessPattern = function (Y, extraValues) --Attempts to model seasonality in the data with linear regression
	--This is quite limited in practice but is fun to try on regularly repeating chunks of data [with constant periodicity]
	local extraValues = math.floor(extraValues)
	assert(extraValues > 0, "GuessPattern: extraValues should be at least 1")
	local X = math.range(#Y)
	local lineConst1, lineConst2 = math.linearRegression(X, Y)
	local UnderlyingLine = lineConst1 + lineConst2*X
	local Y_ = Y - UnderlyingLine
	
	local period = math.estimateSeasonality(Y_)
	if period == 0 then
		return Y ..(lineConst1 + lineConst2*math.range(#Y + 1, #Y + extraValues))
	end
	
	local regressedPart = math.vec()
	
	for i = 1, period do
		local currX = math.range(i, #Y, period)
		local currY = Y_[currX]
		--local a0, a1 = math.linearRegression(currX, currY)
		local m = math.mean(currY)
		for j = i, #Y + extraValues, period do
			regressedPart[j] = m --a0 + a1*j
		end
	end
	
	return regressedPart + lineConst1 + lineConst2*math.range(#Y + extraValues)
end

return math