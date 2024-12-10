#!/bin/env Rscript
# serve.r
#
# use R's internal webserver serve static HTML
serve = function(dir = ".", port = 0){
    httpd_static = function(path, query, ...){
        path = sub(pattern = "^/", replace = "", path)

        if(path == "") path = "index.html"
        if(file.exists(path) && file_test("-f", path)){
            list(file = path, "content-type" = tools:::mime_type(path))
            } else {
            list(payload = error404, "statu code" = 404)
            }
        }

    error404 = paste0(
        "<!DOCTYPE html>",
        "<html lang=\"en\">",
        "<head>",
        "    <meta charset=\"UTF-8\">",
        "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">",
        "    <title>Resources not found</title>",
        "</head>",
        "<body>",
        "    <div class=\"main\">",
        "        <h1>404</h1>",
        "        <div>The page you are looking for is not found</div>",
        "        <a href=\"/\">Back to home</a>",
        "    </div>",
        "</body>",
        "</html>",
        collapse = "\n"
        )

    assign_in_namespace = function(x, f, envir){
        old = get(x, envir = envir)
        unlockBinding(x, envir)
        assign(x, f, envir = envir)
        lockBinding(x, envir)
        invisible(old)
        }

    stop_server = function(){
        port = tools:::httpdPort()
        if(port > 0)
            tools::startDynamicHelp(FALSE)
        }

    dir = normalizePath(dir)
    if(port) options(help.ports = port)

    old_httpd = assign_in_namespace("httpd", httpd_static, getNamespace("tools"))
    on.exit(
        assign_in_namespace("httpd", old_httpd, getNamespace("tools")),
        add = TRUE
        )

    old_wd = getwd()
    setwd(dir)
    on.exit(setwd(old_wd), add = TRUE)

    stop_server()
    on.exit(stop_server, add = TRUE)

    port = suppressMessages(tools:::startDynamicHelp(NA))
    url = paste0("http://127.0.0.1:", port)
    message("Serving directory: ", dir)
    message(paste("Served at:", url))

    browser = getOption("browser")
    browseURL(url, browser = browser)

    Sys.sleep(Inf)
    }


usage = function(){
    cat(paste0(
    "Usage: serve.r DIR [PORT]\n",
    "Start internal web server in DIR on port PORT\n",
    "\n",
    "If PORT is missing, 8080 is opened.\n\n"
    ))
    }


if(sys.nframe() == 0){
    args = commandArgs(TRUE)
    if(length(args) == 0){
        usage()
        stop("Not enough arguments")
        }
    if(any(c("-h", "--help") %in% args))
        usage()

    dir = args[1]
    port = if(is.na(args[2])) 8080 else args[2]

    serve(dir, port)
    }
