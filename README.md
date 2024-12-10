# R internal httpd server

This repo demonstrate the use of R internal HTTP server.

This server is used internally within R to serve help files and is not intended for any other usage.
The functions are not documented or exported and can change at any time.
For this reason, use this knowledge only for a minimalistic reasons in toy non-critical applications.
For a production use the [httpuv](https://cran.r-project.org/web/packages/httpuv/index.html) or [Rserve](https://cran.r-project.org/web/packages/Rserve/index.html) packages.

## How to use:

Clone or download the file, such as:

```r
https://raw.githubusercontent.com/J-Moravec/serve/refs/heads/master/serve.r
```

and run the `serve` with:

```r
Rscript serve.r directory
```

will start a webserver to serve static HTML in the `directory`, and open a web-browser.

You can also source the file, start `R` and then type:

```r
source("serve.r")
serve(directory)
```

to start the webserver.

## Examples

```r
git clone https://github.com/j-moravec/CookingRecipes
Rscript serve.r CookingRecipes
```

## How does this work

R has a simple http server it uses to serve interactive help pages when you type `help.start()`.
It follows the [HTTP/1.1](https://http.dev/1.1) specification from 1997 as opposed to more modern HTTP/2 (2015) or recent HTTP/3 (2022).

The functions are unexported and undocumented, which is a sign that you shouldn't touch them.
But if you want to, they are at:

 * R code: https://github.com/wch/r-source/blob/trunk/src/library/tools/R/dynamicHelp.R
 * C code: https://github.com/wch/r-source/blob/trunk/src/modules/internet/Rhttpd.c

The HTTP server is started by `.`, which internally runs the `.Call` to the C code.
To process the requests, the C code then uses two handlers, one is the internal function `tools:::httpd()`, and then any custom handlers set at `tools:::.httpd.handlers.env` environment.

The handlers have signature `function(path, query, ...)`, where:

* `path` is the **url**, a single character vector
* `query` is the **query**, a named vector
* `...` is the **body**, a list

For instance, for `127.0.0.1:8080/foo/bar?baz=a&biz=i`, you will have:

* **path**: `/foo/bar`
* **query**: `c(baz = "a", biz = "i")`
* **...**: `list(NULL, raw(...)` where the raw vector in is a user agent.

The return value of handler can be quite complex, the internal `tools:::httpd()` is using:

 * **payload** - a single character vector of the actual content
 * **file** - a single character vector, the path to content
 * **content-type** - the mime-type of payload or file, you can use `tools:::mime_type()` for this
 * **header** - various types of http headers, `httpd()` is using `Location` which cause redirection
 * **status code** - well, the status code, see [status code](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status)

### httpd

The most direct way is to replace the internal `tools:::httpd` function.

For this, you could use the `utils::assignInNamespace`, but it is rather complex and you cannot run it in a function.
`serve` is using a custom function that does something similar and also invisibly returns the old function.

With this, all you need to do is prepare your http handler as described above

```r
assign_in_namespace = function(x, f, envir){
    old = get(x, envir = envir)
    unlockBinding(x, envir)
    assign(x, f, envir = envir)
    lockBinding(x, envir)
    invisible(old)
    }

assign_in_namespace("httpd", my_handler, getNamespace("tools"))
```

Note that this replaces the generated help when you the internal webserver with `help.start()`.
Also, you will probably get a lot of angry messages when you try to do this in a package.

### .httpd.handlers.env

The handlers at `tools:::.httpd.handlers.env` are slightly different.
You don't replace anything, you can even run multiple handlers at the same time.

First, get the internal environment after which you can assign to it directly.
Each handler you assign to this environment will be run alongside the interactive help at
`/custom/your_handler`.

For instance:

```r
env = tools:::.httpd.handlers.env
env$foo = my_handler_foo
env$bar = my_handler_bar
help.start()
```

Now you can go to `/custom/foo` to interact with the `my_handler_foo` and `/custom/bar` to interact with the `my_handler_bar`.
This approach is actually used in [Rook](https://cran.r-project.org/web/packages/Rook/index.html) and [xfun](https://cran.r-project.org/web/packages/xfun/index.html).

## Alternatives

To serve static pages, you can use:

### Rserve

```r
Rserve:::Rserve.http.add.static("","",last=TRUE)
Rserve::run.Rserve(http.port=8080, qap=FALSE)
```

as suggested by Simon Urbanek on the _R devel_ mailing list:

> (prefix="" means all paths will be served by the static server, path="" means everything is relative to the current directory and last=TRUE means you don’t want to proceed to other static mappings or the R handler, http.port sets the port you want the HTTP server to listen on, qap=FALSE disables the otherwise default QAP protocol which you don’t use).
> See Rserve documentation for additional options (e.g. TLS/SSL support, binding to all interfaces etc.). The static handlers are experimental and undocumented, but can be given more love if people like them 🙂.

The big issue I have here is that traditionally, `/` of a website is redirected to `index.html`, which isn't the case in here.
This will cause links that assume this redirection to break.

### httpuv and servr

[servr](https://cran.r-project.org/web/packages/servr/index.html) implements a static HTTP server on top of [httpuv](https://cran.r-project.org/web/packages/httpuv/index.html)-

```r
servr::httd()
```

## History

This approach is not new and attempts to use the internal R server are quite old.
Here are a few examples, but not a complete history.

### Rserve

The code itself originates in the [Rserve](https://cran.r-project.org/web/packages/Rserve/index.html) by Simon Urbanek,
which is a quite complex tooling, much more powerful than a simple http server.

### sinartra

[sinartra](https://github.com/hadley/sinartra) is written by Hadley Wickham to write a web framework.
It was more of a toy project and didn't include an actual connection with the web server.

This was then plugged in a [separate project](https://github.com/jeffreyhorner/sinartra_example) by Jeffrey Horner.

### Rook

Probably based on the experiene with sinartra, Jeffrey Horner then wrote [Rook](https://github.com/evanbiederstedt/Rook/),
which is fully fledged web api that allows plugging into an internal web server.

### webutils

Few years after this, Jeroen Oms wrote [webutils](https://github.com/jeroen/webutils) for parsing http request.
In examples, he demonstrates working with the internal webserver.

But with a fully fledged http server [httpuv](https://cran.r-project.org/web/packages/httpuv/index.html) comming to the scene,
the interest in the internal web server died out.
