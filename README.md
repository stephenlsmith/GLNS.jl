# GLNS

A Generalized Traveling Salesman Problem (GTSP) Solver.

This solver is implemented in Julia (<http://julialang.org/>).  It is now **compatible with Julia v1.0.  Update Julia to v1.0 before running GLNS.**

More information on the solver is given at <https://ece.uwaterloo.ca/~sl2smith/GLNS/>

## Citing this work
The solver and its settings are described in the following paper
[[DOI]](https://doi.org/10.1016/j.cor.2017.05.010) [[PDF]](https://ece.uwaterloo.ca/~sl2smith/papers/2017COR-GLNS.pdf):

	@Article{Smith2017GLNS,
		author =    {S. L. Smith and F. Imeson},
		title =     {{GLNS}: An Effective Large Neighborhood Search Heuristic
		             for the Generalized Traveling Salesman Problem},
		journal =   {Computers \& Operations Research},
		volume =    87,
   	    pages =     {1-19},
		year =      2017,
	}


Please cite this paper when using GLNS.


## Using the solver

GLNS has three default settings: slow, default, and fast.
It also has several flags that can be used to give to give the solver
timeout, or to have it quit when a solution cost threshold is met.

The solver can be run from the command line or from the Julia REPL.

The input to the solver is a text file in
[GTSPLIB format](http://www.cs.rhul.ac.uk/home/zvero/GTSPLIB/), which is an extension of the
[TSPLIB format](https://www.iwr.uni-heidelberg.de/groups/comopt/software/TSPLIB95/).

### Running from the command line


Julia has a startup time of approximately 0.5 seconds, which gives this
option a delay over option two below.  Download the command line solver **GLNScmd.jl** from this repository and place in a convenient location.
The syntax is as follows:

```bash
$ <path_to_script>/GLNScmd.jl <path_to_instance> -options
```

The following are a few examples:

```bash
$ <path_to_script>/GLNScmd.jl test/39rat195.gtsp
$ <path_to_script>/GLNScmd.jl test/39rat195.gtsp -mode=fast -output=tour.txt

# GLNS can also be set to run "persistently" for a given amount of time.
# The following example will run for 60 seconds before terminating.
$ <path_to_script>/GLNScmd.jl test/39rat195.gtsp -max_time=60 -trials=100000
```

### Running from the Julia REPL

For this method you should launch Julia, include the GLNS module, and then
call the solver. This is done as follows:

```julia
$ julia
julia> include("GLNS.jl")
julia> GLNS.solver("<path_to_instance>", options)
```

Here are a few more examples.  The first uses the default settings.  The
last example is a persistent solver that will run for at most 60 seconds,
but will quit if it finds a tour of cost 13,505 or less (the best known solution
for this instance is 13,502):

```julia
julia> GLNS.solver("test/39rat195.gtsp")
julia> GLNS.solver("test/39rat195.gtsp", mode="slow")
julia> GLNS.solver("test/107si535.gtsp", max_time=60, budget=13505, trials=100000)
```


## Index of files
The GLNS solver package is arranged as follows.

- GLNScmd.jl -- Command line solver 
- examples/ -- contains sample GTSP instances for testing and as example inputs
- src/ -- contains
    - GLNS.jl --- Main Julia solver
	- adaptive_powers.jl
	- insertion_deletion.jl
	- parameter_defaults.jl
	- parse_print.jl
	- tour_optimizations.jl
	- utilities.jl
- test/ -- test scripts for installation verification


## License
Copyright 2018 Stephen L. Smith and Frank Imeson

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at  <http://www.apache.org/licenses/LICENSE-2.0>

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
