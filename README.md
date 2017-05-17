# GLNS -- A Generalized Traveling Salesman Problem (GTSP) Solver 

A solver for the Generalized Traveling Salesman Problem implemented in Julia (<http://julialang.org/>). 

The solver and its settings are described in the following paper:
```
@Article{Smith2016GLNS,
	author =    {S. L. Smith and F. Imeson},
	title =     {GLNS}: An Effective Large Neighborhood Search Heuristic for the Generalized Traveling Salesman Problem},
	journal =   {Computers \& Operations Research},
	year =      2017,
	note =      {To appear},  
}
```

See also <https://ece.uwaterloo.ca/~sl2smith/GLNS/>


## Using the solver

GLNS has three default settings: slow, default, and fast. 
It also has several flags that can be used to give to give the solver
timeout, or to have it quit when a solution cost threshold is met.

The solver can be run from the command line or from the Julia REPL. 

### Running from the command line


Julia has a startup time of approximately 0.5 seconds, which gives this option
a delay over option two below.  The syntax is as follows:


`$ ./GLNScmd.jl <path_to_instance> -options`

The following are a few examples

```$ ./GLNScmd.jl test/39rat195.gtsp
$ ./GLNScmd.jl test/39rat195.gtsp -mode=fast -output=tour.txt```

GLNS can also be set to run "persistently" for a given amount of time. The following example will run for 60 seconds before terminating.

`$ ./GLNScmd.jl test/39rat195.gtsp -max_time=60 -trials=100000`

### Running from the Julia REPL

For this method you should launch Julia, include the GLNS module, and then call
the solver. This is done as follows:

```
$ julia
julia> include("GLNS.jl")
julia> GLNS.solver("<path_to_instance>", options)
```

The following are a few examples.  The first is the default setting and the last is
 the a persistent solver that will run for 30 seconds

```
julia> GLNS.solver("test/39rat195.gtsp") 
julia> GLNS.solver("test/39rat195.gtsp", mode="slow")
julia> GLNS.solver("test/107si535.gtsp", max_time=30, trials=100000)
```


## Index of files
The GLNS solver contains the following files.

- GLNScmd.jl --- command line solver
- GLNS.jl --- Main Julia solver
- src/ -- contains
	- adaptive_powers.jl
	- insertion_deletion.jl
	- parameter_defaults.jl
	- parse_print.jl
	- tour_optimizations.jl
	- utilities.jl
- test/ -- contains sample GTSP instances for testing


## Licence 
Copyright 2017 Stephen L. Smith and Frank Imeson

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 

## Contact information 

Prof. Stephen L. Smith  
Department of Electrical and Computer Engineering  
University of Waterloo  
Waterloo, ON Canada  
web: <https://ece.uwaterloo.ca/~sl2smith/>  
email: <stephen.smith@uwaterloo.ca>
