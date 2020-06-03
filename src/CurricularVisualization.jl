module CurricularVisualization

using CurricularAnalytics
using WebIO
using HTTP
using Blink
using Plots
using StatsPlots
using LinearAlgebra

import HTTP.Messages

export metric_boxplot, metric_histogram, show_homology, visualize

const LOCAL_EMBED_PORT = 8156
const LOCAL_EMBED_FOLDER = joinpath(dirname(pathof(CurricularVisualization)),"..","embed_client","dist")

function get_embed_url()
        local_embed_url = string("http://localhost:", LOCAL_EMBED_PORT)
        try
            HTTP.request("GET", local_embed_url)
        catch
            serve_local_embed_client()
        end
        return local_embed_url
end

# Serve a local embed client on port 8156
function serve_local_embed_client()
    @async HTTP.serve(HTTP.Sockets.localhost, LOCAL_EMBED_PORT) do req::HTTP.Request
        # default render index.html case
        req.target == "/" && return HTTP.Response(200, read(joinpath(LOCAL_EMBED_FOLDER, "index.html")))

        # construct file location from request target
        file = joinpath(LOCAL_EMBED_FOLDER, HTTP.unescapeuri(req.target[2:end]))

        # determine / set content type
        content_type = "text/html"
        if (occursin(r".js$", file))          
        content_type = "application/javascript"
        elseif (occursin(r".css$", file))     
        content_type = "text/css"
        end
        Messages.setheader(req, "Content-Type" => content_type)

        # return file or 404 if not present
        return isfile(file) ? HTTP.Response(200, read(file)) : HTTP.Response(404)
    end
end

# Returns a requisite as a string
function requisite_to_string(req::Requisite)
    if req == pre
        return "CurriculumPrerequisite"
    elseif req == co
        return "CurriculumCorequisite"
    else
        return "CurriculumStrictCorequisite"
    end
end

# Returns a requisite (enumerated type) from a string
function string_to_requisite(req::String)
    if (req == "prereq" || req == "CurriculumPrerequisite")
        return pre
    elseif (req == "coreq" || req == "CurriculumCorequisite")
        return co
    elseif (req == "strict-coreq" || req == "CurriculumStrictCorequisite")
        return strict_co
    end
end

function prepare_data_for_visualization(degree_plan::DegreePlan; edit::Bool=false, hide_header::Bool=false, show_delay::Bool=true, 
                                            show_blocking::Bool=true, show_centrality::Bool=true, show_complexity::Bool=true)
    dp_dict = Dict{String,Any}()
    dp_dict["options"] = Dict{String, Any}()
    dp_dict["options"]["edit"] = edit
    dp_dict["options"]["hideTerms"] = hide_header
    dp_dict["curriculum"] = Dict{String, Any}()
    dp_dict["curriculum"]["dp_name"] = degree_plan.name
    dp_dict["curriculum"]["name"] = degree_plan.curriculum.name
    dp_dict["curriculum"]["institution"] = degree_plan.curriculum.institution
    dp_dict["curriculum"]["curriculum_terms"] = Dict{String, Any}[]
    for i = 1:degree_plan.num_terms
        current_term = Dict{String, Any}()
        current_term["id"] = i
        current_term["name"] = "Term $i"
        current_term["curriculum_items"] = Dict{String, Any}[]
        for course in degree_plan.terms[i].courses
            current_course = Dict{String, Any}()
            current_course["id"] = course.id
            current_course["nameSub"] = course.name
            current_course["name"] =  course.prefix * " " * course.num
            current_course["credits"] = course.credit_hours
            current_course["curriculum_requisites"] = Dict{String, Any}[]
            if !show_complexity
                delete!(course.metrics, "complexity")
            end
            if !show_centrality
                delete!(course.metrics, "centrality")
            end
            if !show_delay
                delete!(course.metrics, "delay factor")
            end
            if !show_blocking
                delete!(course.metrics, "blocking factor")
            end
            current_course["metrics"] = course.metrics
            current_course["nameCanonical"] = course.canonical_name
            for req in collect(keys(course.requisites))
                current_req = Dict{String, Any}()
                current_req["source_id"] = req
                current_req["target_id"] = course.id
                # Parse the Julia requisite type to the required type for the visualization
                current_req["type"] = requisite_to_string(course.requisites[req])
                push!(current_course["curriculum_requisites"], current_req)
            end
            push!(current_term["curriculum_items"], current_course)
        end
        push!(dp_dict["curriculum"]["curriculum_terms"], current_term)
    end
    return dp_dict
end

# Main visualization function. Pass in degree plan to be visualized. Optionally a window 
# prop can be passed in to specify the render where the visualization should be rendered.
# Additional changed callback may be provided which will envoke whenever the curriculum is 
# modified through the interfaces.
"""
     visualize(curriculum; <keyword arguments>))

Visualize a curriculum. 

# Arguments
Required:

- `curriculum::Curriculum` : the curriculum to visualize.

Keyword:

- `changed` : callback function argument, called whenever the curriculum is modified through the interface.
     Default is `nothing`.
- `notebook` : a Boolean argument, if set to `true`, Blink will not create a new window for the visualization, which allows it to be displayed in the output cell of a Jupyter notebook.
- `edit` : a Boolean argument, if set to `true`, the user may edit the curriculum through the visualziation interface. 
   Default is `false`.
- `output_file` : the relative or absolute path to the CSV file that will store the edited curriculum. Default 
   is `edited_curriculum.csv`.
- `show_delay` : a Boolean argument, if set to `true`, the delay factor metric will be displayed in the tooltip when hovering over a course. Default is `false`.
- `show_blocking` : a Boolean argument, if set to `true`, the blocking factor metric will be displayed in the tooltip when hovering over a course. Default is `false`.
- `show_centrality` : a Boolean argument, if set to `true`, the centrality metric will be displayed in the tooltip when hovering over a course. Default is `false`.
- `show_complexity` : a Boolean argument, if set to `true`, the complexity metric will be displayed in the tooltip when hovering over a course. Default is `false`.
- `scale` : a Real value used to scale the size of the output window.

"""
function visualize(curric::Curriculum; changed=nothing, notebook::Bool=false, edit::Bool=false, min_term::Int=1, output_file="edited_curriculum.csv", 
                    show_delay::Bool=true, show_blocking::Bool=true, show_centrality::Bool=true, show_complexity::Bool=true, scale::Real=1)
    num_courses = curric.num_courses
    if num_courses <= 8
        max_credits_per_term = 9
    elseif num_courses <= 16
        max_credits_per_term = 12
    elseif num_courses <= 24
        max_credits_per_term = 15
    elseif num_courses <= 32
        max_credits_per_term = 18
    elseif num_courses <= 40
        max_credits_per_term = 21
    elseif num_courses <= 48
        max_credits_per_term = 21
    elseif num_courses <= 56
        max_credits_per_term = 21    
    elseif num_courses <= 64
        max_credits_per_term = 21
    elseif num_courses <= 72
        max_credits_per_term = 21
    elseif num_courses <= 80
        max_credits_per_term = 24
    elseif num_courses <= 88
        max_credits_per_term = 24
    elseif num_courses <= 96
        max_credits_per_term = 24
    else
        error("Curriculum is too big to visualize.")
    end
    term_count = num_courses
    dp = create_degree_plan(curric, bin_filling, max_cpt = max_credits_per_term)
    viz_helper(dp; changed=changed, notebook=notebook, edit=edit, hide_header=true, output_file=output_file, show_delay=show_delay,
                show_blocking=show_blocking, show_centrality=show_centrality, show_complexity=show_complexity, scale=scale)
end

# Main visualization function. A "changed" callback function may be provided which will be invoked whenever the 
# curriculum/degere plan is modified through the interface.
"""
    visualize(degree_plan; <keyword arguments>))

Visualize a degree plan. 

# Arguments
Required:
- `degree_plan::DegreePlan` : the degree plan to visualize.

Keyword:
- `changed` : callback function argument, called whenever the degree plan is modified through the interface.
     Default is `nothing`.
- `notebook` : a Boolean argument, if set to `true`, Blink will not create a new window for the visualization, which allows it to be displayed in the output cell of a Jupyter notebook.
- `edit` : a Boolean argument, if set to `true`, the user may edit the degree plan through the visualziation interface. 
   Default is `false`.
- `output_file` : the relative or absolute path to the CSV file that will store the edited degree plan. Default 
   is `edited_degree_plan.csv`.
- `show_delay` : a Boolean argument, if set to `true`, the delay factor metric will be displayed in the tooltip when hovering over a course. Default is `true`.
- `show_blocking` : a Boolean argument, if set to `true`, the blocking factor metric will be displayed in the tooltip when hovering over a course. Default is `true`.
- `show_centrality` : a Boolean argument, if set to `true`, the centrality metric will be displayed in the tooltip when hovering over a course. Default is `true`.
- `show_complexity` : a Boolean argument, if set to `true`, the complexity metric will be displayed in the tooltip when hovering over a course. Default is `true`.
- `scale` : a Real value used to scale the size of the output window.

"""
function visualize(plan::DegreePlan; changed=nothing, notebook::Bool=false, edit::Bool=false, output_file="edited_degree_plan.csv", 
                    show_delay::Bool=true, show_blocking::Bool=true, show_centrality::Bool=true, show_complexity::Bool=true, scale::Real=1)
   
    viz_helper(plan; changed=changed, notebook=notebook, edit=edit,output_file=output_file, show_delay=show_delay,
                show_blocking=show_blocking, show_centrality=show_centrality, show_complexity=show_complexity, scale=scale)
end

function viz_helper(plan::DegreePlan; changed, notebook, edit, hide_header=false, output_file, show_delay::Bool, 
    show_blocking::Bool, show_centrality::Bool, show_complexity::Bool, scale::Real=1)
    if show_delay
        delay_factor(plan.curriculum)
    end
    if show_blocking
        blocking_factor(plan.curriculum)
    end
    if show_centrality
        centrality(plan.curriculum)
    end
    if show_complexity
        complexity(plan.curriculum)
    end  

    if !Blink.AtomShell.isinstalled() 
        Blink.AtomShell.install()
    end
    # Data
    data = prepare_data_for_visualization(plan, edit=edit, hide_header=hide_header, show_delay=show_delay,
                show_blocking=show_blocking, show_centrality=show_centrality,
                show_complexity=show_complexity)        

    # Setup data observation to check for changes being made to curriculum
    s = Scope()

    obs = Observable(s, "curriculum-data", data)

    on(obs) do new_data
        if (isa(changed, Function)) 
            changed(plan, new_data, output_file)
        end
    end

    # iFrame onload event handler
    iframe_loaded = @js function ()
        # when iFrame loaded, post curriculum data to it
        this.contentWindow.postMessage($data, "*")
        # listen for changes to the curriculum and make the observable aware
        # make sure the previous handler is removed before adding the new one
        window.removeEventListener("message", window.messageReceived)
        window.messageReceived = function (event)
            if (event.data.curriculum !== undefined) 
                $obs[] = event.data.curriculum
            end
        end
        window.addEventListener("message", window.messageReceived)
    end
	
	s(
        dom"iframe#curriculum"(
            "", 
            # iFrame source
            src=get_embed_url(),
            # iFrame styles
            style=Dict(
                :width => "100%",
                :height => string(Int(scale*100)) * "vh",
                :margin => "0",
                :padding => "0",
                :border => "none"
            ),
            events=Dict(
                # iFrame onload event
                :load => iframe_loaded
            )
        )
    )
    if (notebook == true)
        # scoped by WebIO
        s
    else
        # Write window body
		w=Window()
        body!(
            w,

            # scoped by WebIO
            s
        )
        return w
    end
end

# Applies to scalar-valued metrics
function metric_histogram(curricula::Array{Curriculum,1}, metric_name::AbstractString; nbins::Int=5, title::AbstractString="", 
                           xlabel::AbstractString="", ylabel::AbstractString="", xlim::Tuple{Int64,Int64}=(0,0), ylim::Tuple{Int64,Int64}=(0,0),
                           legend=false, alpha=0.7, color=:dodgerblue3)
    metric_values = Array{Real,1}() 
    if xlim == (0,0) 
        xlower = 0
        xupper = 0
    end
    for c in curricula
        if haskey(c.metrics, metric_name)
            if typeof(c.metrics[metric_name]) == Float64
                value = c.metrics[metric_name]
            elseif typeof(c.metrics[metric_name]) == Tuple{Float64,Array{Number,1}}  
                value = c.metrics[metric_name][1]  # metric where total curricular metric as well as course-level metrics are stored in an array
            end
            push!(metric_values, value)
            if (@isdefined xlower) == true
                (value < xlower) ? xlower = value : nothing
                (value > xupper) ? xupper = value : nothing
            end
        else
            error("metric_histogram(): $(metric_name) does not exist in the metric dictionary of $(c.name)")
        end
    end
    if xlim == (0,0) 
        x_lim = (xlower, xupper)
    else
        x_lim = xlim
    end
    if ylim == (0,0)
        y_lim = (0, length(curricula)/2)
    else 
        y_lim = ylim
    end
    StatsPlots.histogram(metric_values, nbins=nbins, title=title, xlabel=xlabel, ylabel=ylabel, xlim=x_lim, ylim=y_lim, legend=legend, 
                     alpha=alpha, color=color)
end

# Applies to scalar-valued metrics
function metric_boxplot(series_labels::Array{String,2}, curricula::Array{Array{Curriculum,1},1}, metric_name::AbstractString; title::AbstractString="", 
                        xlabel::AbstractString="", ylabel::AbstractString="", legend=false, alpha=0.7, color=:dodgerblue3)
    if length(series_labels) != length(curricula)
        error("metric_boxplot(): the number of series_labels and the number of curricula series do not match")
    end
    series_ary = Array{Array{Real,1},1}()  # array of series arrays
    for series in curricula
        tmp_series = Array{Real,1}()
        for c in series
            if haskey(c.metrics, metric_name)
                if typeof(c.metrics[metric_name]) == Float64
                    value = c.metrics[metric_name]
                elseif typeof(c.metrics[metric_name]) == Tuple{Float64,Array{Number,1}}  
                    value = c.metrics[metric_name][1]  # metric where total curricular metric as well as course-level metrics are stored in an array
                end
                push!(tmp_series, value)
            else
                error("metric_boxplot(): $(metric_name) does not exist in the metric dictionary of $(c.name)")
            end
        end
        append!(series_ary, [tmp_series])
    end
    StatsPlots.boxplot(series_labels, series_ary, title=title, xlabel=xlabel, ylabel=ylabel, legend=legend, alpha=alpha, color=color)
end

"""
    homology(curricula; <keyword arguments>)

Given a collection of `Curriculum` data objects as input, provide a visulaization that shows how similar each 
curriculum is (in terms of shared courses) to every other curriculum in the collection.  With the default color scheme,
lighter colors indicate hihger similarity, with the color on the main diagonal (the similarity of a curriculum to itself)
indicating maximal similarity.

# Arguments
Required:
- `curricula::Array{Curriculum,1}` : the collection of curricula that will be analzyed for similarity.

Keyword:
- `strict::Bool` : if true, strictly match courses (including course ID); if false (default), match only course name or courese prefix and number. 
- `title::AbstractString` : the title that will appear above the visualization, default is the empty string.
- `xlabel::AbstractString` : the label below the x-axis, default is the empty string.
- `ylabel::AbstractString` : the label below the x-axis, default is the empty string.
- `color::Symbol` : the color gradient used to plot similarity values, default is the symbol `:thermal`.  Other color schemes symbols
- `legend::Bool` : display a plot legend, default is `false`.

To see the color libraries avaiable to you, type:
```julia-repl
julia> clibraries()
```
Then pick one of these color libraries, and use the following function to see the color scheme symbols available in that library, e.g.,
```julia-repl
julia> showlibrary(:cmocean)
```
"""
function show_homology(curricula::Array{Curriculum,1}; strict::Bool=false, title::AbstractString="", xlabel::AbstractString="", ylabel::AbstractString="", 
                  color::Symbol=:thermal, legend::Bool=true)
    names = Array{String,1}()
    sort!(curricula, by = c -> c.name)
    for c in curricula
        push!(names, c.name)
    end
    similarity_matrix = homology(curricula, strict=strict)
    plotlyjs();
    Plots.heatmap(names, names, similarity_matrix, size=(1400,1100), xticks=:all, xtickfont=font(7, "Courier"), xrotation=65, yticks=:all, ytickfont=font(7, "Courier"), 
          yflip=true, hover=similarity_matrix, title=title, xlabel=xlabel, ylabel=ylabel, color=color, legend=legend)
end

end # module
