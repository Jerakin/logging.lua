package.loaded.logging = nil
local logging = require("logging")
local lust = require("tests.lust")

lust.nocolor()

local describe, it, expect = lust.describe, lust.it, lust.expect

local test_handler = {
	name = "test_handler",
	record = nil,
	handle = function(self, record)
	end,
}

local logger = logging.get_logger()
logger:remove_handler("io_handler")

logger:add_handler(test_handler)

describe("logging", function()
	lust.before(function()
		-- Probably need to clear the logger here.
		logger:set_level(logging.DEBUG)
	end)

	describe("basic-logging-level", function()
		it("setting-logging-level", function()
			logger:set_level(logging.ERROR)
			expect(logger.level).to.equal(logging.ERROR)
		end)

		it("setting-logging-level-number", function()
			logger:set_level(15)
			expect(logger.level).to.equal(15)
		end)

		it("setting-logging-level-invalid", function()
			local status, _ = xpcall(function()
				logger:set_level("number")
			end, function() end)
			expect(status).to.equal(false)
		end)
	end)

	describe("basic-logging", function()
		it("record-is-created", function()
			local spy = lust.spy(test_handler, "handle")
			local msg = "Doing some logging"
			logger:debug(msg)
			expect(#spy).to.equal(1)
		end)

		it("record-is-ignored-with-level", function()
			local spy = lust.spy(test_handler, "handle")
			logger:set_level(logging.WARNING)
			local msg = "Doing some logging"
			logger:debug(msg)
			expect(#spy).to.equal(0)
		end)

		it("root-logger", function()
			local spy = lust.spy(test_handler, "handle")
			local msg = "Doing some logging"
			logging.debug(msg)
			expect(#spy).to.equal(1)
		end)
	end)

	describe("hierarchial-logging", function()
		it("root-handler-called", function()
			local parent = logging.get_logger("test")
			local msg = "Doing some logging"
			local spy = lust.spy(test_handler, "handle")
			parent:debug(msg)
			expect(#spy).to.equal(1)
		end)

		it("propagation-off", function()
			local parent = logging.get_logger("test")
			parent.propagate = false
			local msg = "Doing some logging"
			local spy = lust.spy(test_handler, "handle")
			parent:debug(msg)
			expect(#spy).to.equal(0)
		end)

		it("child-parent-relationship", function()
			logging.get_logger("foo.bar.baz")
			logging.get_logger("foo.bin")
			logging.get_logger("foo")
			logging.get_logger("foo.bin.bon")

			expect(logging.get_logger("foo").parent).to.equal("root")
			expect(logging.get_logger("foo.bin").parent).to.equal("foo")
			expect(logging.get_logger("foo.bin.bon").parent).to.equal("foo.bin")
			expect(logging.get_logger("foo.bar.baz").parent).to.equal("foo")
		end)
	end)
	describe("add-logger-levels", function()
		it("level-not-found", function()
			local spy = lust.spy(test_handler, "handle")
			local status , _ = xpcall(function()logger:warn("Here is my warning")end, function() end)
			expect(#spy).to.equal(0)
			expect(status).to.equal(false)
		end)

		it("adding-level", function()
			logging.add_level("warn", 35)
			local spy = lust.spy(test_handler, "handle")
			logger:warn("Here is my warning")
			expect(#spy).to.equal(1)
		end)

		it("overwrite-level", function()
			logging.add_level("warn", 30)
			local spy = lust.spy(test_handler, "handle")
			local status, _ = xpcall(function() logger:warning("Message") end, function()end)
			expect(status).to.equal(false)
			expect(#spy).to.equal(0)
		end)
	end)

	describe("handlers", function()
		it("adhers-to-hierarchy", function()
			local handler = {
				name = "handle-test",
				handle = function() end,
			}
			local spy = lust.spy(handler, "handle")
			logging.get_logger("foo.bar"):add_handler(handler)

			logging.get_logger("foo").debug("Hi from foo")
			logging.get_logger("foo.bar").debug("Hi from foo.bar")
			logging.get_logger("foo.bar.baz").debug("Hi from foo.bar.baz")

			expect(#spy).to.equal(2)
		end)
	end)

	describe("name", function()
		it("generates a proper name", function()
			local name = logging.logger_name()
			expect(name).to.equal("tests.tests_logger")
		end)
	end)
end)
