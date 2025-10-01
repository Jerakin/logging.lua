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

logging.warning("This is my test")