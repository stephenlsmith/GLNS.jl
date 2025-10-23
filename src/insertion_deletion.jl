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

"""
Select a removal and an insertion method using powers, and then perform
removal followed by insertion on tour.  Operation done in place.
"""
function remove_insert(current::Tour, dist::Array{Int64,2}, member::Array{Int64,1},
                        setdist::Distsv, sets::Array{Any,1},
                        powers, param::Dict{Symbol,Any}, phase::Symbol)
	# make a new tour to perform the insertion and deletion on
    trial = Tour(copy(current.tour), current.cost)
	pivot_tour!(trial.tour)
	num_removals = rand(param[:min_removals]:param[:max_removals])

	removal = power_select(powers["removals"], powers["removal_total"], phase)
	if removal.name == "distance"
		sets_to_insert = distance_removal!(trial.tour, dist, num_removals,
													member, removal.value)
    elseif removal.name == "worst"
		sets_to_insert = worst_removal!(trial.tour, dist, num_removals,
													member, removal.value)
	else
		sets_to_insert = segment_removal!(trial.tour, num_removals, member)
	end

	randomize_sets!(sets, sets_to_insert)
	# then perform insertion
	insertion = power_select(powers["insertions"], powers["insertion_total"], phase)
	noise = power_select(powers["noise"], powers["noise_total"], phase)
	if insertion.name == "cheapest"
		cheapest_insertion!(trial.tour, sets_to_insert, dist, setdist, sets)
	else
		randpdf_insertion!(trial.tour, sets_to_insert, dist, setdist, sets,
							insertion.value, noise)
	end
	if rand() < param[:prob_reopt] 
		opt_cycle!(trial, dist, sets, member, param, setdist, "partial")
	else
		trial.cost = tour_cost(trial.tour, dist)
	end
	# update power scores for remove and insert
	score = (current.cost > 0) ? 100 * max(current.cost - trial.cost, 0) / current.cost : 0.0
	insertion.scores[phase] += score
	insertion.count[phase] += 1
	removal.scores[phase] += score
	removal.count[phase] += 1
	noise.scores[phase] += score
	noise.count[phase] += 1
	return trial
end


"""
Select an integer between 1 and num according to
and exponential distribution with lambda = power
# goes from left of array if power is positive
# and right of array if it is negative
"""
function select_k(num::Int64, power::Float64)
	base = (1/2)^abs(power)
	# (1 - base^num)/(1 - base) is sum of geometric series
	rand_select = (1 - base^num)/(1 - base) * rand()
	bin = 1
	@inbounds for k = 1:num
		if rand_select < bin
			return (power >= 0 ? (num - k + 1) : k)
		end
		rand_select -= bin
		bin *= base
	end
	return (power >=0 ? num : 1)
end


"""
selecting a random k in 1 to length(weights) according to power
and then selecting the kth smallest element in weights
"""
function pdf_select(weights::Array{Int64,1}, power::Float64)
    power == 0.0 && return rand(1:length(weights))
    power > 9.0 && return rand_select(weights, maximum(weights))
    power < - 9.0 && return rand_select(weights, minimum(weights))

	# select kth smallest.  If 1 or length(weights), simply return
	k = select_k(length(weights), power)
	k == 1 && return rand_select(weights, minimum(weights))
	k == length(weights) && return rand_select(weights, maximum(weights))
	val = partialsort(weights, k)

	return rand_select(weights, val)
end


"""  choose set with pdf_select, and then insert in best place with noise  """
function randpdf_insertion!(tour::Vector{Int}, sets_to_insert::Vector{Int},
							dist::Array{Int64, 2}, setdist::Distsv,
							sets::Array{Any, 1}, power::Float64, noise::Power)

    mindist = [typemax(Int64) for i=1:length(sets_to_insert)]
    @inbounds for i in eachindex(sets_to_insert)
        set = sets_to_insert[i]
        for vertex in tour
            if setdist.min_sv[set, vertex] < mindist[i]
                mindist[i] = setdist.min_sv[set, vertex]
            end
        end
    end
    new_vertex_in_tour = 0

    @inbounds while length(sets_to_insert) > 0
        if new_vertex_in_tour != 0
            for i in eachindex(sets_to_insert)
                set = sets_to_insert[i]
                if setdist.min_sv[set, new_vertex_in_tour] < mindist[i]
                    mindist[i] = setdist.min_sv[set, new_vertex_in_tour]
                end
            end
        end
        set_index = pdf_select(mindist, power) # select set to insert from pdf
        # find the closest vertex and the best insertion in that vertex
        nearest_set = sets_to_insert[set_index]
		if noise.name == "subset"
            bestv, bestpos = insert_subset_lb(tour, dist, sets[nearest_set], nearest_set,
											  setdist, noise.value)
		else
			bestv, bestpos =
					insert_lb(tour, dist, sets[nearest_set], nearest_set, setdist, noise.value)
		end
        insert!(tour, bestpos, bestv)  # perform the insertion
        new_vertex_in_tour = bestv
        # remove the inserted set from data structures
        splice!(sets_to_insert, set_index)
        splice!(mindist, set_index)
    end
end


function cheapest_insertion!(tour::Vector{Int}, sets_to_insert::Vector{Int},
	dist::Array{Int64, 2}, setdist::Distsv, sets::Array{Any, 1})
    """
	choose vertex that can be inserted most cheaply, and insert it in that position
	"""
	while length(sets_to_insert) > 0
        best_cost = typemax(Int64)
        best_v = 0
        best_pos = 0
        best_set = 0
        for i in eachindex(sets_to_insert)
            set_ind = sets_to_insert[i]
            # find the best place to insert the vertex
            best_v, best_pos, cost = insert_cost_lb(tour, dist, sets[set_ind], set_ind, setdist,
										  best_v, best_pos, best_cost)
			if cost < best_cost
				best_set = i
				best_cost = cost
			end
        end

        # now, perform the insertion
        insert!(tour, best_pos, best_v)
        # remove the inserted set from data structures
        splice!(sets_to_insert, best_set)
    end
end


"""
Given a tour and a set, this function finds the vertex in the set with minimum
insertion cost, along with the position of this insertion in the tour.  If
best_position is i, then vertex should be inserted between tour[i-1] and tour[i].
"""
@inline function insert_lb(tour::Vector{Int}, dist::Array{Int64,2}, set::Array{Int64, 1},
							setind::Int, setdist::Distsv, noise::Float64)
	best_cost = typemax(Int64)
	bestv = 0
	bestpos = 0

    @inbounds for i in eachindex(tour)
		v1 = prev_tour(tour, i)
		lb = setdist.vert_set[v1, setind] + setdist.set_vert[setind, tour[i]] - dist[v1, tour[i]]
		lb > best_cost && continue

		for v in set
	        insert_cost = dist[v1, v] + dist[v, tour[i]] - dist[v1, tour[i]]
			noise > 0.0 && (insert_cost += round(Int64, noise * rand() * abs(insert_cost)))
			if insert_cost < best_cost
				best_cost = insert_cost
				bestv = v
				bestpos = i
	        end
		end
    end
    return bestv, bestpos
end


@inline function insert_subset_lb(tour::Vector{Int}, dist::Array{Int64,2}, set::Array{Int64, 1},
							setind::Int, setdist::Distsv, noise::Float64)
	best_cost = typemax(Int64)
	bestv = 0
	bestpos = 0
	tour_inds = collect(1:length(tour))

	@inbounds for i = 1:ceil(Int64, length(tour) * noise)
		i = incremental_shuffle!(tour_inds, i)
		v1 = prev_tour(tour, i)
		lb = setdist.vert_set[v1, setind] + setdist.set_vert[setind, tour[i]] - dist[v1, tour[i]]
		lb > best_cost && continue

		for v in set
	        insert_cost = dist[v1, v] + dist[v, tour[i]] - dist[v1, tour[i]]
	        if insert_cost < best_cost
				best_cost = insert_cost
				bestv = v
				bestpos = i
	        end
		end
    end
    return bestv, bestpos
end


############ Initial Tour Construction ##########################

"""build tour from scratch on a cold restart"""
function initial_tour!(lowest::Tour, dist::Array{Int64, 2}, sets::Array{Any, 1},
						setdist::Distsv, trial_num::Int64, param::Dict{Symbol,Any})
	sets_to_insert = collect(1:param[:num_sets])
	best = Tour(Int64[], typemax(Int64))

	# compute random initial tour only if past first trial
	# in this case, randomly choose between random and insertion tour.
	if param[:init_tour] == "rand" && (trial_num > 1) && (rand() < 0.5)
		random_initial_tour!(best.tour, sets_to_insert, dist, sets)
	else
		random_insertion!(best.tour, sets_to_insert, dist, sets, setdist)
	end
	best.cost = tour_cost(best.tour, dist)
	if lowest.cost > best.cost 
		lowest.cost = best.cost
		lowest.tour = best.tour
	end
	return best
end


"""
Randomly shuffle the sets, and then insert the best vertex from each set back into
the tour where sets are considered in shuffled order.
"""
function random_insertion!(tour::Vector{Int}, sets_to_insert::Vector{Int},
						   dist::Array{Int64, 2}, sets::Array{Any, 1}, setdist::Distsv)
    shuffle!(sets_to_insert)  # randomly permute the sets
    for set in sets_to_insert
        # only have to compute the insert cost for the changed portion of the tour
        if isempty(tour)
            best_vertex = rand(sets[set])
            best_position = 1
        else
            best_vertex, best_position = insert_lb(tour, dist, sets[set], set, setdist, 0.75)
        end
        # now, perform the insertion
        insert!(tour, best_position, best_vertex)
    end
end


"""
Randomly shuffle the sets, and then insert the best vertex from each set back into
the tour where sets are considered in shuffled order.
"""
function random_initial_tour!(tour::Vector{Int}, sets_to_insert::Vector{Int},
							  dist::Array{Int64, 2}, sets::Array{Any, 1})
    shuffle!(sets_to_insert)
    for set in sets_to_insert
		push!(tour, rand(sets[set]))
    end
end


######################### Removals ################################
"""
Remove the vertices randomly, but biased towards those that add the most length to the
tour.  Bias is based on the power input.  Vertices are then selected via pdf select.
"""
function worst_removal!(tour::Vector{Int}, dist::Array{Int64, 2},
							num_to_remove::Int64, member::Array{Int64,1}, power::Float64)
    deleted_sets = Int[]
	while length(deleted_sets) < num_to_remove
		removal_costs = worst_vertices(tour, dist)
		ind = pdf_select(removal_costs, power)
		set_to_delete = member[tour[ind]]

        # perform the deletion
        push!(deleted_sets, set_to_delete)
		splice!(tour, ind)
	end
    return deleted_sets
end


""" removing a single continuous segment of the tour of size num_remove """
function segment_removal!(tour::Vector{Int}, num_to_remove::Int64, member::Array{Int64,1})
	i = rand(1:length(tour))
    deleted_sets = Int[]
	while length(deleted_sets) < num_to_remove
		i > length(tour) && (i = 1)
		push!(deleted_sets, member[tour[i]])
		splice!(tour, i)
	end
	return deleted_sets
end


"""  pick a random vertex, and delete its closest neighbors  """
function distance_removal!(tour::Vector{Int}, dist::Array{Int64, 2},
							   num_to_remove::Int64, member::Array{Int64,1}, power::Float64)
    deleted_sets = Int[]
    deleted_vertices = Int[]

    seed_index = rand(1:length(tour))
    push!(deleted_sets, member[tour[seed_index]])
    push!(deleted_vertices, tour[seed_index])
    splice!(tour, seed_index)

    # preallocate distance workspace to avoid repeated allocations
    mindist = Vector{Int64}(undef, length(tour))

    while length(deleted_sets) < num_to_remove
        # pick a random vertex from the set of deleted vertices
        seed_vertex = rand(deleted_vertices)
        # find closest vertex to the seed vertex that's still in the tour
        resize!(mindist, length(tour))
        for i in eachindex(tour)
			mindist[i] = min(dist[seed_vertex, tour[i]], dist[tour[i], seed_vertex])
        end
        del_index = pdf_select(mindist, power)
        push!(deleted_sets, member[tour[del_index]])
        push!(deleted_vertices, tour[del_index])
        splice!(tour, del_index)
    end

    return deleted_sets
end


"""
determine the cost of removing each vertex from the tour, given that all others remain.
"""
function worst_vertices(tour::Vector{Int}, dist::Array{Int64, 2})
    removal_cost = zeros(Int64, length(tour))
    @inbounds for i in eachindex(tour)
        if i == 1
            removal_cost[i] = dist[tour[end], tour[i]] +
								dist[tour[i], tour[i+1]] - dist[tour[end], tour[i+1]]
        elseif i == length(tour)
            removal_cost[i] = dist[tour[i-1], tour[i]] +
								dist[tour[i], tour[1]] - dist[tour[i-1], tour[1]]
        else
            removal_cost[i] = dist[tour[i-1], tour[i]] +
								dist[tour[i], tour[i+1]] - dist[tour[i-1], tour[i+1]]
		end
    end
    return removal_cost
end
