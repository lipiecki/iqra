# Install dependencies and download replication files from Hugging Face.
using Pkg
Pkg.instantiate()

using HuggingFaceApi

const PROJECT_DIR = normpath(joinpath(@__DIR__, ".."))
const REPO = "lipiecki/iqra"

function download_directory(name; project_dir=PROJECT_DIR)
    files = sort(filter(path -> startswith(path, "$name/"),
                        HuggingFaceApi.list_dataset_files(REPO)))
    downloaded = 0
    for path in files
        target = joinpath(project_dir, split(path, '/')...)
        isfile(target) && filesize(target) > 0 && continue
        mkpath(dirname(target))
        temporary = hf_hub_download("datasets/$REPO", path; cache=false)
        try
            mv(temporary, target; force=true)
        finally
            isfile(temporary) && rm(temporary)
        end
        downloaded += 1
    end
    println("$name/: downloaded $downloaded files, $((length(files) - downloaded)) existing files were skipped")
end

function main(args)
    all(arg -> arg == "--with-outputs", args) && length(args) <= 1 ||
        error("Usage: julia --project=. scripts/setup.jl [--with-outputs]")

    Pkg.instantiate()
    download_directory("inputs")
  
    if "--with-outputs" in args
        download_directory("outputs")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end
