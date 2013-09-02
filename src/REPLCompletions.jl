module REPLCompletions

    export completions, shell_completions

    using Base.Meta

    function completes_global(x, name)
        return beginswith(x, name) && !in('#', x)
    end

    # REPL Symbol Completions
    function complete_symbol(sym)
        # Find module
        strs = split(sym,".")
        # Maybe be smarter in the future
        context_module = Main

        mod = context_module
        lookup_module = true
        t = None
        for name in strs[1:(end-1)]
            s = symbol(name)
            if lookup_module
                if isdefined(mod,s)
                    b = mod.(s)
                    if isa(b,Module)
                        mod = b
                    elseif Base.isstructtype(typeof(b))
                        lookup_module = false
                        t = typeof(b)
                    else
                        # A.B.C where B is neither a type nor a 
                        # module. Will have to be revisited if
                        # overloading is allowed
                        return ASCIIString[]
                    end
                else 
                    # A.B.C where B doesn't exist in A. Give up
                    return ASCIIString[]
                end
            else
                # We're now looking for a type
                fields = t.names
                found = false
                for i in 1:length(fields)
                    if s == fields[i]
                        t = t.types[i]
                        if !Base.isstructtype(t)
                            return ASCIIString[]
                        end
                        found = true
                        break
                    end
                end
                if !found
                    #Same issue as above, but with types instead of modules
                    return ASCIIString[]
                end
            end
        end

        name = strs[end]

        suggestions = String[]
        if lookup_module
            # Looking for a binding in a module
            if mod == context_module
                # Also look in modules we got through `using` 
                mods = ccall(:jl_module_usings,Any,(Any,),Main)
                for m in mods
                    ssyms = names(m)
                    syms = map!(string,Array(UTF8String,length(ssyms)),ssyms)
                    append!(suggestions,syms[map((x)->completes_global(x,name),syms)])
                end
                ssyms = names(mod,true,true)
                syms = map!(string,Array(UTF8String,length(ssyms)),ssyms)
            else 
                ssyms = names(mod,true,false)
                syms = map!(string,Array(UTF8String,length(ssyms)),ssyms)
            end
            append!(suggestions,syms[map((x)->completes_global(x,name),syms)])
        else
            # Looking for a member of a type
            fields = t.names
            for field in fields
                s = string(field)
                if beginswith(s,name)
                    push!(suggestions,s)
                end
            end
        end
        sort(unique(suggestions))
    end

    const non_word_chars = " \t\n\"\\'`@\$><=:;|&{}()[].,+-*/?%^~"

    function completions(string,pos)
        startpos = pos
        dotpos = 0
        while startpos >= 1
            c = string[startpos]
            if c < 0x80 && in(char(c), non_word_chars)
                if c != '.'
                    startpos = nextind(string,startpos)
                    break
                elseif dotpos == 0
                    dotpos = startpos
                end
            end
            if startpos == 1
                break
            end
            startpos = prevind(string,startpos)
        end
        if startpos == 0
            pos = -1
        end
        if dotpos == 0
            dotpos = startpos-1
        end
        complete_symbol(string[startpos:pos]), (dotpos+1):pos
    end

    function shell_completions(string,pos)
        # First parse everything up to the current position
        scs = string[1:pos]
        args, last_parse = Base.shell_parse(scs,true)
        # Now look at the last this we parsed
        arg = args.args[end].args[end]
        if isa(arg,String)
            # Treat this as a path (perhaps give a list of comands in the future as well?)
            dir,name = splitdir(arg)
            if isempty(dir)
                files = readdir()
            else
                if !isdir(dir)
                    return ([],0:-1)
                end
                files = readdir(dir)
            end
            # Filter out files and directories that do not begin with the partial name we were
            # completiong and append "/" to directories to simplify further completion
            ret = map(filter(x->beginswith(x,name),files)) do x
                if !isdir(joinpath(dir,x))
                    return x
                else
                    return x*"/"
                end
            end
            r = (nextind(string,pos-sizeof(name))):pos
            return (ret,r,string[r])
        elseif isexpr(arg,:escape) && (isexpr(arg.args[1],:continue) || isexpr(arg.args[1],:error))
            r = first(last_parse):prevind(last_parse,last(last_parse))
            partial = scs[r]
            ret, range = completions(partial,endof(partial))
            range += first(r)-1
            return (ret,range)
        end
    end
end