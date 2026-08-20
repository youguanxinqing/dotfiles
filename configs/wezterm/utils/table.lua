local fn = {}

fn.extend = function(t1, t2)
    if t1 == nil and t2 == nil then
        return {}
    end

    if t1 == nil then
        return t2
    end

    if t2 == nil then
        return t1
    end

    for _, v in ipairs(t2) do
        table.insert(t1, v)
    end
end

return fn
