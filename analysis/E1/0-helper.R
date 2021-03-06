# Reads in the raw tracker data files and converts some basic raw values for us.
read.data <- function(path,file.name) {
    # E.g., A-ADU-P01.txt (for condition A, ADULT, and participant 01)
    name.parts <- unlist(strsplit(file.name, "[-_.]"))
    data <- read.csv(paste(path,file.name,sep=""))
    # Within the tracker data for this participant...
    data <- within(data, {
        L.POR.X..px. <- to.n(L.POR.X..px.)
        R.POR.X..px. <- to.n(R.POR.X..px.)
        L.POR.Y..px. <- to.n(L.POR.Y..px.)
        R.POR.Y..px. <- to.n(R.POR.Y..px.)
        # Average x and y positions
        x.pos <- rowMeans(data[, c("L.POR.X..px.", "R.POR.X..px.")])
        y.pos <- rowMeans(data[, c("L.POR.Y..px.", "R.POR.Y..px.")])
        # Object.Hits are when the eyes are looking in an area of interest
        L.looks <- L.Object.Hit == "LEFT" | R.Object.Hit == "LEFT"
        R.looks <- L.Object.Hit == "RIGHT" | R.Object.Hit == "RIGHT"
        # Events are what the eyes are doing (e.g., fixating, saccading, etc.)
        Events <- L.Event.Info != "Blink" & L.Event.Info != "-" &
            R.Event.Info != "Blink" & R.Event.Info != "-"
        Saccades <- L.Event.Info == "Saccade" | R.Event.Info == "Saccade"
        Fixations <- L.Event.Info == "Fixation" | R.Event.Info == "Fixation"
        # Add a version/agegroup/subject column based on the file name
        Condition <- rep(name.parts[1], nrow(data))
        AgeGroup <- rep(name.parts[2], nrow(data))
        Subject <- rep(paste(name.parts[1], name.parts[3], name.parts[2],
            sep = "-"), nrow(data))
        # Make the time into seconds
        TimeSec <- round((Time - Time[1])/(1000000), 3)
        MS.Increment <- c(0, diff(TimeSec))
    })
    return (data)
}


# Adds annotations to those measurements that are within the analysis windows
# |--------A----|-|                     # Speaker A's turn
#                      |-|----B-----|   # Speaker B's turn
# Anchor:      |--|
# Transition:   |---------|
# Gap:            |----|
#
get.windows.categorical <- function(obs, gap.info, utt1.window,
    utt2.window, fixation.window) {
    # Get rid of gaps over 550 ms (marked as 0 in the spreadsheet)
    gaps <- subset(gap.info, Gap != "na" & Gap != "0")
    df.out = data.frame()
    for (i in 1:nrow(gaps)) {
        gap <- gaps[i,]
        rows <- subset(obs,
            Condition == toString(gap$Condition) & 
            (TimeSec >= gap$Onset - utt1.window - fixation.window) & 
            (TimeSec <= gap$Offset + utt2.window + fixation.window))           
        if (nrow(rows) == 0) {
    	    next
        }
        # Set the anchor window measurements to "ANCHOR"
        anchor.window.idx <- which(
            (rows$TimeSec >= gap$Onset - utt1.window - fixation.window) &
            rows$TimeSec <= gap$Onset)
        rows$Anchor.Window <- rep(NA, nrow(rows))
        rows$Anchor.Window[anchor.window.idx] <- "ANCHOR"
        # Set the transition window measurements to "TRANSITION"
        transition.window.idx <- which(
            (rows$TimeSec >= gap$Onset - utt1.window) &
            (rows$TimeSec <= gap$Offset + utt2.window + fixation.window))
        rows$Transition.Window <- rep(NA, nrow(rows))
        rows$Transition.Window[transition.window.idx] <- "TRANSITION"
        # Set the gap window measurements to "GAP"
        gap.window.idx <- which(rows$TimeSec >= gap$Onset &
            rows$TimeSec <= gap$Offset)
        rows$Gap.Window <- rep(NA, nrow(rows))
        rows$Gap.Window[gap.window.idx] <- "GAP"
        # Set the origin to the previous speaker at that gap
        rows$Origin <- rep(as.character(gap$SpeakerPrev), nrow(rows))
        # Set the QS status to the transition type (question or non-question)
        rows$QS <- rep(as.character(gap$Type), nrow(rows))
        # Set the gap number
        rows$GapNum <- rep(toString(gap$Gap), nrow(rows))
        # Create a "cumulative" time to plot the analysis window from t=0    
        minTime <- min(rows$TimeSec)
        rows$Cumulative.Time <- round((rows$TimeSec - minTime), 3) 
        df.out <- rbind(df.out, rows)
    }
    # Re-order data and return it
    df.out <- df.out[order(df.out$Subject, as.integer(df.out$GapNum),
        df.out$Cumulative.Time), ]
    return(df.out)
}