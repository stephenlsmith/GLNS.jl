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
module GLNS
export solver
using Random
include("src/utilities.jl")
include("src/parse_print.jl")
include("src/tour_optimizations.jl")
include("src/adaptive_powers.jl")
include("src/insertion_deletion.jl")
include("src/parameter_defaults.jl")

"""
Main GTSP solver, which takes as input a problem instance and
some optional arguments
"""
function solver(problem_instance; args...)
	###### Read problem data and solver settings ########
	num_vertices, num_sets, sets, dist, membership = read_file(problem_instance)
	param = parameter_settings(num_vertices, num_sets, sets, problem_instance, args)
	#####################################################
	init_time = time()
	count = Dict(:latest_improvement => 1,
	  			 :first_improvement => false,
	 		     :warm_trial => 0,
	  		     :cold_trial => 1,
				 :total_iter => 0,
				 :print_time => init_time)
	lowest = Tour(Int64[], typemax(Int64))
	start_time = time_ns()
	# compute set distances which will be helpful
	setdist = set_vertex_dist(dist, num_sets, membership)
	powers = initialize_powers(param)

	while count[:cold_trial] <= param[:cold_trials]
		# build tour from scratch on a cold restart
		best = initial_tour!(lowest, dist, sets, setdist, count[:cold_trial], param)
		# print_cold_trial(count, param, best)
		phase = :early

		if count[:cold_trial] == 1
			powers = initialize_powers(param)
		else
			power_update!(powers, param)
		end

		while count[:warm_trial] <= param[:warm_trials]
			iter_count = 1
			current = Tour(copy(best.tour), best.cost)
			temperature = 1.442 * param[:accept_percentage] * best.cost
			# accept a solution with 50% higher cost with 0.05% change after num_iterations.
			cooling_rate = ((0.0005 * lowest.cost)/(param[:accept_percentage] *
									current.cost))^(1/param[:num_iterations])

			if count[:warm_trial]  > 0	  # if warm restart, then use lower temperature
		        temperature *= cooling_rate^(param[:num_iterations]/2)
				phase = :late
			end
			while count[:latest_improvement] <= (count[:first_improvement] ?
				  param[:latest_improvement] : param[:first_improvement])

				if iter_count > param[:num_iterations]/2 && phase == :early
					phase = :mid  # move to mid phase after half iterations
				end
				trial = remove_insert(current, best, dist, membership, setdist, sets, powers, param, phase)

		        # decide whether or not to accept trial
				if accepttrial_noparam(trial.cost, current.cost, param[:prob_accept]) ||
				   accepttrial(trial.cost, current.cost, temperature)
					param[:mode] == "slow" && opt_cycle!(current, dist, sets, membership, param, setdist, "full")
				    current = trial
		        end
		        if current.cost < best.cost
					count[:latest_improvement] = 1
					count[:first_improvement] = true
					if count[:cold_trial] > 1 && count[:warm_trial] > 1
						count[:warm_trial] = 1
					end
					opt_cycle!(current, dist, sets, membership, param, setdist, "full")
					best = current
	        	else
					count[:latest_improvement] += 1
				end

				# if we've come in under budget, or we're out of time, then exit
			    if best.cost <= param[:budget] || time() - init_time > param[:max_time]
					param[:timeout] = (time() - init_time > param[:max_time])
					param[:budget_met] = (best.cost <= param[:budget])
					timer = (time_ns() - start_time)/1.0e9
					lowest.cost > best.cost && (lowest = best)
					print_best(count, param, best, lowest, init_time)
					print_summary(lowest, timer, membership, param)
					return
				end

		        temperature *= cooling_rate  # cool the temperature
				iter_count += 1
				count[:total_iter] += 1
				print_best(count, param, best, lowest, init_time)
			end
			print_warm_trial(count, param, best, iter_count)
			# on the first cold trial, we are just determining
			count[:warm_trial] += 1
			count[:latest_improvement] = 1
			count[:first_improvement] = false
		end
		lowest.cost > best.cost && (lowest = best)
		count[:warm_trial] = 0
		count[:cold_trial] += 1

		# print_powers(powers)

	end
	timer = (time_ns() - start_time)/1.0e9
	print_summary(lowest, timer, membership, param)
end
end
