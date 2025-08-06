# [Sequencing](@id sequencing)

In a typical simulation pipeline, we want to connect daily (24-hours) day-ahead unit commitment problems, with multiple economic dispatch problems. Usually, our day-ahead unit commitment problem will have an hourly (1-hour) resolution, while the economic dispatch will have a 5-minute resolution.

Depending on your problem, it is common to use a 2-day look-ahead for unit commitment problems, so in this case, the Day-Ahead problem will have: resolution = Hour(1) with interval = Hour(24) and horizon = Hour(48). In the case of the economic dispatch problem, it is common to use a look-ahead of two hours. Thus, the Real-Time problem will have: resolution = Minute(5), with interval = Minute(5) (we only store the first operating point) and horizon = 24 (24 time steps of 5 minutes are 120 minutes, that is 2 hours).
