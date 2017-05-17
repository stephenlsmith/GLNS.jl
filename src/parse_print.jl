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

#########  Input Parsing ############################

"""
parse the problem instance file given as a text file with the following format:
N: int
M: int
Symmetric: true/false
Triangle: true/false
1 5 
5 1 8 9 10 11 
8 2 3 4 6 7 12 13 14 
DISTANCE_MATRIX

Note: the line 5 1 8 9 10 11 shows that the second set contains 5 vertices: 
1,8,9,10,11.

TSPLIB Parser defined by:
  http://comopt.ifi.uni-heidelberg.de/software/TSPLIB95/TSPFAQ.html
"""
function read_file(filename)
	  if !isfile(filename)
		    error("the problem instance  ", filename, " does not exist")
	  end

    # Setup
    INF = 9999
    RE_INT = r"-?\d+"
    RE_DEC = r"-?\d+\.\d+"
    RE_NUMBER = r"-?\d+\.?\d*"

    parse_state = "UNKNOWN_FORMAT"
    data_type = ""
    data_format = ""
    dist = zeros(Int64, 0, 0)
    sets = Any[]
    vid00 = vid01 = 1
    coords = Any[]
    set_data = Int64[]
    num_vertices = -1
    num_sets = -1

    # parse
    s = open(filename, "r")
    for line in readlines(s)
        line = strip(line)
        # debug
#        println(line)
#        println(parse_state)

        # auto format select
        if parse_state == "UNKNOWN_FORMAT"
            if ismatch(r"^\s*NAME\s*:\s*\w+", uppercase(line))
                parse_state = "TSPLIB_HEADER"
            elseif ismatch(r"^\s*N\s*:\s*\w+", uppercase(line))
                parse_state = "SIMPLE_HEADER"
            end
        end

        # Parse Setup
        if parse_state == "TSPLIB_HEADER"
            value = strip(split(line,":")[end])
            if ismatch(r"^\s*NAME\s*:\s*\w+", uppercase(line))
            elseif ismatch(r"^\s*TYPE\s*:\s*\w+\s*$", uppercase(line))
            elseif ismatch(r"^\s*DIMENSION\s*:\s*\d+\s*$", uppercase(line))
                num_vertices = parse(Int64, value)
                dist = zeros(Int64, num_vertices, num_vertices)
            elseif ismatch(r"^\s*GTSP_SETS\s*:\s*\d+\s*$", uppercase(line))
                num_sets = parse(Int64, value)
            elseif ismatch(r"^\s*EDGE_WEIGHT_TYPE\s*:\s*\w+\s*$", uppercase(line))
                data_type = value
                data_format = value
            elseif ismatch(r"^\s*EDGE_WEIGHT_FORMAT\s*:\s*\w+\s*$", uppercase(line))
                if data_type == "EXPLICIT"
                    data_format = value
                end
            elseif ismatch(r"^\s*EDGE_WEIGHT_SECTION\s*:?\s*$", uppercase(line))
                parse_state = "TSPLIB_MATRIX_DATA"
            elseif ismatch(r"^\s*NODE_COORD_SECTION\s*:?\s*$", uppercase(line))
                parse_state = "TSPLIB_COORD_DATA"
            end

        # Parse matrix data
        elseif parse_state == "TSPLIB_MATRIX_DATA"
            if ismatch(r"^[\d\se+-\.]+$", line)
                for x in split(line)
                    cost = parse(Int64, x)
                    # tested
                    if data_format == "FULL_MATRIX"
                        dist[vid00, vid01] = cost
                        vid01 += 1
                        if vid01 > num_vertices
                            vid00 += 1
                            vid01  = 1
                        end
                    # tested
                    elseif data_format == "LOWER_DIAG_ROW"
                        dist[vid00, vid01] = cost
                        dist[vid01, vid00] = cost
                        vid01 += 1
                        if vid01 > vid00
                            vid00 += 1
                            vid01  = 1
                        end
                    # not tested
                    elseif data_format == "LOWER_ROW"
                        println("WARNING: Not tested")

                        if vid00 == 0 && vid01 == 0
                            vid00 = 1
                        end
                        dist[vid00, vid01] = cost
                        dist[vid01, vid00] = cost
                        vid01 += 1
                        if vid01 >= vid00
                            vid00 += 1
                            vid01  = 0
                        end
                    # tested
                    elseif data_format == "UPPER_DIAG_ROW"
                        dist[vid00, vid01] = cost
                        dist[vid01, vid00] = cost
                        vid01 += 1
                        if vid01 > num_vertices
                            vid00 += 1
                            vid01  = vid00
                        end
                    # tested
                    elseif data_format == "UPPER_ROW"
                        if vid00 == 1 && vid01 == 1
                            vid01 = 2
                        end
                        dist[vid00, vid01] = cost
                        dist[vid01, vid00] = cost
                        vid01 += 1
                        if vid01 > num_vertices
                            vid00 += 1
                            vid01  = vid00+1
                        end
                    end
                end
            elseif ismatch(r"^\s*DISPLAY_DATA_SECTION\s*:?\s*$", uppercase(line))
                parse_state = "TSPLIB_DISPLAY_DATA"
            elseif ismatch(r"^\s*GTSP_SET_SECTION\s*:?\s*$", uppercase(line))
                parse_state = "TSPLIB_SET_DATA"
            end

        # Parse display data
        elseif parse_state == "TSPLIB_DISPLAY_DATA"
            if ismatch(r"^\s*GTSP_SET_SECTION\s*:?\s*$", uppercase(line))
                parse_state = "TSPLIB_SET_DATA"
            end

        # Parse coord data
        elseif parse_state == "TSPLIB_COORD_DATA"
            if ismatch(r"\s*\d+\s*", uppercase(line))
                coord = [parse(Float64, x) for x = split(line)[2:end]]
                push!(coords, coord)
            elseif ismatch(r"^\s*GTSP_SET_SECTION\s*:?\s*$", uppercase(line))
                parse_state = "TSPLIB_SET_DATA"
            end

        # Parse set data
        elseif parse_state == "TSPLIB_SET_DATA"
            if ismatch(r"\d+", uppercase(line))
                for x = split(line)
                    push!(set_data, parse(Int64,x))
                end
            elseif ismatch(r"^\s*EOF\s*$", uppercase(line))
                parse_state = "TSPLIB"
            end

        # Parse header (simple)
        elseif parse_state == "SIMPLE_HEADER"
            if ismatch(r"^\s*N\s*:\s*\w+", uppercase(line))
                value = strip(split(strip(line),":")[end])
                num_vertices = parse(Int64, value)
                dist = zeros(Int64, num_vertices, num_vertices)
            elseif ismatch(r"^\s*M\s*:\s*\d+\s*$", uppercase(line))
                value = strip(split(strip(line),":")[end])
                num_sets = parse(Int64, value)
                parse_state = "SIMPLE_SETS"
            end

        # Parse set data (simple)
        elseif parse_state == "SIMPLE_SETS"
            if ismatch(r"^[\d\se+-\.]+$", line)
                sid = parse(Int64, split(line)[1])
                set = [parse(Int64, x) for x in split(line)[2:end]]
                push!(sets, set)
                if sid == num_sets
                    parse_state = "SIMPLE_MATRIX"
                end
            end

        # Parse set data (simple)
        elseif parse_state == "SIMPLE_MATRIX"
            if ismatch(r"^[\d\se+-\.]+$", line)
                for x in split(line)
                    cost = parse(Int64, x)
                    dist[vid00, vid01] = cost
                    vid01 += 1
                    if vid01 > num_vertices
                        vid00 += 1
                        vid01  = 1
                    end
                end
            else
                parse_state = "SIMPLE"
            end
        end

    end
    close(s)
    if ismatch(r"TSPLIB", parse_state)
        parse_state = "TSPLIB"
    end

    # Convert coordinate data to matrix data
    if parse_state == "TSPLIB" && data_type != "EXPLICIT"
        # tested
        if data_format == "EUC_2D"
            for vid00 in 1:num_vertices
                for vid01 in 1:num_vertices
                    if vid00 == vid01
                        dist[vid00, vid01] = INF
                    else
                        dx = coords[vid00][1] - coords[vid01][1]
                        dy = coords[vid00][2] - coords[vid01][2]
                        cost = sqrt(dx^2 + dy^2)
                        dist[vid00, vid01] = nint(cost)
                    end
                end
            end
        # not tested
        elseif data_format == "MAN_2D"
            println("Warning: MAN_2D not tested")
            for vid00 in 1:num_vertices
                for vid01 in 1:num_vertices
                    if vid00 == vid01
                        dist[vid00, vid01] = INF
                    else
                        dx = coords[vid00][1] - coords[vid01][1]
                        dy = coords[vid00][2] - coords[vid01][2]
                        cost = abs(dx) + abs(dy)
                        dist[vid00, vid01] = nint(cost)
                    end
                end
            end
        # not working...
        elseif data_format == "GEO"
            RRR = 6378.388
            PI = 3.141592
            DEBUG01 = false
            TSPLIB_GEO = true
            for vid00 in 1:num_vertices
                d, m    = degree_minutes(coords[vid00][1])
                lat00   = PI * (d + 5.0 * m / 3.0) / 180.0
                d, m    = degree_minutes(coords[vid00][2])
                long00  = PI * (d + 5.0 * m / 3.0) / 180.0
                for vid01 in 1:num_vertices
                    d, m    = degree_minutes(coords[vid01][1])
                    lat01   = PI * (d + 5.0 * m / 3.0) / 180.0
                    d, m    = degree_minutes(coords[vid01][2])
                    long01  = PI * (d + 5.0 * m / 3.0) / 180.0
                    if vid00 == vid01
                        dist[vid00, vid01] = INF
                    else
                        if TSPLIB_GEO
                            q1      = cos(long00 - long01)
                            q2      = cos(lat00 - lat01)
                            q3      = cos(lat00 + lat01)
                            cost    = RRR * acos(0.5 * ((1.0 + q1) * q2 - (1.0 - q1) * q3)) + 1.0
                            dist[vid00, vid01] = floor(Int64, cost)
                        else
                            # http://andrew.hedges.name/experiments/haversine/
                            R       = 6373
                            dlat    = abs(coords[vid01][1] - coords[vid00][1])
                            dlong   = abs(coords[vid01][2] - coords[vid00][2])
                            a       = (sind(dlat/2))^2 + cosd(coords[vid00][1])*cosd(coords[vid01][1])*(sind(dlong/2))^2
                            c       = 2*atan2(sqrt(a), sqrt(1-a))
                            cost    = R * c
                            dist[vid00, vid01] = floor(Int64, cost)
                        end
                        if DEBUG01
                            println("lat00 = ", coords[vid00][1], ", long00 = ", coords[vid00][2], ", lat01 = ", coords[vid01][1], ", long01 = ", coords[vid01][2], ", dist = ", floor(Int64, cost))
                            DEBUG01 = false
                        end
                    end
                end
            end
        # tested
        elseif data_format == "ATT"
            for vid00 in 1:num_vertices
                for vid01 in 1:num_vertices
                    if vid00 == vid01
                        dist[vid00, vid01] = INF
                    else
                        dx = coords[vid00][1] - coords[vid01][1]
                        dy = coords[vid00][2] - coords[vid01][2]
                        r  = sqrt((dx^2 + dy^2)/10.0)
                        cost = ceil(r)
                        dist[vid00, vid01] = nint(cost)
                    end
                end
            end
        # tested: not sure if working or not
        elseif data_format == "CEIL_2D"
            for vid00 in 1:num_vertices
                for vid01 in 1:num_vertices
                    if vid00 == vid01
                        dist[vid00, vid01] = INF
                    else
                        dx = coords[vid00][1] - coords[vid01][1]
                        dy = coords[vid00][2] - coords[vid01][2]
                        cost = sqrt(dx^2 + dy^2)
                        dist[vid00, vid01] = ceil(cost)
                    end
                end
            end
        else
            error("coordinate type $data_format not supported")
        end
    end

    # construct sets
    if parse_state == "TSPLIB"
        i = 1
        sid00 = 1
        set = Int64[]
        set_data = set_data[2:end]
        while i <= length(set_data)
            x = set_data[i]
            if x == -1
                push!(sets, set)
                set = Int64[]
                i += 1 # skip set id
            else
                push!(set, x)
            end        
            i += 1
        end
        if num_sets != length(sets)
            error("number of sets doesn't match set size")
        end
    end

    if length(sets) <= 1
        error("must have more than 1 set")
    end

	  membership = findmember(num_vertices, sets)

    return num_vertices, num_sets, sets, dist, membership
end


""" Computing degrees and minutes for GEO instances """
function degree_minutes(num)
	if num > 0
		deg = floor(Int64, num)
		return deg, num - deg 
	else
		deg = ceil(Int64, num)
		return deg, num - deg
	end
end


#####################################################
#####################################################
######### Output Printing ###########################

""" print the main parameter settings """
function print_params(param::Dict{Symbol,Any})
	if param[:print_output] > 0
		println("\n", "--------- Problem Data ------------")
		println("Instance Name      : ", param[:problem_instance])
	    println("Number of Vertices : ", param[:num_vertices])
	    println("Number of Sets     : ", param[:num_sets])
		println("Initial Tour       : ", (param[:init_tour] == "rand" ? 
				"Random" : "Random Insertion"))
		println("Maximum Removals   : ", param[:max_removals])
		println("Trials             : ", param[:cold_trials])
		println("Restart Attempts   : ", param[:warm_trials])
		println("Rate of Adaptation : ", param[:epsilon])
		println("Prob of Reopt      : ", param[:prob_reopt])
		println("Maximum Time       : ", param[:max_time])
		println("Tour Budget        : ", (param[:budget] == typemin(Int64) ?
				"None" : param[:budget]))
		println("-----------------------------------\n")
	end
end


"""
Print the powers in an easy-to-read format for debugging the adaptive weights
"""
function print_powers(powers)
	println("--  Printing powers -- ")
	println("Insertions:")
	for power in powers["insertions"]
		println(power.name, " ", power.value, ": ", power.weight)
	end

	println("\n Removals:")
	for power in powers["removals"]
		println(power.name, " ", power.value, ": ", power.weight)
	end
	print("\n")
	
	println("\n Noises:")
	for power in powers["noise"]
		println(power.name, " ", power.value, ": ", power.weight)
	end
	print("\n")
end


"""print statement at the beginning of a cold trial"""
function print_cold_trial(count::Dict{Symbol,Any}, param::Dict{Symbol,Any}, best::Tour)
	if param[:print_output] == 2
		println("\n||--- trial ", count[:cold_trial], 
		" --- initial cost ", best.cost, " ---||")
	end
end


"""print details at the end of each warm trial"""
function print_warm_trial(count::Dict{Symbol,Any}, param::Dict{Symbol,Any}, 
							best::Tour, iter_count::Int)
	if param[:print_output] == 2
		println("-- ", count[:cold_trial], ".", count[:warm_trial], 
		" - iterations ", iter_count, ":  ", "cost ", best.cost)
	end
end


""" print best cost so far """
function print_best(count::Dict{Symbol,Any}, param::Dict{Symbol,Any}, 
							best::Tour, lowest::Tour, init_time::Float64)
	if param[:print_output] == 1 && time() - count[:print_time] > param[:print_time]
		count[:print_time] = time()
		println("-- trial ", count[:cold_trial], ".", count[:warm_trial], ":", 
				"  Cost = ", min(best.cost, lowest.cost), 
				"  Time = ", round(count[:print_time] - init_time, 1), " sec") 
	
	elseif (param[:print_output] == 3 && time() - count[:print_time] > 0.5) ||
		param[:budget_met] || param[:timeout]
		
		count[:print_time] = time()
		if param[:warm_trials] > 0
			progress = (count[:cold_trial] - 1)/param[:cold_trials] +
	 	   			 (count[:warm_trial])/param[:warm_trials]/param[:cold_trials]						   		
		else 
			progress = (count[:cold_trial] - 1)/param[:cold_trials]
		end
		tcurr = round(count[:print_time] - init_time, 1)
		cost = min(best.cost, lowest.cost)
		progress_bar(param[:cold_trials], progress, cost, tcurr)
	end	
end


""" a string representing the progress bar """
function progress_bar(trials, progress, cost, time)
	ticks, trials_per_bar, total_length = 6, 5, 31
	progress == 1.0 && (progress -= 0.0001)	
	n = floor(Int64, progress * trials/trials_per_bar)
	start_number = n * trials_per_bar
	trials_in_bar = min(trials_per_bar, trials - start_number)

	progress_in_bar = (progress * trials - start_number)/trials_in_bar
	bar_length = min(total_length - 1, (trials - start_number) * ticks)
	
	progress_bar = "|"
	for i=1:total_length
		if i == bar_length + 1
			progress_bar *= "|"
		elseif i > bar_length + 1
			progress_bar *= " "
		elseif i % ticks == 1
			progress_bar *= string(start_number + ceil(Int64, i / ticks))
		elseif i <= ceil(Int64, bar_length * progress_in_bar)
			progress_bar *= "="
		else
			progress_bar *= " "
		end
	end
	print(" ", progress_bar, "  Cost = ", cost, "  Time = ", time, " sec      \r")
end


"""print tour summary at end of execution"""
function print_summary(lowest::Tour, timer::Float64, member::Array{Int64,1}, 
						param::Dict{Symbol,Any})
	if param[:print_output] == 3 && !param[:timeout] && !param[:budget_met]
		progress_bar(param[:cold_trials], 1.0, lowest.cost, round(timer, 1))
	end
	if param[:print_output] > -1
		if (param[:print_output] > 0 || param[:output_file] == "None")
			println("\n\n", "--------- Tour Summary ------------")
			println("Cost              : ", lowest.cost)
			println("Total Time        : ", round(timer, 2), " sec")
			println("Solver Timeout?   : ", param[:timeout])
			println("Tour is Feasible? : ", tour_feasibility(lowest.tour, member, 
																	param[:num_sets]))
			order_to_print = (param[:output_file] == "None" ? 
					lowest.tour : "printed to " * param[:output_file])
			println("Output File       : ",  param[:output_file])
			println("Tour Ordering     : ",  order_to_print)
			println("-----------------------------------")
		end
		if param[:output_file] != "None"
			s = open(param[:output_file], "w")
			write(s, "Problem Instance : ", param[:problem_instance], "\n")
			write(s, "Vertices         : ", string(param[:num_vertices]), "\n")
			write(s, "Sets             : ", string(param[:num_sets]), "\n")
			write(s, "Comment          : To avoid ~0.5sec startup time, use the Julia REPL\n")
			write(s, "Host Computer    : ", gethostname(), "\n")
			write(s, "Solver Time      : ", string(round(timer, 3)), " sec\n")
			write(s, "Tour Cost        : ", string(lowest.cost), "\n")
			write(s, "Tour             : ", string(lowest.tour))
			close(s)
		end
	end
end


"""
init function defined by TSPLIB
  http://comopt.ifi.uni-heidelberg.de/software/TSPLIB95/TSPFAQ.html
"""
function nint(x::Float64)
    return floor(Int64, x + 0.5)
end

