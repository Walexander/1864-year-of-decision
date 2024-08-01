module [ frameCountToSeconds ]

frameCountToSeconds = \x -> Num.toFrac x |> Num.div 60
