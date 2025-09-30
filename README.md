# logging.lua
> Complex enough logging library for Lua


# Installation
Drop the logging.lua file into your project.

# Usage
You should require the library, get a named logger and use it.
```lua
local logging = require "logging"

local logger = logging.get_logger("mymodule")

logger.debug("Something went wrong")
-- [DEBUG] [mymodule] mymodule.lua:5: Something went wrong
````

You can also use the root logger, however this is discourge.
```lua
local logging = require "logging"

logging.debug("Something went wrong")
-- [DEBUG] [root] mymodule.lua:3: Something went wrong
````

You set the level on the logging object.

```lua
local logging = require "logging"

local logger = logging.get_logger("mymodule")

logger.set_level(logging.INFO)

logger.debug("Something went wrong")
-- As debug is of a lower level than info, this will not print anything.
````


The library uses a hierarchical logging system. A logger will call its parent logger with the same record, while filtering it on the log level. In practive this means that you can use the parent logger to silence child loggers.
```lua
local logging = require "logging"

logging.get_logger("lib.module").set_level(logging.INFO)

local logger = logging.get_logger("lib.module.file")

logger.debug("Something went wrong")
-- As a parent logger has a higher level (INFO) than this child logger is using (DEBUG) this will not print anything.
````