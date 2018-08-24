using PowerSystems
using Pkg

const DATA_FOLDER = joinpath(dirname(dirname(Base.find_package("PowerSystems"))),"data")


function build_powersystems()

    if !isdir(DATA_FOLDER)
       Pkg.build("PowerSystems")
    end

end

build_powersystems()