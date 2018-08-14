# Copyright 2017 Stephen L. Smith and Frank Imeson
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

## The items needed to adapt the powers in pdf_insert and pdf_remove
"""
A struct to store each insertion/deletion method using its power,
its weight, and its score on the last segment
"""
mutable struct Power
	name::String
	value::Float64
	weight::Dict{Symbol, Float64}
	scores::Dict{Symbol, Float64}
	count::Dict{Symbol, Int64}
end


""" initialize four noise values, none, low, med, and high """
function initialize_noise(weights, scores, count, noise)
	none = Power("additive", 0.0, Dict(:early => 1.0, :mid => 1.0, :late => 1.0),
				 copy(scores), copy(count))
	low = Power("additive", 0.25, Dict(:early => 1.0, :mid => 1.0, :late => 1.0),
				 copy(scores), copy(count))
	high = Power("additive", 0.75, Dict(:early => 1.0, :mid => 1.0, :late => 1.0),
				 copy(scores), copy(count))
 	sublow = Power("subset", 0.5, Dict(:early => 1.0, :mid => 1.0, :late => 1.0),
			 	 copy(scores), copy(count))
  	subhigh = Power("subset", 0.25, Dict(:early => 1.0, :mid => 1.0, :late => 1.0),
 			 	 copy(scores), copy(count))
	if noise == "None"
		noises = [none]
	elseif noise == "Add"
		noises = [none, low, high]
	elseif noise == "Subset"
		noises = [none, sublow, subhigh]
	else
		noises = [none, low, high, sublow, subhigh]
	end
	return noises
end


"""
initialize the insertion methods.  Use powers between -10 and 10
the spacing between weights is chosen so that when you increase the weight,
the probability of selecting something that is a given distance farther
is cut in half.
"""
function initialize_powers(param)
	weights = Dict(:early => 1.0, :mid => 1.0, :late => 1.0)
	scores = Dict(:early => 0, :mid => 0, :late => 0)
	count = Dict(:early => 0, :mid => 0, :late => 0)

	insertionpowers = Power[]
	for insertion in param[:insertions]
		if insertion == "cheapest"
			push!(insertionpowers, Power(insertion, 0.0, copy(weights), copy(scores),
				  copy(count)))
		else
			for value in param[:insertion_powers]
				push!(insertionpowers, Power(insertion, value, copy(weights), copy(scores),
					  copy(count)))
			end
		end
	end

	removalpowers = Power[]
	# use only positive powers for randworst -- -ve corresponds to "best removal"
	for removal in param[:removals]
		if removal == "segment"
			push!(removalpowers, Power(removal, 0.0, copy(weights), copy(scores),
										copy(count)))
		else
			for value in param[:removal_powers]
				if removal == "distance"
					value == 0.0 && continue  # equivalent to randworst with 0.0
					value *= -1.0  # for distance, we want to find closest vertices
				end
				push!(removalpowers, Power(removal, value, copy(weights), copy(scores),
											copy(count)))
			end
		end
	end

	noises = initialize_noise(weights, scores, count, param[:noise])
	# store the sum of insertion and deletion powers for roulette selection
	powers = Dict("insertions" => insertionpowers,
				  "removals" => removalpowers,
				  "noise" => noises,
				  "insertion_total" => total_power_weight(insertionpowers),
				  "removal_total" => total_power_weight(removalpowers),
  				  "noise_total" => total_power_weight(noises),
				  )
	return powers
end


"""
sums the weights for all the powers (i.e., the insertion or deletion methods)
"""
function total_power_weight(powers::Array{Power, 1})
	total_weight = Dict(:early => 0.0, :mid => 0.0, :late => 0.0)
	for phase in keys(total_weight)
		for i = 1:length(powers)
			total_weight[phase] += powers[i].weight[phase]
		end
	end
	return total_weight
end


"""
function takes in a set of bins and a weights array of the same length
and selects a bin with probability equal to weight
"""
function power_select(powers, total_weight, phase::Symbol)
	selection = rand()*total_weight[phase]
	for i = 1:length(powers)
		if selection < powers[i].weight[phase]
			return powers[i]
		end
		selection -= powers[i].weight[phase]
	end
	return powers[1]  # should never hit this case, but if you do, return first bin?
end


"""
Update both insertion and deletion powers along with the total weights
if we are a multiple of param[:adaptive_iter] iterations in trial
"""
function power_update!(powers, param::Dict{Symbol,Any})
	for phase in [:early, :mid, :late]
		power_weight_update!(powers["insertions"], param, phase)
		power_weight_update!(powers["removals"], param, phase)
		power_weight_update!(powers["noise"], param, phase)
	end
	powers["insertion_total"] = total_power_weight(powers["insertions"])
	powers["removal_total"] = total_power_weight(powers["removals"])
	powers["noise_total"] = total_power_weight(powers["noise"])
end


"""
Update only at the end of each trial -- update based on average success
over the trial
"""
function power_weight_update!(powers::Array{Power, 1}, param::Dict{Symbol,Any},
								phase::Symbol)
	for power in powers
		if power.count[phase] > 0 && param[:cold_trials] > 0  # average after 2nd trial
			power.weight[phase] = param[:epsilon] * power.scores[phase]/power.count[phase] +
									(1 - param[:epsilon]) * power.weight[phase]
		elseif power.count[phase] > 0
			power.weight[phase] = power.scores[phase]/power.count[phase]
		end
		power.scores[phase] = 0
		power.count[phase] = 0
	end
end
