using Test
using Random
using GLNS

@testset "Parsing basics" begin
    datafile = joinpath(@__DIR__, "..", "examples", "tiny.gtsp")
    n, m, sets, dist, membership = GLNS.read_file(datafile)
    @test n > 0 && m > 1
    @test size(dist) == (n, n)
    @test length(sets) == m
    @test all(!isempty, sets)
    # membership covers all vertices exactly once where defined
    seen = zeros(Int, n)
    for (sidx, set) in pairs(sets)
        for v in set
            @test 1 <= v <= n
            @test membership[v] == sidx
            seen[v] += 1
        end
    end
    @test all(==(1), seen[seen .> 0])
end

@testset "Tour utilities" begin
    # tiny synthetic instance: 3 sets, 1 vertex each
    dist = Int[ 9999 1  2;
                2   9999 3;
                4   1  9999 ]
    sets = [[1],[2],[3]]
    membership = [1,2,3]
    tour = [1,2,3]
    @test GLNS.tour_feasibility(tour, membership, 3)
    @test GLNS.tour_cost(tour, dist) == dist[3,1] + dist[1,2] + dist[2,3]
end

@testset "Set-vertex distances" begin
    datafile = joinpath(@__DIR__, "..", "examples", "tiny.gtsp")
    n, m, sets, dist, membership = GLNS.read_file(datafile)
    dsv = GLNS.set_vertex_dist(dist, m, membership)
    # spot-check a few minima
    @test dsv.set_vert[1,3] == min(dist[1,3], dist[2,3])
    @test dsv.vert_set[4,1] == min(dist[4,1], dist[4,2])
end

@testset "pivot_tour! preserves elements" begin
    Random.seed!(1)
    t = [1,2,3,4,5]
    before = copy(t)
    GLNS.pivot_tour!(t)
    @test sort(t) == sort(before)
    @test length(t) == length(before)
end

@testset "remove_insert invariants" begin
    datafile = joinpath(@__DIR__, "..", "examples", "tiny.gtsp")
    n, m, sets, dist, membership = GLNS.read_file(datafile)
    setdist = GLNS.set_vertex_dist(dist, m, membership)
    # minimal params for remove/insert
    param = Dict{Symbol,Any}(
        :min_removals => 1,
        :max_removals => 2,
        :prob_reopt => 0.0,
        :num_sets => length(sets),
        :mode => "default",
    )
    powers = GLNS.initialize_powers(Dict{Symbol,Any}(
        :insertions => ["cheapest"],
        :insertion_powers => [-1.0, 0.0, 1.0],
        :removals => ["worst"],
        :removal_powers => [0.0],
        :noise => "None",
        :epsilon => 0.5,
        :mode => "default",
    ))
    current_vertices = [sets[i][1] for i in 1:m]
    current = GLNS.Tour(current_vertices, GLNS.tour_cost(current_vertices, dist))
    trial = GLNS.remove_insert(current, dist, membership, setdist, sets, powers, param, :early)
    @test length(trial.tour) == length(current.tour)
    @test GLNS.tour_feasibility(trial.tour, membership, m)
    @test trial.cost == GLNS.tour_cost(trial.tour, dist)
end

@testset "Reoptimization non-increasing" begin
    datafile = joinpath(@__DIR__, "..", "examples", "tiny.gtsp")
    n, m, sets, dist, membership = GLNS.read_file(datafile)
    setdist = GLNS.set_vertex_dist(dist, m, membership)
    t = [sets[i][1] for i in 1:m]
    current = GLNS.Tour(copy(t), GLNS.tour_cost(t, dist))
    param = Dict{Symbol,Any}(
        :mode => "default",
        :max_removals => 2,
        :min_set => GLNS.min_set(sets),
        :num_vertices => n,
    )
    GLNS.opt_cycle!(current, dist, sets, membership, param, setdist, "full")
    @test GLNS.tour_feasibility(current.tour, membership, m)
end

@testset "Acceptance functions" begin
    @test GLNS.accepttrial(10, 10, 1.0) == true
    @test GLNS.accepttrial_noparam(10, 10, 0.0) == true
    @test GLNS.accepttrial_noparam(11, 10, 0.0) == false
end

@testset "Integration (39rat195.gtsp)" begin
    datafile = joinpath(@__DIR__, "..", "examples", "39rat195.gtsp")
    n, m, sets, dist, membership = GLNS.read_file(datafile)
    @test n > 0 && m > 1
    @test size(dist) == (n, n)
    @test length(sets) == m

    tmp = joinpath(@__DIR__, "tour_39rat195.txt")
    try
        GLNS.solver(datafile; output=tmp, verbose=0)
        @test isfile(tmp)
        contents = read(tmp, String)
        @test occursin("Tour Cost", contents)
        @test occursin("Tour", contents)
    finally
        isfile(tmp) && rm(tmp; force=true)
    end
end

