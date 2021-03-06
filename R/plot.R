##' Plot function for incidence objects
##'
##' This function is used to visualise the output of the \code{\link{incidence}}
##' function, using the package \code{ggplot2}.
##'
##'
##' @export
##'
##' @importFrom graphics plot
##'
##' @author Thibaut Jombart \email{thibautjombart@@gmail.com}
##'
##' @seealso The \code{\link{incidence}} function to generate the 'incidence'
##' objects.
##'
##' @param x An incidence object, generated by the function
##' \code{\link{incidence}}.
##'
##' @param ... Further arguments passed to other methods (currently not used).
##'
##' @param fit An 'incidence_fit' objet as returned by \code{\link{fit}}.
##'
##' @param stack A logical indicating if bars of multiple groups should be
##' stacked, or displayed side-by-side.
##'
##' @param color The color to be used for the filling of the bars; NA for
##' invisiable bars; defaults to "black".
##'
##' @param border The color to be used for the borders of the bars; NA for
##' invisiable borders; defaults to NA.
##'
##' @param col_pal The color palette to be used for the groups; defaults to
##' \code{pal1}. See \code{\link{pal1}} for other palettes implemented in
##' incidence.
##'
##' @param alpha The alpha level for color transparency, with 1 being fully
##' opaque and 0 fully transparent; defaults to 0.7.
##'
##' @param xlab The label to be used for the x-axis; empty by default.
##'
##' @param ylab The label to be used for the y-axis; by default, a label will be
##' generated automatically according to the time interval used in incidence
##' computation.
##' @param labels_iso_week a logical value indicating whether labels x axis tick
##' marks are in ISO 8601 week format yyyy-Www when plotting ISO week-based weekly
##' incidence; defaults to be TRUE.
##'
##' @examples
##'
##' if(require(outbreaks)) {
##'   onset <- ebola_sim$linelist$date_of_onset
##'
##'   ## daily incidence
##'   inc <- incidence(onset)
##'   inc
##'   plot(inc)
##'
##'   ## weekly incidence
##'   inc.week <- incidence(onset, interval = 7)
##'   inc.week
##'   plot(inc.week) # default to label x axis tick marks with isoweeks
##'   plot(inc.week, labels_iso_week = FALSE) # label x axis tick marks with dates
##'   plot(inc.week, border = "white") # with visible border
##'
##'   ## use group information
##'   sex <- ebola_sim$linelist$gender
##'   inc.week.gender <- incidence(onset, interval = 7, groups = sex)
##'   plot(inc.week.gender)
##'   plot(inc.week.gender, labels_iso_week = FALSE)
##'
##'   ## adding fit
##'   fit <- fit_optim_split(inc.week.gender)$fit
##'   plot(inc.week.gender, fit = fit)
##'   plot(inc.week.gender, fit = fit, labels_iso_week = FALSE)
##' }
##'
plot.incidence <- function(x, ..., fit = NULL, stack = is.null(fit),
                           color = "black", border = NA, col_pal = pal1,
                           alpha = .7, xlab = "", ylab = NULL,
                           labels_iso_week = !is.null(x$isoweeks)) {
    stopifnot(is.logical(labels_iso_week))

    ## extract data in suitable format for ggplot2
    df <- as.data.frame(x, long = TRUE)
    n.groups <- ncol(x$counts)


    ## Use custom labels for usual time intervals
    if (is.null(ylab)) {
        if (x$interval == 1) {
            ylab <- "Daily incidence"
        } else if (x$interval == 7) {
            ylab <- "Weekly incidence"
        } else if (x$interval == 14) {
            ylab <- "Biweekly incidence"
        } else {
            ylab <- sprintf("Incidence by period of %d days",
                            x$interval)
        }
    }

    ## Handle stacking
    stack.txt <- ifelse(stack, "stack", "dodge")

    ## By default, the annotation of bars in geom_bar puts the label in the
    ## middle of the bar. This is wrong in our case as the annotation of a time
    ## interval is the lower (left) bound, and should therefore be left-aligned
    ## with the bar. Note that we cannot use position_nudge to create the
    ## x-offset as we need the 'position' argument for stacking. Best option
    ## here is add x$interval / 2 to the x-axis.

    x.axis.txt <- paste("dates", x$interval/2, sep = "+")
    out <- ggplot2::ggplot(df, ggplot2::aes_string(x = x.axis.txt, y = "counts")) +
        ggplot2::geom_bar(stat = "identity", width = x$interval,
                          position = stack.txt,
                          color = border, alpha = alpha) +
            ggplot2::labs(x = xlab, y = ylab)


    ## Handle fit objects here; 'fit' can be either an 'incidence_fit' object,
    ## or a list of these. In the case of a list, we add geoms one after the
    ## other.

    if (!is.null(fit)) {
        if (inherits(fit, "incidence_fit")) {
            out <- add_incidence_fit(out, fit)
        } else if (is.list(fit)) {
            for (i in seq_along(fit)) {
                fit.i <- fit[[i]]
                if (!inherits(fit.i, "incidence_fit")) {
                    stop(sprintf(
                        "The %d-th item in 'fit' is not an 'incidence_fit' object, but a %s",
                                 i, class(fit.i)))
                }
                out <- add_incidence_fit(out, fit.i)
            }
        } else {
            stop("Fit must be a 'incidence_fit' object, or a list of these")
        }
    }


    ## Handle colors

    ## Note 1: because of the way 'fill' works, we need to specify it through
    ## 'aes' if not directly in the geom. This causes the kludge below, where we
    ## make a fake constant group to specify the color and remove the legend.

    ## Note 2: when there are groups, and the 'color' argument does not have one
    ## value per group, we generate colors from a color palette. This means that
    ## by default, the palette is used, but the user can manually specify the
    ## colors.

    if (ncol(x$counts) < 2) {
        out <- out + ggplot2::aes(fill = 'a') +
            ggplot2::scale_fill_manual(values = color, guide = FALSE)
    } else {
        ## find group colors
        if (length(color) != ncol(x$counts)) {
            group.colors <- col_pal(n.groups)
        } else {
            group.colors <- color
        }

        ## add colors to the plot
        out <- out + ggplot2::aes_string(fill = "groups") +
            ggplot2::scale_fill_manual(values = group.colors)
        if (!is.null(fit)) {
            out <- out + ggplot2::aes_string(color = "groups") +
            ggplot2::scale_color_manual(values = group.colors)
        }
    }

    ## Replace labels of x axis tick marks with ISOweeks
    if (labels_iso_week && "isoweeks" %in% names(x)) {
      out_build <- ggplot2::ggplot_build(out)
      x.major_source <- out_build$layout$panel_ranges[[1]]$x.major_source
      dates.major_source <- as.Date(x.major_source, origin = "1970-01-01")
      isoweeks.major_source <- ISOweek::date2ISOweek(dates.major_source)
      substr(isoweeks.major_source, 10, 10) <- "1"
      breaks <- ISOweek::ISOweek2date(isoweeks.major_source)
      labels <- substr(isoweeks.major_source, 1, 8)
      out <- out + ggplot2::scale_x_date(breaks = breaks, labels = labels)
    }
    out
}
