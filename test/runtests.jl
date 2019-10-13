using GLNS

datafile = joinpath( @__DIR__, "..", "examples", "test.gtsp" )
@time GLNS.solver( datafile )

