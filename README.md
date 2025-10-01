# logging.lua
> Complex enough logging library for Lua


# Installation
Drop the logging.lua file into your project.

# Usage
You should require the library, get a named logger, and use it.
```lua
local logging = require "logging"

local logger = logging.get_logger("mymodule")

logger.debug("Something went wrong")
-- [DEBUG] [mymodule] mymodule.lua:5: Something went wrong
````

You can also use the root logger, however this is discourge. As that defeats the whole purpose of segmenting your logs into child loggers. However, this does enable the module to be a drop in replacement for other logging libraries.
```lua
local logging = require "logging"

logging.debug("Something went wrong")
-- [DEBUG] [root] mymodule.lua:3: Something went wrong
````

### Setting log level.

You set the level on the logging object.

> [!NOTE]
> The library uses both the `.` and `:` annotations. `logging.get_logger` and the logging methods (`.debug`, `.info`, etc) uses `.`. Every other method uses `:`.

```lua
local logging = require "logging"

local logger = logging.get_logger("mymodule")

logger:set_level(logging.INFO)

logger.debug("Something went wrong")
-- As debug is of a lower level than info, this will not print anything.
````

### Hierarchical logging

The library uses a hierarchical logging system. A logger will call its parent logger with the same record, while filtering it on the log level. In practice this means that you can use the parent logger to silence child loggers. This can be especially helpful if you have a particular noisy part of your code that you majority of the time want silenced.

This would also enable you to set a higher level on the root logger effeciantly silencing all logs. Which could be useful when releasing.
```lua
local logging = require "logging"

logging.get_logger("lib.module"):set_level(logging.INFO)

local logger = logging.get_logger("lib.module.file")

logger.debug("Something went wrong")
-- As a parent logger has a higher level (INFO) than this child logger is using (DEBUG) this will not print anything.
````


## Handlers
The library uses handlers to display/emit the log. By default a "`print_handler`" is added to the root logger. There is also a "`file_logger`" that you set up and use. You can also write your own handlers easily.

To use the file handler you can do something like this.
```lua
local logging = require "logging"

logging.handlers.file_handler.file_path = "my/file/path/log.log"
logging.get_logger().add_handler(logging.handlers.file_handler)
```

Remember, this is a hierarhical logging library. To fully benefit from the file handler you need to add it at the "top most" logger you want to use it with.

Any logger on a child would not be used with a parent. Meaning something like this
```lua
local logging = require "logging"
logging.get_logger().remove_logger("print_handler")
logging.get_logger("foo.bar").add_handler(logging.handlers.print_handler)

logging.get_logger("foo").debug("Hi from foo")
logging.get_logger("foo.bar").debug("Hi from foo.bar")
logging.get_logger("foo.bar.baz").debug("Hi from foo.bar.baz")

```
Would print `Hi from foo.bar` and `Hi from foo.bar.baz` but as `foo` is the parent logger to `foo.bar` which has the handler. The debug statement from `foo` would not be printed.

### Custom Handlers
A handler is simple table. It shoud have a name and a handle function, and can also have a formatter defined. This is a valid handler, a very useless one.
```lua
{
    name = "my-example",
    handle = function() end
}
```

## Formatters
If you are not happy with the formatting you can specify your own formatter. These are specified on the handlers.

As an example, you could implement your own colored handler with something like this.
```lua
local logging = require "logging"

local colors = {
  [logging.DEBUG] = "\27[36m",
  [logging.INFO] = "\27[32m",
  [logging.WARNING] = "\27[33m",
  [logging.ERROR] = "\27[31m",
  [logging.CRITICAL] = "\27[35m",
}

local names = {
  [logging.DEBUG] = "DEBUG",
  [logging.INFO] = "INFO",
  [logging.WARNING] = "WARNING",
  [logging.ERROR] = "ERROR",
  [logging.CRITICAL] = "CRITICAL",
}

local function color_formatter(record)
    local col = colors[record.level]
    local name = names[record.level]
    local line_info = record.pathname .. ":" .. record.lineno
    return string.format(
        "%s[%s]%s %s: %s",
        col,
        name,
        "\27[0m",
        line_info,
        record.msg
    )
end

logging.handlers.print_handler.formatter = color_formatter

```