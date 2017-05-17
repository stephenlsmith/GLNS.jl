# GLNS -- A Generalized Traveling Salesman Problem (GTSP) Solver 

A Julia solver for the Generalized Traveling Salesman Problem

Julia is available at <http://julialang.org/>

See also <https://ece.uwaterloo.ca/~sl2smith/GLNS/>


## Using the solver

- GLNS has three main settings: slow, default, and fast.
- GLNS can be run from the command line. There are two drawbacks to this method.
  Julia has a startup time of approximately 0.5 seconds, which gives this option
  a delay.  Second, 

$ ./GLNScmd.jl <path_to_instance> -options

The following a few examples

$ ./GLNScmd.jl test/39rat195.gtsp
$ ./GLNScmd.jl test/39rat195.gtsp -mode=fast -output=tour.txt

- GLNS can also be set to run "persistently" for a given amount of time.
The following example will run for 60 seconds before terminating.
$ ./GLNScmd.jl test/39rat195.gtsp -max_time=60 -trials=100000

- Alternatively, GLNS can be run from the Julia REPL.

$ julia
julia> include("GLNS.jl")
julia> GLNS.solver("<path_to_instance>", options)

The following are a few examples:

julia> GLNS.solver("test/39rat195.gtsp")  # default setting
julia> GLNS.solver("test/39rat195.gtsp", mode="slow")
julia> GLNS.solver("test/39rat195.gtsp", mode="fast", trials=20)



## Index of files
The GLNS solver contains the following files.

GLNScmd.jl --- command line solver
GLNS.jl --- Main Julia solver
src/ -- contains
	- adaptive_powers.jl
	- insertion_deletion.jl
	- parameter_defaults.jl
	- parse_print.jl
	- tour_optimizations.jl
	- utilities.jl
test/ -- contains sample GTSP instances for testing


## Licence 
Copyright 2017 Stephen L. Smith and Frank Imeson

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    <http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 

## Contact Information 

Prof. Stephen L. Smith
Department of Electrical and Computer Engineering
University of Waterloo
Waterloo, ON Canada
email: stephen.smith@uwaterloo.ca